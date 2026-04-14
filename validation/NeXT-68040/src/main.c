/*
 * main.c
 * NeXT 68040LC system emulator with hardware MC68882 FPU.
 *
 * Boots a NeXT Mach kernel under Musashi emulation on a Zynq UltraScale+.
 * FPU instructions are intercepted via F-line trapping and routed to the
 * hardware MC68882 FPGA over AXI-Lite (same mechanism as the Atari 68000
 * validation firmware).
 *
 * Console output: SCC channel A TX bytes are forwarded to ARM UART.
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "musashi/m68k.h"
#include "next_memory.h"
#include "next_devs.h"
#include "next_mon_stub.h"
#include "next_hw.h"
#ifdef TEST_ROM
#ifdef FPU_TEST_ROM
#include "../test/fpu_test_rom.h"
#elif defined(MMU_TEST_ROM)
#include "../test/mmu_test_rom.h"
#else
#include "../test/timer_test_rom.h"
#endif
#else
#include "next_rom_image.h"
#endif
#include "fline_handler.h"
#include "next_rtc.h"
#include "next_dsp.h"
#include "next_kms.h"
#include "next_scsi.h"
#include "next_ufs_diag.h"
#include "next_video.h"
#include "text_fb.h"
#include "dp_video.h"
#include "render_core1.h"

/* Number of M68K instructions to execute per main-loop tick */
#define EMU_CYCLES_PER_TICK  10000

/* ------------------------------------------------------------------ */
/* Early instruction trace (first N instructions for boot debugging)   */
/* ------------------------------------------------------------------ */
#define TRACE_LIMIT  0  /* Disabled */
static int trace_count = 0;

/* ------------------------------------------------------------------ */
/* Syscall/trap ring buffer — records user→kernel transitions            */
/* On NeXT Mach: TRAP #0 = Unix syscall, TRAP #1 = Mach trap           */
/* D0 holds the syscall number (negative for Mach traps)                */
/* ------------------------------------------------------------------ */
#define TRAP_LOG_SIZE 256
static struct {
    uint32_t pc;       /* user PC of TRAP instruction */
    uint32_t d0;       /* D0 = syscall number */
    uint32_t d1;       /* D1 = first arg (Mach traps) */
    uint32_t sp;       /* user SP at time of trap */
    uint32_t arg1;     /* USP+4: first stack arg (Unix syscalls) */
    uint32_t arg2;     /* USP+8: second stack arg */
    uint32_t arg3;     /* USP+12: third stack arg */
    uint16_t sr;       /* SR before trap (bit 13 = user/super) */
    uint8_t  trap_num; /* TRAP #N (0-15) */
} trap_log[TRAP_LOG_SIZE];
static int trap_log_idx = 0;
static int trap_log_total = 0;

/* User-mode execution tracker — counts instructions + last 4 PCs + URP */
static uint32_t user_instr_count = 0;
static uint32_t user_last_pc[4];
static uint32_t user_last_urp = 0;  /* URP active during last user instruction */
static int user_last_idx = 0;
int emu_user_mode_flag = 0;

/* Called from Musashi's m68ki_exception_trapN — before SR goes supervisor */
void emu_trap_log(unsigned int trap_num, unsigned int pc,
                  unsigned int sr, unsigned int d0, unsigned int d1,
                  unsigned int sp)
{
    emu_user_mode_flag = 0;  /* entering kernel */
    int idx = trap_log_idx;
    trap_log[idx].pc = pc;
    trap_log[idx].d0 = d0;
    trap_log[idx].d1 = d1;
    trap_log[idx].sp = sp;
    trap_log[idx].sr = (uint16_t)sr;
    trap_log[idx].trap_num = (uint8_t)trap_num;
    /* For Unix syscalls (TRAP#4), capture args from user stack.
     * BSD convention: args at USP+4, USP+8, USP+12 */
    if (trap_num == 4 && sp >= 0x1000) {
        trap_log[idx].arg1 = m68k_read_memory_32(sp + 4);
        trap_log[idx].arg2 = m68k_read_memory_32(sp + 8);
        trap_log[idx].arg3 = m68k_read_memory_32(sp + 12);
    } else if (trap_num == 3 && (d0 == 0x15 || d0 == 0x16 || d0 == 0x14)) {
        /* Mach msg traps: D1 = msg header pointer.
         * msg_local_port at offset 12 = the port being used.
         * D0=$14=msg_send, $15=msg_receive, $16=msg_rpc */
        if (d1 >= 0x1000) {
            trap_log[idx].arg1 = m68k_read_memory_32(d1 + 12); /* msg_local_port */
            trap_log[idx].arg2 = m68k_read_memory_32(d1 + 16); /* msg_remote_port */
            trap_log[idx].arg3 = m68k_read_memory_32(d1 + 20); /* msg_id */
        } else {
            trap_log[idx].arg1 = 0;
            trap_log[idx].arg2 = 0;
            trap_log[idx].arg3 = 0;
        }
    } else {
        trap_log[idx].arg1 = 0;
        trap_log[idx].arg2 = 0;
        trap_log[idx].arg3 = 0;
    }
    trap_log_idx = (trap_log_idx + 1) % TRAP_LOG_SIZE;
    trap_log_total++;
}

