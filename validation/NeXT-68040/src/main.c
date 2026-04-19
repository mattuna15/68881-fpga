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
#include "next_debug.h"
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
#include "next_scsi_dma.h"
#include "next_esp.h"
#include "next_ufs_diag.h"
#include "next_video.h"
#include "text_fb.h"
#include "dp_video.h"
#include "render_core1.h"

/* Number of M68K instructions to execute per main-loop tick.
 * Interrupt delivery latency is no longer gated by this value —
 * next_intr_set() now calls m68k_set_irq() immediately so interrupts
 * fire on the very next instruction, just like real hardware. */
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
    uint32_t urp;      /* URP at trap time — for per-process VA translation */
    uint16_t sr;       /* SR before trap (bit 13 = user/super) */
    uint8_t  trap_num; /* TRAP #N (0-15) */
    uint32_t body[8];  /* msg_rpc/msg_send body captured at trap entry —
                        * 32 bytes starting at (D1 + 24), translated through
                        * the per-trap URP. Only populated for TRAP#3 with
                        * d0 = 0x14/0x16 and d1 >= 0x1000. */
} trap_log[TRAP_LOG_SIZE];

extern unsigned int fh_get_urp(void);
extern unsigned int fh_get_srp(void);
extern unsigned int mmu040_translate_with_urp(unsigned int urp, unsigned int va);
extern unsigned int mmu040_translate_user(unsigned int va);

/* Best-effort MMU-translated 32-bit read: walks the given URP, then hits
 * the physical callback.  On translation failure, returns 0xFFFFFFFF so
 * the diagnostic dumper can show "no mapping" without faulting. */
static uint32_t trap_read_u32(uint32_t urp, uint32_t va)
{
    uint32_t pa = mmu040_translate_with_urp(urp, va);
    if (pa == va) return 0xFFFFFFFFu;  /* translation failed */
    return next_phys_read_32(pa);
}
static int trap_log_idx = 0;
static int trap_log_total = 0;

/* Counter: set by next_intr_set for SCSI interrupts.  Counts down each
 * instruction; delivers when it reaches 0.  10 instructions gives the
 * polling code time to set STF_POLL_IP after splx, while still being
 * fast enough to prevent the SVF_ACTIVE / biowait deadlock. */
volatile int next_irq_pending_update = 0;

/* User-mode execution tracker — counts instructions + last 4 PCs + URP */
static uint32_t user_instr_count = 0;
static uint32_t user_last_pc[4];
static uint32_t user_last_urp = 0;  /* URP active during last user instruction */
static int user_last_idx = 0;
int emu_user_mode_flag = 0;
int emu_idle_entered = 0;  /* set by instr hook when idle_thread detected */

/* URP switch log — each entry records a user-mode URP change (thread/proc
 * switch visible from user mode).  Helps diagnose "stuck in msg_recv"
 * stalls: if no URPs rotate, no other thread is being scheduled. */