void trap_log_dump(void) {
    {
        extern unsigned int pmmu_translate_addr(unsigned int addr_in);
        uint32_t last_upc = user_last_pc[(user_last_idx - 1) & 3];
        xil_printf("[USER] %u user-mode instructions, last PCs: $%08X $%08X $%08X $%08X\r\n",
                   user_instr_count,
                   user_last_pc[(user_last_idx - 4) & 3],
                   user_last_pc[(user_last_idx - 3) & 3],
                   user_last_pc[(user_last_idx - 2) & 3],
                   last_upc);
        if (last_upc && user_instr_count > 0) {
            extern unsigned int mmu040_translate_user(unsigned int va);
            uint32_t pa = mmu040_translate_user(last_upc & ~1);
            xil_printf("[USER] Code at last user PC $%08X (PA=$%08X):\r\n  ",
                       last_upc, pa);
            for (int i = -4; i < 12; i++) {
                uint32_t a = mmu040_translate_user((last_upc & ~1) + i*2);
                uint16_t w = (next_phys_read_32(a & ~3) >> (((a & 2) ? 0 : 16))) & 0xFFFF;
                if (i == 0) xil_printf("[");
                xil_printf("%04X", w);
                if (i == 0) xil_printf("]");
                xil_printf(" ");
            }
            xil_printf("\r\n");
        }
    }
    xil_printf("[TRAP-LOG] Last %d syscalls (total %d):\r\n",
               trap_log_total < TRAP_LOG_SIZE ? trap_log_total : TRAP_LOG_SIZE,
               trap_log_total);
    int start = trap_log_total < TRAP_LOG_SIZE ? 0 : trap_log_idx;
    int count = trap_log_total < TRAP_LOG_SIZE ? trap_log_total : TRAP_LOG_SIZE;
    for (int i = 0; i < count; i++) {
        int idx = (start + i) % TRAP_LOG_SIZE;
        const char *kind = "???";
        if (trap_log[idx].trap_num == 3) kind = "MACH";
        else if (trap_log[idx].trap_num == 4) kind = "UNIX";
        else if (trap_log[idx].trap_num == 5) kind = "GREG";
        else if (trap_log[idx].trap_num == 6) kind = "SREG";
        else if (trap_log[idx].trap_num == 0) kind = "OLD ";
        if (trap_log[idx].trap_num == 4) {
            /* Unix syscall: show syscall name and stack args */
            const char *sname = "?";
            switch (trap_log[idx].d0) {
            case 1: sname = "exit"; break;
            case 2: sname = "fork"; break;
            case 3: sname = "read"; break;
            case 4: sname = "write"; break;
            case 5: sname = "open"; break;
            case 6: sname = "close"; break;
            case 7: sname = "wait4"; break;
            case 9: sname = "link"; break;
            case 10: sname = "unlink"; break;
            case 12: sname = "chdir"; break;
            case 15: sname = "chmod"; break;
            case 17: sname = "obreak"; break;
            case 18: sname = "getfsstat"; break;
            case 20: sname = "getpid"; break;
            case 23: sname = "setuid"; break;
            case 24: sname = "getuid"; break;
            case 33: sname = "access"; break;
            case 37: sname = "kill"; break;
            case 42: sname = "pipe"; break;
            case 47: sname = "getgid"; break;
            case 54: sname = "ioctl"; break;
            case 59: sname = "execve"; break;
            case 61: sname = "chroot"; break;
            case 66: sname = "vfork"; break;
            case 73: sname = "munmap"; break;
            case 74: sname = "mprotect"; break;
            case 78: sname = "mincore"; break;
            case 90: sname = "dup2"; break;
            case 92: sname = "fcntl"; break;
            case 97: sname = "socket"; break;
            case 104: sname = "bind"; break;
            case 106: sname = "listen"; break;
            case 120: sname = "readv"; break;
            case 121: sname = "writev"; break;
            case 128: sname = "rename"; break;
            case 136: sname = "mkdir"; break;
            case 197: sname = "mmap"; break;
            }
            xil_printf("  [%d] TRAP#4 (UNIX) %s(%d) args=[$%08X,$%08X,$%08X] PC=$%08X SP=$%08X\r\n",
                       i, sname, trap_log[idx].d0,
                       trap_log[idx].arg1, trap_log[idx].arg2, trap_log[idx].arg3,
                       trap_log[idx].pc, trap_log[idx].sp);
        } else if (trap_log[idx].trap_num == 3 &&
                   (trap_log[idx].d0 == 0x14 || trap_log[idx].d0 == 0x15 || trap_log[idx].d0 == 0x16)) {
            /* Mach msg trap: show port info */
            const char *mname = "msg_send";
            if (trap_log[idx].d0 == 0x15) mname = "msg_recv";
            else if (trap_log[idx].d0 == 0x16) mname = "msg_rpc";
            xil_printf("  [%d] TRAP#3 %s port=%d rport=%d id=%d msg=$%08X PC=$%08X\r\n",
                       i, mname,
                       trap_log[idx].arg1, trap_log[idx].arg2, trap_log[idx].arg3,
                       trap_log[idx].d1, trap_log[idx].pc);
        } else {
            xil_printf("  [%d] TRAP#%d (%s) D0=$%08X D1=$%08X PC=$%08X SP=$%08X SR=$%04X\r\n",
                       i, trap_log[idx].trap_num, kind,
                       trap_log[idx].d0, trap_log[idx].d1,
                       trap_log[idx].pc, trap_log[idx].sp, trap_log[idx].sr);
        }
    }
    /* Dump msg_header for the last msg_recv/msg_rpc using URP walker */
    {
        extern unsigned int mmu040_translate_user(unsigned int va);
        for (int i = count - 1; i >= 0; i--) {
            int idx2 = ((start + i) % TRAP_LOG_SIZE);
            if (trap_log[idx2].trap_num == 3 &&
                (trap_log[idx2].d0 == 0x15 || trap_log[idx2].d0 == 0x16) &&
                trap_log[idx2].d1 >= 0x1000) {
                uint32_t msg_va = trap_log[idx2].d1;
                xil_printf("[MSG-HDR] %s buf at VA=$%08X:\r\n",
                           trap_log[idx2].d0 == 0x15 ? "msg_recv" : "msg_rpc",
                           msg_va);
                for (int j = 0; j < 24; j += 4) {
                    uint32_t pa = mmu040_translate_user(msg_va + j);
                    uint32_t val = next_phys_read_32(pa);
                    const char *fname = "";
                    if (j == 0)  fname = " (simple+unused)";
                    if (j == 4)  fname = " (msg_size)";
                    if (j == 8)  fname = " (msg_type)";
                    if (j == 12) fname = " (local_port)";
                    if (j == 16) fname = " (remote_port)";
                    if (j == 20) fname = " (msg_id)";
                    xil_printf("  +%02d: $%08X%s\r\n", j, val, fname);
                }
                break;
            }
        }
    }
}

/* Intercept ROM's mg_putc to mirror bitmap console output to serial.
 * Address is ROM-version-specific; set to 0 to auto-detect from mon_global.
 * Rev 3.3 v74 (Turbo): $010081C8
 * Rev 2.5 v66 (68040):  discovered at runtime from mg_putc field */
static uint32_t rom_putc_addr = 0;  /* 0 = not yet discovered */

/* Sliding 16-entry ring buffer of recent PCs.  Dumped on the first OOB
 * fetch trap so we can see the last ~16 instructions the CPU executed
 * before running off into garbage. */
#define PC_RING_SIZE 16
static uint32_t pc_ring[PC_RING_SIZE];
static uint32_t pc_ring_idx;

void emu_dump_pc_ring(const char *why)
{
    xil_printf("[PCRING] %s — last %d PCs (oldest→newest):\r\n", why, PC_RING_SIZE);
    for (int i = 0; i < PC_RING_SIZE; i++) {
        uint32_t p = pc_ring[(pc_ring_idx + i) % PC_RING_SIZE];
        xil_printf("  %2d: $%08X\r\n", i, p);
    }
}

void emu_instr_hook(unsigned int pc)
{
    pc_ring[pc_ring_idx % PC_RING_SIZE] = pc;
    pc_ring_idx++;

    /* Track A7 change around the specific ROM routine whose RTS is
     * popping garbage.  Log PC + A7 when PC is in the helper/caller
     * range AND A7 is near the crashed slot. */
    {
        uint32_t a7 = m68k_get_reg(NULL, M68K_REG_A7);
        (void)a7;  /* A7 tracking now disabled — root cause fixed */
    }

    /* Track user-mode instruction count (only after first syscall fires) */
    if (trap_log_total > 0) {
        uint16_t sr = m68k_get_reg(NULL, M68K_REG_SR);
        if (!(sr & 0x2000)) {
            if (user_instr_count == 0)
                next_softint_enable();  /* safe: timer calibration is done */
            user_instr_count++;
            user_last_pc[user_last_idx & 3] = pc;
            user_last_idx++;
        }
    }

    /* Mirror ROM's bitmap console output to serial.
     * Auto-discover mg_putc address from mon_global (A3 register). */
    if (rom_putc_addr == 0) {
        /* Try to find mg_putc once the ROM has set up mon_global */
        uint32_t mg = m68k_get_reg(NULL, M68K_REG_A3);
        if (mg >= 0x0B000000 && mg < 0x0C000000) {
            uint32_t pgsz = m68k_read_memory_32(mg + 10);
            if (pgsz == 8192 || pgsz == 4096) {
                rom_putc_addr = m68k_read_memory_32(mg + 734);
                if (rom_putc_addr >= 0x01000000 && rom_putc_addr < 0x01020000) {
                    /* mg_getc at offset 726, mg_try_getc at 730 */
                    uint32_t getc_addr = m68k_read_memory_32(mg + 726);
                    uint32_t try_getc = m68k_read_memory_32(mg + 730);
                    xil_printf("[MG] mg_putc=$%08X mg_getc=$%08X mg_try_getc=$%08X\r\n",
                               rom_putc_addr, getc_addr, try_getc);
                    /* mg_console_i is at mg+792, mg_console_o at mg+796.
                     * ROM sets these to CONS_I_KBD(0) / CONS_O_BITMAP(0).
                     * Patch mg_console_i to CONS_I_SCC_A(1) so the ROM
                     * monitor polls SCC serial instead of the keyboard. */
                    uint32_t cons_i = m68k_read_memory_32(mg + 792);
                    if (cons_i == 0) {
                        m68k_write_memory_32(mg + 792, 1); /* CONS_I_SCC_A */
                        xil_printf("[MG] patched mg_console_i: KBD→SCC_A\r\n");
                    }
                } else {
                    rom_putc_addr = 0;  /* invalid, keep searching */
                }
            }
        }
    }
    if (rom_putc_addr != 0 && pc == rom_putc_addr) {
        uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
        uint8_t ch = m68k_read_memory_8(sp + 7);
        if (ch >= 0x20 && ch < 0x7F)
            xil_printf("%c", ch);
        else if (ch == '\r' || ch == '\n' || ch == '\t' || ch == '\b')
            xil_printf("%c", ch);
    }

    /* The ROM gets stuck in an event/animation loop at $010024E2
     * that calls $0100A1A8 and loops while D3 != 0.  Force D3=0
     * when keyboard input is available to break out of the loop. */
    if (pc == 0x010024E8 && next_scc_rx_available()) {
        /* $010024E8 is TST.L D3 after the BSR — force D3=0 to exit */
        m68k_set_reg(M68K_REG_D3, 0);
    }

    /* REMOVED: cthread hack at $00004EDE — caused ILLG-USER at $00004EE0
     * because $008C (FPU displacement word) was executed as opcode.
     * The real problem is all threads blocked in msg_recv with no
     * wakeup source — need to investigate what's missing. */

    /* Watch for kernel exec path — all call stack addresses from panic.
     * Also search for "errno" string in kernel to find the printf caller. */
    {
        static int exec_watch_armed = 0;
        static int exec_watch_hits = 0;
        static uint32_t errno_str_addr = 0;
        static int errno_search_done = 0;
        static int kernel_phase = 0;  /* 0=boot, 1=kernel running */

        /* Arm after kernel starts executing in RAM */
        if (!exec_watch_armed && pc >= 0x04000000 && pc < 0x04100000)
            exec_watch_armed = 1;
        /* Detect kernel phase: after timer set to 500us, the kernel is running.
         * PC=$040013A6 is PFLUSH right after SRP setup — marks kernel takeover. */
        if (kernel_phase == 0 && pc == 0x040013A6)
            kernel_phase = 1;

        if (exec_watch_armed) {
            /* One-time search: find "errno" string in kernel text/data.
             * The kernel prints "Load of /etc/mach_init, errno 13" —
             * search for "errno " in physical RAM. */
            if (!errno_search_done) {
                errno_search_done = 1;
                /* Kernel text/data lives in bank 0 ($04000000..$04C00000).
                 * Iterate virtual addresses so the bank-mask offset is
                 * applied correctly for every byte read. */
                #define RAM_B(va) (next_ram[(va) & 0x07FFFFFFu])
                for (uint32_t va = NEXT_RAM_BASE;
                     va < NEXT_RAM_BASE + 0x00C00000 && !errno_str_addr;
                     va += 2) {
                    if (RAM_B(va)   == 'e' && RAM_B(va+1) == 'r' &&
                        RAM_B(va+2) == 'r' && RAM_B(va+3) == 'n' &&
                        RAM_B(va+4) == 'o' && RAM_B(va+5) == ' ') {
                        for (int back = 4; back < 64; back++) {
                            if (va >= NEXT_RAM_BASE + (uint32_t)back &&
                                RAM_B(va-back)   == 'L' &&
                                RAM_B(va-back+1) == 'o' &&
                                RAM_B(va-back+2) == 'a' &&
                                RAM_B(va-back+3) == 'd') {
                                errno_str_addr = va - back;
                                xil_printf("[EXEC-FIND] 'Load of...errno' string at VA=$%08X\r\n",
                                           errno_str_addr);
                                xil_printf("[EXEC-FIND] ");
                                for (int j = 0; j < 64; j++) {
                                    uint8_t ch = RAM_B(va - back + j);
                                    if (ch >= 0x20 && ch < 0x7F) xil_printf("%c", ch);
                                    else if (ch == 0) { xil_printf("\\0"); break; }
                                    else xil_printf(".");
                                }
                                xil_printf("\r\n");
                                break;
                            }
                        }
                    }
                }
                #undef RAM_B
                if (!errno_str_addr)
                    xil_printf("[EXEC-FIND] 'errno' string NOT found in kernel RAM\r\n");
            }

            /* Watch exec-related call stack addresses — each with own counter.
             * Only after kernel takes over (kernel_phase=1). */
            if (kernel_phase) {
                static int w54c_n=0, wfef6_n=0, w2504_n=0, w7884_n=0;
                /* 0x0405454c — in exec call chain */
                if (pc == 0x0405454c && w54c_n < 5) {
                    xil_printf("[W@54c] D0=$%08X D1=$%08X A0=$%08X A6=$%08X SP=$%08X\r\n",
                        m68k_get_reg(NULL, M68K_REG_D0), m68k_get_reg(NULL, M68K_REG_D1),
                        m68k_get_reg(NULL, M68K_REG_A0), m68k_get_reg(NULL, M68K_REG_A6),
                        m68k_get_reg(NULL, M68K_REG_A7));
                    w54c_n++;
                }
                /* 0x0405fef6 — return addr in exec chain */
                if (pc == 0x0405fef6 && wfef6_n < 5) {
                    xil_printf("[W@fef6] D0=$%08X D1=$%08X A0=$%08X SP=$%08X\r\n",
                        m68k_get_reg(NULL, M68K_REG_D0), m68k_get_reg(NULL, M68K_REG_D1),
                        m68k_get_reg(NULL, M68K_REG_A0), m68k_get_reg(NULL, M68K_REG_A7));
                    wfef6_n++;
                }
                /* 0x04072504 — load_init_program caller return */
                if (pc == 0x04072504 && w2504_n < 5) {
                    xil_printf("[W@2504] D0=$%08X D1=$%08X SP=$%08X\r\n",
                        m68k_get_reg(NULL, M68K_REG_D0), m68k_get_reg(NULL, M68K_REG_D1),
                        m68k_get_reg(NULL, M68K_REG_A7));
                    w2504_n++;
                }
                /* 0x04067884 — kernel init caller */
                if (pc == 0x04067884 && w7884_n < 5) {
                    xil_printf("[W@7884] D0=$%08X D1=$%08X SP=$%08X\r\n",
                        m68k_get_reg(NULL, M68K_REG_D0), m68k_get_reg(NULL, M68K_REG_D1),
                        m68k_get_reg(NULL, M68K_REG_A7));
                    w7884_n++;
                }

                /* Watch for PEA $040A6980 or MOVE.L #$040A6980 — loading
                 * the "Load of...errno" format string for printf.
                 * Detect by checking if any data register or address reg
                 * contains the string address. Check every 10000 PCs. */
                {
                    static int errno_printf_n = 0;
                    static uint32_t last_errno_check = 0;
                    if (errno_str_addr && errno_printf_n < 2 &&
                        pc >= 0x04060000 && pc <= 0x040A0000) {
                        /* Check A0 for the format string address */
                        uint32_t a0 = m68k_get_reg(NULL, M68K_REG_A0);
                        if (a0 == errno_str_addr) {
                            uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
                            xil_printf("\r\n[ERRNO-PRINTF] PC=$%08X A0=$%08X (format str!)\r\n", pc, a0);
                            xil_printf("[ERRNO-PRINTF] SP=$%08X stack:\r\n", sp);
                            for (int i = 0; i < 10; i++)
                                xil_printf("  SP+%02X: $%08X\r\n", i*4,
                                    m68k_read_memory_32(sp + i*4));
                            /* Dump string at the filename arg (likely SP+4 or SP+8) */
                            uint32_t fn = m68k_read_memory_32(sp + 4);
                            if (fn > 0x04000000 && fn < 0x05000000) {
                                xil_printf("[ERRNO-PRINTF] filename: ");
                                for (int j = 0; j < 30; j++) {
                                    uint8_t ch = m68k_read_memory_8(fn + j);
                                    if (ch == 0) break;
                                    if (ch >= 0x20 && ch < 0x7F) xil_printf("%c", ch);
                                }
                                xil_printf("\r\n");
                            }
                            errno_printf_n++;
                        }
                    }
                }
            }
        }
    }

    if (trace_count < TRACE_LIMIT) {
        uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
        uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
        uint16_t opword = m68k_read_memory_16(pc);
        uint32_t a0 = m68k_get_reg(NULL, M68K_REG_A0);
        uint32_t a1 = m68k_get_reg(NULL, M68K_REG_A1);
        uint32_t d0 = m68k_get_reg(NULL, M68K_REG_D0);
        xil_printf("[T%03d] PC=$%08X SR=$%04X SP=$%08X op=$%04X A0=$%08X A1=$%08X D0=$%08X\r\n",
                   trace_count, pc, sr, sp, opword, a0, a1, d0);
        /* On exception: dump stacked frame */
        if (trace_count > 0 && pc < 0x00001000 && sp < 0x04000400) {
            xil_printf("  [EXC] frame@SP: %08X %08X\r\n",
                       m68k_read_memory_32(sp),
                       m68k_read_memory_32(sp + 4));
        }
        trace_count++;
        if (trace_count == TRACE_LIMIT)
            xil_printf("[TRACE] --- limit reached, tracing off ---\r\n");
    }
}