#define URP_LOG_SIZE 32
static struct {
    uint32_t instr_count;  /* user_instr_count at the switch */
    uint32_t urp;          /* new URP */
    uint32_t pc;           /* user PC at the switch */
} urp_log[URP_LOG_SIZE];
static int urp_log_idx = 0;
static int urp_log_total = 0;

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
    trap_log[idx].urp = fh_get_urp();
    uint32_t urp = trap_log[idx].urp;
    /* For Unix syscalls (TRAP#4), capture args from user stack.
     * BSD convention: args at USP+4, USP+8, USP+12.  User VAs — must go
     * through the current URP before hitting the physical callback. */
    if (trap_num == 4 && sp >= 0x1000) {
        trap_log[idx].arg1 = trap_read_u32(urp, sp + 4);
        trap_log[idx].arg2 = trap_read_u32(urp, sp + 8);
        trap_log[idx].arg3 = trap_read_u32(urp, sp + 12);
    } else if (trap_num == 3 && (d0 == 0x15 || d0 == 0x16 || d0 == 0x14)) {
        /* Mach msg traps: D1 = msg header pointer (user VA).
         * msg_local_port at offset 12, remote at 16, id at 20. */
        if (d1 >= 0x1000) {
            trap_log[idx].arg1 = trap_read_u32(urp, d1 + 12);
            trap_log[idx].arg2 = trap_read_u32(urp, d1 + 16);
            trap_log[idx].arg3 = trap_read_u32(urp, d1 + 20);
            /* Snapshot 32 bytes of body past the 24-byte header.  The
             * user stack gets reused after this trap returns, so by the
             * time trap_log_dump runs the live bytes would be stale.
             * Capture them NOW while the caller's frame is still live. */
            if (d0 == 0x16 || d0 == 0x14) {
                for (int k = 0; k < 8; k++)
                    trap_log[idx].body[k] = trap_read_u32(urp, d1 + 24 + k*4);
            } else {
                for (int k = 0; k < 8; k++) trap_log[idx].body[k] = 0;
            }
        } else {
            trap_log[idx].arg1 = 0;
            trap_log[idx].arg2 = 0;
            trap_log[idx].arg3 = 0;
            for (int k = 0; k < 8; k++) trap_log[idx].body[k] = 0;
        }
    } else {
        trap_log[idx].arg1 = 0;
        trap_log[idx].arg2 = 0;
        trap_log[idx].arg3 = 0;
        for (int k = 0; k < 8; k++) trap_log[idx].body[k] = 0;
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
            /* Wide window: -48..+16 words around the trap site so we can
             * disassemble the calling function and its prologue. */
            for (int i = -48; i < 16; i++) {
                if (i > -48 && (i % 16) == 0)
                    xil_printf("\r\n  ");
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
            /* Print the 32 bytes of body captured at trap entry for
             * msg_rpc/msg_send calls.  Captured in emu_trap_log before
             * the user stack got reused.  Annotate known mach-subsystem
             * routine ids — remember the DESTINATION is arg2 (remote),
             * not arg1 (which is the reply port for msg_rpc). */
            if ((trap_log[idx].d0 == 0x16 || trap_log[idx].d0 == 0x14) &&
                trap_log[idx].d1 >= 0x1000) {
                int id = trap_log[idx].arg3;
                const char *rname = NULL;
                /* mach subsystem base 2000. Verified against the SERVER
                 * dispatch table at kern/mach_server.c:6494 — use that,
                 * not the .defs file (which contains obsolete placeholder
                 * routines that skew simple counting). */
                if (id == 2007) rname = "task_create";
                else if (id == 2008) rname = "task_terminate";
                else if (id == 2011) rname = "task_threads";
                else if (id == 2016) rname = "thread_terminate";
                else if (id == 2021) rname = "vm_allocate";
                else if (id == 2023) rname = "vm_deallocate";
                else if (id == 2024) rname = "vm_protect";
                else if (id == 2026) rname = "vm_read";
                else if (id == 2027) rname = "vm_write";
                else if (id == 2029) rname = "vm_region";
                else if (id == 2030) rname = "vm_statistics";
                else if (id == 2031) rname = "task_by_unix_pid";
                else if (id == 2056) rname = "task_suspend";
                else if (id == 2057) rname = "task_resume";
                else if (id == 2058) rname = "task_get_special_port";
                else if (id == 2059) rname = "task_set_special_port";
                else if (id == 2060) rname = "task_info";
                else if (id == 2062) rname = "thread_suspend";
                else if (id == 2063) rname = "thread_resume";
                else if (id == 2064) rname = "thread_abort";
                else if (id == 2067) rname = "thread_get_special_port";
                else if (id == 2068) rname = "thread_set_special_port";
                else if (id == 2073) rname = "port_names";
                else if (id == 2074) rname = "port_type";
                else if (id == 2075) rname = "port_rename";
                else if (id == 2076) rname = "port_allocate";
                else if (id == 2077) rname = "port_deallocate";
                else if (id == 2078) rname = "port_set_backlog";
                else if (id == 2079) rname = "port_status";
                else if (id == 2080) rname = "port_set_allocate";
                else if (id == 2082) rname = "port_set_add";
                else if (id == 2085) rname = "port_insert_send";
                else if (id == 2087) rname = "port_insert_receive";
                xil_printf("      ~ %s body:",
                           rname ? rname : "(unknown)");
                for (int k = 0; k < 8; k++)
                    xil_printf(" %08X", trap_log[idx].body[k]);
                xil_printf("\r\n");
            }
        } else {
            /* Decode the mach trap selector for TRAP#3 entries (per
             * kern/syscall_sw.c:155 mach_trap_table). */
            const char *mname = NULL;
            if (trap_log[idx].trap_num == 3) {
                switch (trap_log[idx].d0) {
                    case 10: mname = "task_self"; break;
                    case 11: mname = "thread_reply"; break;
                    case 12: mname = "task_notify"; break;
                    case 13: mname = "thread_self"; break;
                    case 20: mname = "msg_send"; break;
                    case 21: mname = "msg_receive"; break;
                    case 22: mname = "msg_rpc"; break;
                    case 33: mname = "task_by_pid"; break;
                    case 40: mname = "mach_swapon"; break;
                    case 41: mname = "init_process"; break;
                    case 43: mname = "map_fd"; break;
                    case 51: mname = "kern_timestamp"; break;
                    case 55: mname = "host_self"; break;
                    case 56: mname = "host_priv_self"; break;
                    case 59: mname = "swtch_pri"; break;
                    case 60: mname = "swtch"; break;
                    case 61: mname = "thread_switch"; break;
                }
            }
            if (mname)
                xil_printf("  [%d] TRAP#%d (%s/%s) D1=$%08X PC=$%08X SP=$%08X SR=$%04X\r\n",
                           i, trap_log[idx].trap_num, kind, mname,
                           trap_log[idx].d1,
                           trap_log[idx].pc, trap_log[idx].sp, trap_log[idx].sr);
            else
                xil_printf("  [%d] TRAP#%d (%s) D0=$%08X D1=$%08X PC=$%08X SP=$%08X SR=$%04X\r\n",
                           i, trap_log[idx].trap_num, kind,
                           trap_log[idx].d0, trap_log[idx].d1,
                           trap_log[idx].pc, trap_log[idx].sp, trap_log[idx].sr);
        }
    }
    /* Dump msg_header for the last msg_recv/msg_rpc.  We walk the URP
     * captured at trap entry, because "current" URP at dump time is some
     * other process (we hang in kernel context after many context
     * switches).  Without the per-trap URP the walk goes through empty
     * L1 slots and we see "read from unmapped" even though the buffer
     * was fully mapped when the trap fired. */
    for (int i = count - 1; i >= 0; i--) {
        int idx2 = ((start + i) % TRAP_LOG_SIZE);
        if (trap_log[idx2].trap_num == 3 &&
            (trap_log[idx2].d0 == 0x15 || trap_log[idx2].d0 == 0x16) &&
            trap_log[idx2].d1 >= 0x1000) {
            uint32_t msg_va = trap_log[idx2].d1;
            uint32_t urp    = trap_log[idx2].urp;
            xil_printf("[MSG-HDR] %s buf at VA=$%08X (URP=$%08X):\r\n",
                       trap_log[idx2].d0 == 0x15 ? "msg_recv" : "msg_rpc",
                       msg_va, urp);
            for (int j = 0; j < 24; j += 4) {
                uint32_t val = trap_read_u32(urp, msg_va + j);
                const char *fname = "";
                if (j == 0)  fname = " (simple+unused)";
                if (j == 4)  fname = " (msg_size)";
                if (j == 8)  fname = " (msg_type)";
                if (j == 12) fname = " (local_port)";
                if (j == 16) fname = " (remote_port)";
                if (j == 20) fname = " (msg_id)";
                if (val == 0xFFFFFFFFu)
                    xil_printf("  +%02d: <unmapped>%s\r\n", j, fname);
                else
                    xil_printf("  +%02d: $%08X%s\r\n", j, val, fname);
            }
            break;
        }
    }
    /* URP-switch log: shows thread/process rotations seen from user mode.
     * If this is empty or has only 1 entry after the stall, the scheduler
     * is not rotating threads — the "stuck in msg_recv" is actually a
     * single-thread busy wait or missed wakeup. */
    xil_printf("[URP-LOG] %d switches total, %u user instrs:\r\n",
               urp_log_total, user_instr_count);
    int ustart = urp_log_total < URP_LOG_SIZE ? 0 : urp_log_idx;
    int ucount = urp_log_total < URP_LOG_SIZE ? urp_log_total : URP_LOG_SIZE;
    for (int i = 0; i < ucount; i++) {
        int idx = (ustart + i) % URP_LOG_SIZE;
        xil_printf("  [%d] instr=%u URP=$%08X PC=$%08X\r\n",
                   i, urp_log[idx].instr_count,
                   urp_log[idx].urp, urp_log[idx].pc);
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
#define PC_RING_SIZE 64
static uint32_t pc_ring[PC_RING_SIZE];
static uint32_t pc_ring_idx;

/* Global instruction counter for cross-module timing diagnostics. */
uint64_t emu_instr_count;

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
    /* Deliver deferred SCSI interrupts after a short countdown.
     * The polling code (scsi_pollcmd) needs ~10 instructions after the
     * ESP command write to execute splx and set STF_POLL_IP.  Delivering
     * too soon causes the interrupt to fire before the flag is set,
     * breaking the generic SCSI probe.  Delivering too late (10K insns)
     * causes the SVF_ACTIVE / biowait deadlock. */
    if (next_irq_pending_update > 0) {
        if (--next_irq_pending_update == 0)
            m68k_set_irq(next_intr_pending_ipl());
    }

    /* Deferred DMA completion: the synchronous ESP model completes DMA
     * inside the ESP command write callback, but the resulting interrupt
     * must fire on a separate instruction boundary so the CPU can take
     * it before the kernel's next DMA RESET clears it. */
    next_scsi_dma_tick();

    /* Deferred SELECT TIMEOUT: the real 53C9x waits ~250 µs before
     * signalling DISCONNECT on select timeout.  Defer ~500 instructions
     * so the kernel's scsi_pollcmd setup finishes before scintr runs. */
    next_esp_select_timeout_tick();

    emu_instr_count++;
    pc_ring[pc_ring_idx % PC_RING_SIZE] = pc;
    pc_ring_idx++;

#if NEXT_DEBUG_OUTER_BTST
    /* Probe: identify the OUTER-loop polling target.  PC=$040146BC is the
     * BTST.B #0, (0x67, A3) instruction at the top of the loop.  Log A3
     * and the byte at A3+$67 the first few times, plus every 5000th after. */
    if (pc == 0x040146BC) {
        static int btst_log = 0;
        if (btst_log < 8 || (btst_log % 5000) == 0) {
            uint32_t a3 = m68k_get_reg(NULL, M68K_REG_A3);
            uint32_t flagbyte_addr = a3 + 0x67;
            uint32_t word = next_phys_read_32(flagbyte_addr & ~3);
            int shift = ((flagbyte_addr & 3) ^ 3) * 8;
            uint8_t flagbyte = (word >> shift) & 0xFF;
            xil_printf("[OUTER-BTST] #%d A3=$%08X (A3+$67)=$%08X val=$%02X instr=%u\r\n",
                       btst_log, a3, flagbyte_addr, flagbyte,
                       (uint32_t)emu_instr_count);
            /* Also dump 32 bytes around A3+$67 so we can see neighbouring
             * fields (might be a whole flags word). */
            if (btst_log < 3) {
                for (int off = -16; off < 24; off += 8) {
                    uint32_t addr = (a3 + 0x67 + off) & ~3;
                    xil_printf("  $%08X: %08X %08X\r\n", addr,
                               next_phys_read_32(addr),
                               next_phys_read_32(addr + 4));
                }
            }
        }
        btst_log++;
    }
#endif /* NEXT_DEBUG_OUTER_BTST */

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

            uint32_t cur_urp = fh_get_urp();
            if (cur_urp != user_last_urp) {
                int ui = urp_log_idx;
                urp_log[ui].instr_count = user_instr_count;
                urp_log[ui].urp = cur_urp;
                urp_log[ui].pc  = pc;
                urp_log_idx = (urp_log_idx + 1) % URP_LOG_SIZE;
                urp_log_total++;
                user_last_urp = cur_urp;
            }
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

    /* Watch for TRAP #4 (UNIX syscall) — log every one we see, with
     * D0 (syscall number), D1/D2/D3 (register args), and for syscall
     * 5 (open) also try to read the path string through URP.
     *
     * We don't pre-read the opcode because at some instruction boundaries
     * m68k_read_memory_16 may go through a cache path that doesn't match
     * the exec stream. Instead, catch TRAP #4 by its known PCs from the
     * trap log: $00012C98, $0000C564, $0000C320, $0000CAC6, $00013ACE.
     * Any instruction that's ABOUT to execute at one of these addresses
     * in user mode IS our TRAP #4. */
    /* Set once we observe the open("/dev/console") trap — turns on the
     * supervisor-side PC sampler below so we can locate where the kernel
     * blocks inside cnopen. */
    static int console_open_trace = 0;
    {
        static int trap4_seen[10];
        static int trap4_count = 0;
        uint32_t trap_sr = m68k_get_reg(NULL, M68K_REG_SR);
        int is_user = !(trap_sr & 0x2000);
        int is_trap4_pc = (pc == 0x0000CAC6 || pc == 0x0000C320 ||
                           pc == 0x0000C564 || pc == 0x00012C98 ||
                           pc == 0x00013ACE);
        if (is_user && is_trap4_pc && trap4_count < 10) {
            int already = 0;
            for (int k = 0; k < trap4_count; k++)
                if (trap4_seen[k] == (int)pc) { already = 1; break; }
            if (!already) {
                trap4_seen[trap4_count++] = (int)pc;
                uint32_t d0 = m68k_get_reg(NULL, M68K_REG_D0);
                uint32_t d1 = m68k_get_reg(NULL, M68K_REG_D1);
                uint32_t d2 = m68k_get_reg(NULL, M68K_REG_D2);
                uint32_t d3 = m68k_get_reg(NULL, M68K_REG_D3);
                xil_printf("[SYSCALL] D0=%u (trap#4) D1=$%08X D2=$%08X D3=$%08X PC=$%08X\r\n",
                           (unsigned)d0, d1, d2, d3, pc);
                if (d0 == 5) {                    /* open */
                    /* Dump context window $d1-32 .. $d1+64 so we see
                     * what's before/after the pointer — if the real
                     * filename is just off by a few bytes we'll spot
                     * it. Cross-check via direct-phys read
                     * (next_phys_read_32 → skips Musashi memory layer)
                     * vs m68k_read_memory_8 (goes through Musashi). */
                    xil_printf("[OPEN] context window $%08X-32..+64:\r\n",
                               d1);
                    for (int row = 0; row < 6; row++) {
                        uint32_t base = (d1 & ~3u) - 32 + row*16;
                        xil_printf("  $%08X: ", base);
                        /* Phys read via URP translation */
                        for (int col = 0; col < 16; col += 4) {
                            uint32_t pa = mmu040_translate_user(base + col);
                            if (pa == 0xFFFFFFFFu) {
                                xil_printf("-------- ");
                            } else {
                                uint32_t w = next_phys_read_32(pa);
                                xil_printf("%08X ", w);
                            }
                        }
                        /* ASCII sidebar */
                        xil_printf("| ");
                        for (int col = 0; col < 16; col++) {
                            uint32_t pa = mmu040_translate_user(base + col);
                            if (pa == 0xFFFFFFFFu) {
                                xil_printf(".");
                            } else {
                                uint8_t b = next_phys_read_32(pa & ~3u) >>
                                            ((3 - (col & 3)) * 8);
                                if (b >= 0x20 && b < 0x7F)
                                    xil_printf("%c", b);
                                else
                                    xil_printf(".");
                            }
                        }
                        xil_printf("\r\n");
                    }
                    /* Also the null-terminated string at d1, via BOTH
                     * read paths for cross-check. */
                    char via_musashi[65], via_phys[65];
                    int i;
                    for (i = 0; i < 64; i++) {
                        uint32_t pa = mmu040_translate_user(d1 + i);
                        if (pa == 0xFFFFFFFFu) {
                            via_musashi[i] = via_phys[i] = 0;
                            break;
                        }
                        via_musashi[i] = m68k_read_memory_8(d1 + i);
                        uint32_t word = next_phys_read_32(pa & ~3u);
                        via_phys[i] = (word >> ((3 - ((d1 + i) & 3)) * 8))
                                       & 0xFF;
                        if (via_phys[i] == 0) {
                            via_musashi[i + 1] = via_phys[i + 1] = 0;
                            break;
                        }
                    }
                    via_musashi[64] = via_phys[64] = 0;
                    xil_printf("[OPEN] via m68k_read_memory_8: \"%s\"\r\n",
                               via_musashi);
                    xil_printf("[OPEN] via next_phys_read_32:  \"%s\"\r\n",
                               via_phys);
                    /* If this is /dev/console, turn on the supervisor
                     * PC sampler so we can see where the kernel blocks. */
                    if (via_phys[0] == '/' && via_phys[1] == 'd' &&
                        via_phys[2] == 'e' && via_phys[3] == 'v') {
                        console_open_trace = 1;
                        xil_printf("[OPEN] tracing kernel after this trap\r\n");
                    }
                }
            }
        }
    }

    /* Supervisor PC sampler — once the open("/dev/console") trap fires,
     * sample kernel PC periodically so we can locate the sleep/wait site.
     * Also tracks unique PCs seen in a small ring so we can tell whether
     * the kernel is looping or advancing. */
    if (console_open_trace) {
        uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
        int is_super = (sr & 0x2000) != 0;
        static int banner = 0;
        /* Linear PC history: record distinct PCs until full OR until we
         * first hit the idle range. Non-circular — we want the FIRST
         * PCs after the trap (sys_open path), not the most recent
         * (scheduler/idle housekeeping). */
        #define KHIST_MAX 2048
        static uint32_t hist[KHIST_MAX];
        static int hist_count = 0;
        static int hist_frozen = 0;
        static int idle_dumped = 0;
        static uint32_t prev_pc = 0;
        if (is_super) {
            if (!banner) {
                banner = 1;
                xil_printf("[KTRACE] entered supervisor after open trap PC=$%08X\r\n", pc);
            }
            int in_idle = (pc >= 0x040674D0 && pc <= 0x04067504);
            /* Snapshot registers each time we enter the scheduler
             * ($0406B6F8).  The LAST snapshot before idle is the
             * blocking sleep's call site — its stack has the sleep
             * channel and return address chain. */
            static uint32_t sched_sp = 0, sched_a6 = 0, sched_d0 = 0,
                            sched_d1 = 0, sched_a0 = 0, sched_a1 = 0;
            static int sched_snaps = 0;
            if (pc == 0x0406B6F8) {
                sched_sp = m68k_get_reg(NULL, M68K_REG_A7);
                sched_a6 = m68k_get_reg(NULL, M68K_REG_A6);
                sched_d0 = m68k_get_reg(NULL, M68K_REG_D0);
                sched_d1 = m68k_get_reg(NULL, M68K_REG_D1);
                sched_a0 = m68k_get_reg(NULL, M68K_REG_A0);
                sched_a1 = m68k_get_reg(NULL, M68K_REG_A1);
                sched_snaps++;
            }
            if (!hist_frozen && pc != prev_pc) {
                if (in_idle || hist_count >= KHIST_MAX) {
                    hist_frozen = 1;
                } else {
                    hist[hist_count++] = pc;
                    prev_pc = pc;
                }
            }
            if (!idle_dumped && in_idle) {
                idle_dumped = 1;
                emu_idle_entered = 1;  /* signal main loop heartbeat */
                xil_printf("[KTRACE] entering idle loop — first %d PCs after trap:\r\n",
                           hist_count);
                for (int k = 0; k < hist_count; k++) {
                    xil_printf("  [%4d] $%08X\r\n", k, hist[k]);
                }
                /* Also dump A6 frame chain at this moment */
                uint32_t a6 = m68k_get_reg(NULL, M68K_REG_A6);
                xil_printf("[KTRACE] A6 chain at idle entry:\r\n");
                for (int i = 0; i < 12 && a6 >= 0x04000000 && a6 < 0x12000000; i++) {
                    uint32_t ret = next_phys_read_32((a6 + 4) & 0x07FFFFFFu);
                    uint32_t nxt = next_phys_read_32(a6 & 0x07FFFFFFu);
                    xil_printf("  A6=$%08X  ret=$%08X\r\n", a6, ret);
                    if (nxt <= a6 || nxt > a6 + 0x4000) break;
                    a6 = nxt;
                }
                /* SCSI/DMA/interrupt state at idle entry — the key
                 * diagnostic: if scsi_read_log is 0, the kernel never
                 * issued a disk read during sys_open, so the block is
                 * a lock/port wait, not buffer I/O. */
                {
                    extern int scsi_read_log_count(void);
                    extern void esp_dump_state(void);
                    xil_printf("[IDLE-SCSI] SCSI reads since BUSRST: %d\r\n",
                               scsi_read_log_count());
                    esp_dump_state();
                    xil_printf("[IDLE-SCSI] DMA CSR=$%08X\r\n",
                               next_scsi_dma_csr_read());
                    xil_printf("[IDLE-SCSI] intr_status=$%08X intr_mask=$%08X pending_ipl=%d\r\n",
                               next_intr_get_status(), next_intr_get_mask(),
                               next_intr_pending_ipl());
                }
                /* Dump the LAST scheduler entry's register snapshot.
                 * This is the blocking sleep's stack — SP+0 = return
                 * addr into sleep/assert_wait, SP+4/+8 = args. */
                if (sched_snaps > 0) {
                    /* Kernel thread stacks are at $10xxxxxx, mapped only
                     * through SRP (supervisor root pointer), NOT URP.
                     * pmmu_translate_addr uses URP for user VAs, so we
                     * must use mmu040_translate_with_urp(SRP, va) to
                     * walk the kernel page table explicitly. */
                    uint32_t srp = fh_get_srp();
                    xil_printf("[BLOCK] Last sched entry (#%d) regs (SRP=$%08X):\r\n",
                               sched_snaps, srp);
                    xil_printf("[BLOCK] D0=$%08X D1=$%08X A0=$%08X A1=$%08X\r\n",
                               sched_d0, sched_d1, sched_a0, sched_a1);
                    xil_printf("[BLOCK] SP=$%08X A6=$%08X\r\n", sched_sp, sched_a6);
                    /* Helper: translate VA through SRP, fall back to
                     * identity mapping for low kernel VAs ($04xxxxxx). */
                    #define KXLAT(va) ({ \
                        uint32_t _v = (va); \
                        uint32_t _p = mmu040_translate_with_urp(srp, _v); \
                        (_p == _v && _v >= 0x10000000u) ? 0 : _p; \
                    })
                    xil_printf("[BLOCK] Stack at last sched entry (SRP-xlated):\r\n");
                    for (int i = 0; i < 48; i++) {
                        uint32_t va = sched_sp + i*4;
                        uint32_t pa = KXLAT(va);
                        if (pa != 0) {
                            uint32_t val = next_phys_read_32(pa);
                            xil_printf("  SP+%02X: $%08X  (VA=$%08X PA=$%08X)\r\n",
                                       i*4, val, va, pa);
                        } else {
                            xil_printf("  SP+%02X: ????????  (VA=$%08X no-xlat)\r\n",
                                       i*4, va);
                            break;
                        }
                    }
                    /* A6 chain from the blocking frame */
                    xil_printf("[BLOCK] A6 chain:\r\n");
                    uint32_t fa6 = sched_a6;
                    for (int i = 0; i < 16; i++) {
                        uint32_t pa = KXLAT(fa6);
                        if (pa == 0) {
                            xil_printf("  A6=$%08X  (no translation)\r\n", fa6);
                            break;
                        }
                        uint32_t ret_pa = KXLAT(fa6 + 4);
                        uint32_t ret = ret_pa ? next_phys_read_32(ret_pa) : 0;
                        uint32_t nxt = next_phys_read_32(pa);
                        xil_printf("  A6=$%08X  ret=$%08X\r\n", fa6, ret);
                        if (nxt == 0 || nxt == fa6) break;
                        fa6 = nxt;
                    }
                    #undef KXLAT
                    /* Dump 64 bytes at the sleep channel (A0 from last
                     * sched snapshot) to identify the data structure. */
                    if (sched_a0 >= 0x04000000u && sched_a0 < 0x0C000000u) {
                        xil_printf("[BLOCK] Sleep channel $%08X dump:\r\n", sched_a0);
                        for (int row = 0; row < 4; row++) {
                            uint32_t base = sched_a0 + row*16;
                            xil_printf("  $%08X: ", base);
                            for (int col = 0; col < 16; col += 4)
                                xil_printf("%08X ", next_phys_read_32(base + col));
                            xil_printf("| ");
                            for (int col = 0; col < 16; col++) {
                                uint8_t b = (next_phys_read_32((base+col) & ~3u) >>
                                            ((3 - (col & 3)) * 8)) & 0xFF;
                                xil_printf("%c", (b >= 0x20 && b < 0x7F) ? b : '.');
                            }
                            xil_printf("\r\n");
                        }
                    }
                    /* Dump code at the key return addresses from the
                     * blocking stack — these identify the functions in
                     * the sleep call chain. */
                    {
                    /* Scan the stack for return-address-looking values
                     * ($04xxxxxx in kernel text range) and dump code
                     * around each unique one. */
                    xil_printf("[BLOCK] Code at stack return addresses:\r\n");
                    uint32_t seen_ret[16]; int n_ret = 0;
                    for (int i = 0; i < 48 && n_ret < 16; i++) {
                        uint32_t va = sched_sp + i*4;
                        uint32_t pa = mmu040_translate_with_urp(srp, va);
                        if (pa == 0 || (pa == va && va >= 0x10000000u)) continue;
                        uint32_t val = next_phys_read_32(pa);
                        /* Is this a kernel text address? */
                        if (val >= 0x04001000u && val < 0x040B0000u) {
                            int dup = 0;
                            for (int j = 0; j < n_ret; j++)
                                if (seen_ret[j] == val) { dup = 1; break; }
                            if (!dup) {
                                seen_ret[n_ret++] = val;
                                /* Dump 32 bytes around the return address */
                                uint32_t a = val - 16;
                                xil_printf("  SP+%02X ret=$%08X:\r\n    ", i*4, val);
                                for (int w = 0; w < 8; w++)
                                    xil_printf("%08X ", next_phys_read_32(a + w*4));
                                xil_printf("\r\n");
                            }
                        }
                    }
                    /* Read sleep()'s arguments from its LINK frame.
                     * sleep's saved A6 is at SP+6C on the blocked stack.
                     * sleep(chan, pri): A6+8=chan, A6+12=pri on 68K. */
                    {
                        uint32_t sleep_a6_va = 0;
                        /* Find SP+6C value (sleep's frame pointer) */
                        uint32_t va6c = sched_sp + 0x6C;
                        uint32_t pa6c = mmu040_translate_with_urp(srp, va6c);
                        if (pa6c && pa6c != va6c)
                            sleep_a6_va = next_phys_read_32(pa6c);
                        if (sleep_a6_va >= 0x10000000u) {
                            /* Read chan at A6+8, pri at A6+12, caller_ret at A6+4 */
                            uint32_t pa_ret = mmu040_translate_with_urp(srp, sleep_a6_va + 4);
                            uint32_t pa_chan = mmu040_translate_with_urp(srp, sleep_a6_va + 8);
                            uint32_t pa_pri = mmu040_translate_with_urp(srp, sleep_a6_va + 12);
                            uint32_t caller = pa_ret ? next_phys_read_32(pa_ret) : 0;
                            uint32_t chan = pa_chan ? next_phys_read_32(pa_chan) : 0;
                            uint32_t pri = pa_pri ? next_phys_read_32(pa_pri) : 0;
                            xil_printf("[BLOCK] sleep() frame at A6=$%08X:\r\n", sleep_a6_va);
                            xil_printf("[BLOCK]   caller ret=$%08X  chan=$%08X  pri=%d\r\n",
                                       caller, chan, pri);
                            /* If chan looks like a kernel address, dump 32 bytes there */
                            if (chan >= 0x04000000u && chan < 0x0C000000u) {
                                xil_printf("[BLOCK]   sleep channel @$%08X: ", chan);
                                for (int w = 0; w < 8; w++)
                                    xil_printf("%08X ", next_phys_read_32(chan + w*4));
                                xil_printf("\r\n");
                            }
                            /* Dump code at the caller to identify the function */
                            if (caller >= 0x04001000u && caller < 0x040B0000u) {
                                xil_printf("[BLOCK]   caller code @$%08X-16:\r\n    ", caller);
                                for (int w = 0; w < 8; w++)
                                    xil_printf("%08X ", next_phys_read_32(caller - 16 + w*4));
                                xil_printf("\r\n");
                            }
                        }
                    }
                    }
                }
                /* Dump machine code at the LAST 20 unique PCs before
                 * idle — these are the blocking call site.  With 68K
                 * disassembly this identifies sleep/assert_wait/thread_block. */
                if (hist_count >= 20) {
                    xil_printf("[KTRACE] code at last 20 PCs before idle:\r\n");
                    for (int k = hist_count - 20; k < hist_count; k++) {
                        uint32_t a = hist[k] & 0x07FFFFFFu;
                        xil_printf("  $%08X: ", hist[k]);
                        for (int w = 0; w < 5; w++) {
                            uint32_t d = next_phys_read_32(a + w*4);
                            xil_printf("%08X ", d);
                        }
                        xil_printf("\r\n");
                    }
                }
            }
        }
    }

    /* REMOVED: cthread hack at $00004EDE — caused ILLG-USER at $00004EE0
     * because $008C (FPU displacement word) was executed as opcode.
     * The real problem is all threads blocked in msg_recv with no
     * wakeup source — need to investigate what's missing. */

    /* Kernel phase detection — used elsewhere to gate instrumentation
     * that should only run after the kernel has taken over in RAM. */
    {
        static int kernel_phase = 0;
        if (kernel_phase == 0 && pc == 0x040013A6)
            kernel_phase = 1;
        (void)kernel_phase;
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
                    /* Flush exactly the text area — matches the tighter
                     * range used in render_core1.c for the core-1 path. */
                    Xil_DCacheFlushRange(
                        (UINTPTR)pixel_buf + (TEXT_OFS_Y * SCREEN_W * 4),
                        TEXT_PX_H * SCREEN_W * 4);
                    if (dp_ok) dp_video_refresh();
                }