/* Location to place mon_global stub in RAM (near top of first 64KB) */
#define MON_GLOBAL_ADDR  (NEXT_RAM_BASE + 0x00008000)

/* Forward declarations */
static void next_boot(void);
static void poll_uart_rx(void);

/* ------------------------------------------------------------------ */
/* Musashi interrupt acknowledge callback                              */
/* ------------------------------------------------------------------ */

int emu_int_ack_callback(int int_level)
{
    int vec = next_intr_acknowledge(int_level);
    {
        static int iack_log = 0;
        if (iack_log < 40) {
            uint32_t pc  = m68k_get_reg(NULL, M68K_REG_PC);
            uint32_t vbr = m68k_get_reg(NULL, M68K_REG_VBR);
            int vnum = (vec >= 0) ? vec : (24 + int_level);
            uint32_t handler = next_phys_read_32(vbr + vnum * 4);
            xil_printf("[IACK] ipl=%d vec=%d(%s) PC=$%08X VBR=$%08X handler=$%08X\r\n",
                       int_level, vnum,
                       (vec >= 0) ? "user" : "auto",
                       pc, vbr, handler);
            iack_log++;
        }
    }
    if (vec >= 0)
        return vec;
    return M68K_INT_ACK_AUTOVECTOR;
}

/* ------------------------------------------------------------------ */
/* Main entry point                                                    */
/* ------------------------------------------------------------------ */

int main(void)
{
    /* init_platform enables caches/MMU which may hang under QEMU
     * if the MMU page tables aren't set up by crt0. On real hardware
     * the Xilinx crt0 handles this. Skip for safety under QEMU. */
#ifndef QEMU_MODE
    init_platform();
#endif

    xil_printf("\r\n");
    xil_printf("================================================\r\n");
    xil_printf("  NeXT 68040LC System + MC68882 FPU\r\n");
    xil_printf("  Mach kernel boot emulator\r\n");
    xil_printf("================================================\r\n");

    next_boot();

#ifndef QEMU_MODE
    cleanup_platform();
#endif
    return 0;
}

/* ------------------------------------------------------------------ */
/* NeXT kernel boot                                                    */
/* ------------------------------------------------------------------ */

static void next_boot(void)
{
    uint32_t *pixel_buf;
    int dp_ok = 0;

    /* Initialise emulated memory (16 MB RAM + 128 KB ROM + 256 KB VRAM) */
    next_mem_init();
    xil_printf("[NEXT] Memory: %d MB RAM @ 0x%08X\r\n",
               NEXT_RAM_SIZE / (1024*1024), NEXT_RAM_BASE);

    /* Initialise NeXT hardware stubs */
    next_devs_init();
    next_rtc_init();
    next_dsp_init();
    next_kms_init();
    if (next_scsi_init() == 0) {
        xil_printf("[NEXT] SCSI disk: mounted from SD card\r\n");
        next_ufs_diagnose();
    } else
        xil_printf("[NEXT] SCSI disk: no disk image found\r\n");
    {
        extern uint32_t next_scr1_get(void);
        xil_printf("[NEXT] Device stubs: SCR1=%08X (Turbo)\r\n",
                   next_scr1_get());
    }

    /* Build ROM monitor stub (mon_global) in RAM.  Machine type stays
     * WARP9 — Turbo is indicated via the SCR1_TURBO bit (0x4000) which we
     * set in next_devs_init(). */
    uint32_t mg_addr = next_mon_build(MON_GLOBAL_ADDR,
                                       NEXT_RAM_BASE, NEXT_RAM_SIZE,
                                       NeXT_WARP9);
    xil_printf("[NEXT] mon_global stub @ 0x%08X\r\n", mg_addr);

    /* Load NeXT 68040 Turbo ROM (Rev 3.3 v74, 128 KB).
     * ROM is mapped at both 0x00000000 and 0x01000000 (BMAP).
     * The ROM's vectors: SSP=0x04000400, PC=0x0100001E */
#ifdef TEST_ROM
    next_rom_load(test_rom_data, test_rom_data_len);
    xil_printf("[NEXT] TEST ROM loaded: %u bytes\r\n", test_rom_data_len);
#else
    next_rom_load(next_rom_data, next_rom_data_len);
    xil_printf("[NEXT] ROM loaded: %u bytes\r\n", next_rom_data_len);
#endif

    /* Vectors come directly from the ROM image (first 8 bytes).
     * SSP and PC are already in the ROM at address 0. */

    /* Verify vectors were written correctly */
    xil_printf("[NEXT] Vec0(SSP)=%08X Vec1(PC)=%08X Vec2(BusErr)=%08X\r\n",
               m68k_read_memory_32(0x00000000),
               m68k_read_memory_32(0x00000004),
               m68k_read_memory_32(0x00000008));
    xil_printf("[NEXT] Vec3(AddrErr)=%08X Vec4(Illegal)=%08X Vec5(DivZ)=%08X\r\n",
               m68k_read_memory_32(0x0000000C),
               m68k_read_memory_32(0x00000010),
               m68k_read_memory_32(0x00000014));
    xil_printf("[NEXT] Vec11(Fline)=%08X Vec24(SpurInt)=%08X Vec32(Trap0)=%08X\r\n",
               m68k_read_memory_32(0x0000002C),
               m68k_read_memory_32(0x00000060),
               m68k_read_memory_32(0x00000080));
    /* Dump first 4 instructions at entry point */
    xil_printf("[NEXT] ROM @entry: %04X %04X %04X %04X %04X %04X %04X %04X\r\n",
               m68k_read_memory_16(0x0100001E),
               m68k_read_memory_16(0x01000020),
               m68k_read_memory_16(0x01000022),
               m68k_read_memory_16(0x01000024),
               m68k_read_memory_16(0x01000026),
               m68k_read_memory_16(0x01000028),
               m68k_read_memory_16(0x0100002A),
               m68k_read_memory_16(0x0100002C));

    /* Initialise F-line handler (hardware FPU via AXI-Lite).
     * FSAVE/FRESTORE translate between 68882 and 68040 frame formats
     * so the Turbo ROM's POST accepts the FPU. */
#ifndef QEMU_MODE
    if (fline_init() != 0)
        xil_printf("[NEXT] WARNING: F-line handler init failed\r\n");
#endif

    /* Initialise text framebuffer (provides the pixel buffer) */
    pixel_buf = text_fb_init();

    /* Initialise NeXT VRAM → pixel buffer converter */
    next_video_init(pixel_buf, next_vram);

#ifndef QEMU_MODE
    {
        int status = dp_video_init(pixel_buf);
        if (status == 0) dp_ok = 1;
    }

    /* Start core 1 for display rendering (non-blocking) */
    render_core1_start(pixel_buf, dp_ok);
#endif

    /* Initialise Musashi as 68LC040 (68040 without internal FPU).
     * Interrupt-ack and illegal/F-line callbacks are bound at compile
     * time via m68kconf.h (emu_int_ack_callback, fline_illg_callback). */
    m68k_set_cpu_type(M68K_CPU_TYPE_68LC040);
    m68k_init();
    m68k_pulse_reset();

    xil_printf("[NEXT] 68LC040 reset — entering emulation loop\r\n");
    xil_printf("================================================\r\n");

    /* Main emulation loop */
    while (1) {
        int cycles_run = m68k_execute(EMU_CYCLES_PER_TICK);

        /* Advance timer, RTC, and check for interrupts */
        next_timer_tick(cycles_run);
        next_rtc_tick(cycles_run);

        int ipl = next_intr_pending_ipl();
        m68k_set_irq(ipl);

        /* Detect framebuffer text changes — kernel printf goes to VRAM */
        {
            static uint32_t last_vram_hash = 0;
            static int vram_check_counter = 0;
            if (++vram_check_counter >= 500) {  /* check every ~200ms */
                vram_check_counter = 0;
                extern unsigned char next_vram[];
                {
                    /* Hash first 4K of VRAM (top lines of display) */
                    uint32_t hash = 0;
                    for (int i = 0; i < 4096; i += 4)
                        hash ^= *(uint32_t*)(next_vram + i);
                    if (hash != last_vram_hash && last_vram_hash != 0) {
                        xil_printf("[VRAM] Display changed! (hash $%08X → $%08X)\r\n",
                                   last_vram_hash, hash);
                        /* Force a video refresh */
                    }
                    last_vram_hash = hash;
                }
            }
        }

        /* After ROM settles, find mon_global and dump key fields (one-shot).
         * The ROM may store mg pointer at P_MON, or we can find it via A5
         * (the ROM monitor typically keeps mg in A5). */
        {
            static int mg_dumped = 0;
            if (!mg_dumped) {
                uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
                if (pc >= 0x01002000 && pc <= 0x01003000) {
                    /* Find mon_global: ROM keeps it in A3, stored in VRAM */
                    uint32_t mg = next_get_mon_global();
                    if (mg == 0)
                        mg = m68k_get_reg(NULL, M68K_REG_A3);

                    /* Validate by checking mg_pagesize at MG offset 10 */
                    uint32_t pgsz = m68k_read_memory_32(mg + 10);
                    if (pgsz == 8192 || pgsz == 4096) {
                        uint16_t mg_seq = m68k_read_memory_16(mg + 780);
                        xil_printf("[MG] mon_global=$%08X seq=%d\r\n", mg, mg_seq);
                    }
                    /* Dump VRAM content stats */
                    int zeros = 0, ffs = 0, aas = 0, other = 0;
                    for (int i = 0; i < 239616; i++) {
                        uint8_t v = next_vram[i];
                        if (v == 0x00) zeros++;
                        else if (v == 0xFF) ffs++;
                        else if (v == 0xAA) aas++;
                        else other++;
                    }
                    xil_printf("[VRAM] zeros=%d FF=%d AA=%d other=%d\r\n",
                               zeros, ffs, aas, other);
                    /* Force full render + refresh */
#ifndef QEMU_MODE
                    next_vram_mark_all_dirty();
                    if (render_core1_is_active()) {
                        render_core1_request(1);
                    } else {
                        int min_y, max_y;
                        if (next_video_render_dirty(&min_y, &max_y)) {
                            Xil_DCacheFlushRange(
                                (UINTPTR)pixel_buf + ((UINTPTR)min_y * SCREEN_W * 4),
                                (UINTPTR)(max_y - min_y + 1) * SCREEN_W * 4);
                            if (dp_ok) dp_video_refresh();
                        }
                    }
#endif
                    xil_printf("[VRAM] Forced render complete\r\n");

                    mg_dumped = 1;
                }
            }
        }

        /* PC trace (debug: print every ~2 seconds) */
#if 0
        {
            static int sample_count = 0;
            if (++sample_count >= 500) {
                sample_count = 0;
                uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
                uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
                uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
                uint32_t d3 = m68k_get_reg(NULL, M68K_REG_D3);
                xil_printf("[PC] $%08X SR=$%04X SP=$%08X D3=$%08X\r\n", pc, sr, sp, d3);

                /* Detect stuck PC */
                static uint32_t prev_pc = 0;
                static int stuck = 0;
                if (pc == prev_pc) {
                    if (++stuck >= 10) {
                        /* Don't halt if PC is in ROM address space
                         * (ROM monitor input poll or other loops). */
                        if (pc < 0x01000000 || pc > 0x01020000) {
                            xil_printf("[HALT] PC stuck at $%08X - stopping\r\n", pc);
                            return;
                        }
                        stuck = 0;  /* reset — it's the monitor loop */
                    }
                } else {
                    stuck = 0;
                }
                prev_pc = pc;
            }
        }
#endif

        /* Request display refresh on core 1 (non-blocking).
         * Core 1 handles rendering + cache flush + DP refresh. */
        {
            static int next_vram_active = 0;
            static int refresh_count = 0;

            if (next_vram_is_dirty()) {
                if (!next_vram_active) {
                    xil_printf("[VIDEO] NeXT VRAM active, stride=%d bytes/line\r\n",
                               NEXT_VIDEO_NBPL);
                    next_vram_active = 1;
                }
                next_vram_mark_clean();
                if (++refresh_count >= 2) {
                    refresh_count = 0;
#ifndef QEMU_MODE
                    if (render_core1_is_active()) {
                        render_core1_request(1);  /* 1 = next_vram mode */
                    } else {
                        /* Fallback: render on core 0 if core 1 didn't start */
                        int min_y, max_y;
                        if (next_video_render_dirty(&min_y, &max_y)) {
                            Xil_DCacheFlushRange(
                                (UINTPTR)pixel_buf + ((UINTPTR)min_y * SCREEN_W * 4),
                                (UINTPTR)(max_y - min_y + 1) * SCREEN_W * 4);
                            if (dp_ok) dp_video_refresh();
                        }
                    }
#endif
                }
            } else if (!next_vram_active) {
#ifndef QEMU_MODE
                if (render_core1_is_active()) {
                    if (text_fb_is_dirty())
                        render_core1_request(0);  /* 0 = text_fb mode */
                } else if (text_fb_is_dirty()) {
                    text_fb_render();
                    text_fb_mark_clean();
                    Xil_DCacheFlushRange(
                        (UINTPTR)pixel_buf + (TEXT_OFS_Y * SCREEN_W * 4),
                        (SCREEN_H - TEXT_OFS_Y) * SCREEN_W * 4);
                    if (dp_ok) dp_video_refresh();
                }
#endif
            }
        }

        /* Feed ARM UART RX into SCC RX buffer */
        poll_uart_rx();
    }
}