#endif
            }
        }

        /* Idle heartbeat — once idle_thread is detected after the
         * open("/dev/console") stall, periodically report whether any
         * new SCSI activity has occurred.  This is the key diagnostic:
         * if SCSI reads tick up, the kernel IS doing disk I/O (and it's
         * either completing or hanging mid-transfer).  If the count is
         * flat, the block is a lock/port wait with no disk involvement. */
#if 0  /* [IDLE-HB] heartbeat — disabled now that boot reaches userspace.
        * Was useful while diagnosing the open("/dev/console") hang;
        * re-enable with #if 1 if a new idle-state stall needs tracking. */
        {
            static int heartbeat_counter = 0;
            static int last_scsi_reads = -1;
            extern int emu_idle_entered;
            if (emu_idle_entered) {
                if (last_scsi_reads < 0) {
                    /* First tick after idle — snapshot baseline */
                    extern int scsi_read_log_count(void);
                    last_scsi_reads = scsi_read_log_count();
                }
                if (++heartbeat_counter >= 2500) {  /* ~every 5 seconds */
                    heartbeat_counter = 0;
                    extern int scsi_read_log_count(void);
                    int cur = scsi_read_log_count();
                    uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
                    xil_printf("[IDLE-HB] PC=$%08X scsi_reads=%d (delta=%d) intr=$%08X mask=$%08X ipl=%d\r\n",
                               pc, cur, cur - last_scsi_reads,
                               next_intr_get_status(), next_intr_get_mask(),
                               next_intr_pending_ipl());
                    last_scsi_reads = cur;
                }
            }
        }
#endif

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
            {
                extern uint32_t timer_fires_total, timer_acks_total;
                xil_printf("[DUMP] timer fires=%u acks=%u pending=%u\r\n",
                           timer_fires_total, timer_acks_total,
                           timer_fires_total - timer_acks_total);
            }
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