/* ------------------------------------------------------------------ */
/* UART RX polling — pass ARM UART input to SCC RX buffer              */
/* ------------------------------------------------------------------ */

static void poll_uart_rx(void)
{
#ifdef XPAR_XUARTPS_0_BASEADDR
    /* ZynqMP UART status register: bit 1 = RXEMPTY.
     * Poll while RX FIFO has data and push bytes into SCC RX buffer.
     * Works on both real hardware and QEMU's ZynqMP UART model. */
    volatile uint32_t *uart_sr   = (volatile uint32_t *)(XPAR_XUARTPS_0_BASEADDR + 0x2C);
    volatile uint32_t *uart_fifo = (volatile uint32_t *)(XPAR_XUARTPS_0_BASEADDR + 0x30);
    while (!((*uart_sr) & 0x02)) {  /* while RXEMPTY == 0 */
        uint8_t ch = (uint8_t)(*uart_fifo & 0xFF);
        if (ch == 'X') {
            /* Debug dump on 'X' keypress */
            uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
            uint16_t sr = m68k_get_reg(NULL, M68K_REG_SR);
            uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
            xil_printf("\r\n[DUMP] PC=$%08X SR=$%04X SP=$%08X\r\n", pc, sr, sp);
            xil_printf("[DUMP] D0=$%08X D1=$%08X D2=$%08X D3=$%08X\r\n",
                m68k_get_reg(NULL, M68K_REG_D0), m68k_get_reg(NULL, M68K_REG_D1),
                m68k_get_reg(NULL, M68K_REG_D2), m68k_get_reg(NULL, M68K_REG_D3));
            xil_printf("[DUMP] A0=$%08X A1=$%08X A2=$%08X A3=$%08X\r\n",
                m68k_get_reg(NULL, M68K_REG_A0), m68k_get_reg(NULL, M68K_REG_A1),
                m68k_get_reg(NULL, M68K_REG_A2), m68k_get_reg(NULL, M68K_REG_A3));
            xil_printf("[DUMP] A4=$%08X A5=$%08X A6=$%08X A7=$%08X\r\n",
                m68k_get_reg(NULL, M68K_REG_A4), m68k_get_reg(NULL, M68K_REG_A5),
                m68k_get_reg(NULL, M68K_REG_A6), m68k_get_reg(NULL, M68K_REG_A7));
            xil_printf("[DUMP] USP=$%08X\r\n",
                m68k_get_reg(NULL, M68K_REG_USP));
            {
                extern void mmu040_dump_regs(void);
                mmu040_dump_regs();
            }
            /* Stack dump: translate VA→PA through MMU for virtual stacks */
            {
                extern unsigned int pmmu_translate_addr(unsigned int addr_in);
                uint32_t sp_pa = pmmu_translate_addr(sp);
                xil_printf("[DUMP] Stack VA=$%08X → PA=$%08X:\r\n", sp, sp_pa);
                for (int i = 0; i < 16; i++) {
                    uint32_t va = sp + i*4;
                    uint32_t pa = pmmu_translate_addr(va);
                    uint32_t val = next_phys_read_32(pa);
                    xil_printf("  SP+%02X: $%08X  (VA=$%08X PA=$%08X)\r\n",
                               i*4, val, va, pa);
                }
            }
            /* Code dump: translate VA→PA for PC too */
            {
                extern unsigned int pmmu_translate_addr(unsigned int addr_in);
                uint32_t pc_pa = pmmu_translate_addr(pc);
                xil_printf("[DUMP] Code at PC VA=$%08X → PA=$%08X:\r\n  ", pc, pc_pa);
                for (int i = 0; i < 8; i++) {
                    uint32_t pa = pmmu_translate_addr(pc + i*4);
                    uint32_t val = next_phys_read_32(pa);
                    xil_printf("%08X ", val);
                }
                xil_printf("\r\n");
            }
            continue;  /* don't forward 'X' to SCC */
        }
        if (ch == 'U') {
            /* Dump syscall/trap ring buffer — last 32 user→kernel traps */
            xil_printf("\r\n");
            trap_log_dump();
            continue;
        }
        if (ch == 'D') {
            /* Toggle SCSI/DMA/interrupt debug logging */
            extern int next_debug_scsi;
            next_debug_scsi = !next_debug_scsi;
            xil_printf("\r\n[DEBUG] SCSI/DMA/IRQ logging %s\r\n",
                       next_debug_scsi ? "ON" : "OFF");
            /* Snapshot interrupt state */
            xil_printf("[DEBUG] intr_status=$%08X intr_mask=$%08X pending_ipl=%d\r\n",
                       next_intr_get_status(), next_intr_get_mask(),
                       next_intr_pending_ipl());
            /* Dump ESP IRQ event ring buffer */
            {
                extern void esp_dump_irq_log(void);
                esp_dump_irq_log();
            }
            /* Dump live I/O activity */
            {
                extern void io_activity_dump(void);
                io_activity_dump();
            }
            /* Dump sfa state */
            {
                extern void sfa_dump(void);
                sfa_dump();
            }
            continue;
        }
        if (ch == 'T') {
            /* Trace: log PC for next N cycles */
            static int trace_active = 0;
            trace_active = !trace_active;
            if (trace_active) {
                xil_printf("\r\n[TRACE] PC logging ON (next 200 instructions)\r\n");
                extern int next_trace_count;
                next_trace_count = 200;
            } else {
                xil_printf("\r\n[TRACE] PC logging OFF\r\n");
                extern int next_trace_count;
                next_trace_count = 0;
            }
            continue;
        }
        if (ch == 'I') {
            /* Toggle verbose I/O logging (all device register accesses) */
            extern int next_debug_io;
            extern int io_log_count;
            next_debug_io = !next_debug_io;
            io_log_count = 0;  /* reset counter on each toggle-on */
            xil_printf("\r\n[DEBUG] I/O logging %s (auto-stops after 500 lines)\r\n",
                       next_debug_io ? "ON" : "OFF");
            continue;
        }
        if (ch == 'F') {
            /* Dump page fault / RTE Format 7 statistics */
            extern int rte_format7_count;
            extern int scsi_read_log_count(void);
            extern int mmu040_fault_total;
            extern int mmu040_fault_reset_at;
            xil_printf("\r\n[FAULT] ATC faults: %d total, %d since BUSRST\r\n",
                       mmu040_fault_total,
                       mmu040_fault_total - mmu040_fault_reset_at);
            xil_printf("[FAULT] RTE Format 7 completions: %d\r\n",
                       rte_format7_count);
            xil_printf("[FAULT] SCSI READs since last BUSRST: %d\r\n",
                       scsi_read_log_count());
            continue;
        }
        next_scc_rx_push(ch);    /* SCC serial path */
        next_kms_push_ascii(ch); /* KMS keyboard path (ROM monitor) */
    }
#endif
}
