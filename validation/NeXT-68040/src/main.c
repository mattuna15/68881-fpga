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
#include "next_rom_image.h"
#include "fline_handler.h"
#include "next_rtc.h"
#include "next_dsp.h"
#include "next_kms.h"
#include "next_video.h"
#include "text_fb.h"
#include "dp_video.h"

/* Number of M68K instructions to execute per main-loop tick */
#define EMU_CYCLES_PER_TICK  10000

/* ------------------------------------------------------------------ */
/* Early instruction trace (first N instructions for boot debugging)   */
/* ------------------------------------------------------------------ */
#define TRACE_LIMIT  0  /* Disabled */
static int trace_count = 0;

/* Intercept ROM's mg_putc to mirror bitmap console output to serial.
 * Address is ROM-version-specific; set to 0 to auto-detect from mon_global.
 * Rev 3.3 v74 (Turbo): $010081C8
 * Rev 2.5 v66 (68040):  discovered at runtime from mg_putc field */
static uint32_t rom_putc_addr = 0;  /* 0 = not yet discovered */

void emu_instr_hook(unsigned int pc)
{
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
    xil_printf("[NEXT] Device stubs: SCR1=%08X (WARP9/040)\r\n",
               SCR1_VALUE(NeXT_WARP9, 0));

    /* Build ROM monitor stub (mon_global) in RAM */
    uint32_t mg_addr = next_mon_build(MON_GLOBAL_ADDR,
                                       NEXT_RAM_BASE, NEXT_RAM_SIZE,
                                       NeXT_WARP9);
    xil_printf("[NEXT] mon_global stub @ 0x%08X\r\n", mg_addr);

    /* Load NeXT 68040 Turbo ROM (Rev 3.3 v74, 128 KB).
     * ROM is mapped at both 0x00000000 and 0x01000000 (BMAP).
     * The ROM's vectors: SSP=0x04000400, PC=0x0100001E */
    next_rom_load(next_rom_data, next_rom_data_len);
    xil_printf("[NEXT] ROM loaded: %u bytes\r\n",
               next_rom_data_len);

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
     * DISABLED: The Turbo ROM's POST does FSAVE and expects 68040 FPU
     * frame formats.  The MC68882 returns 68882 frames, causing the ROM
     * to detect a wrong FPU and enter a blink error loop before RTC.
     * With fline disabled, F-line instructions trap as exceptions and
     * the ROM skips FPU testing (same as QEMU behaviour).
     * TODO: add FSAVE/FRESTORE frame translation (68882 ↔ 68040). */
#if 0 /* disabled — see comment above */
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
#endif

    /* Initialise Musashi as 68LC040 (68040 without internal FPU) */
    m68k_set_cpu_type(M68K_CPU_TYPE_68LC040);
    m68k_init();
    m68k_pulse_reset();

    xil_printf("[NEXT] 68LC040 reset — entering emulation loop\r\n");
    xil_printf("================================================\r\n");

    /* Main emulation loop */
    while (1) {
        m68k_execute(EMU_CYCLES_PER_TICK);

        /* Advance timer, RTC, and check for interrupts */
        next_timer_tick(EMU_CYCLES_PER_TICK);
        next_rtc_tick(EMU_CYCLES_PER_TICK);

        int ipl = next_intr_pending_ipl();
        m68k_set_irq(ipl);

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
                    /* Force one render + refresh */
                    next_video_render();
#ifndef QEMU_MODE
                    Xil_DCacheFlushRange((UINTPTR)pixel_buf, SCREEN_W*SCREEN_H*4);
                    if (dp_ok) dp_video_refresh();
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

        /* Refresh display: once NeXT VRAM has content, use it exclusively.
         * Before that, fall back to text_fb for boot messages. */
        {
            static int next_vram_active = 0;
            int need_refresh = 0;

            if (next_vram_is_dirty()) {
                static int vram_refresh_count = 0;
                if (!next_vram_active) {
                    xil_printf("[VIDEO] NeXT VRAM active, stride=%d bytes/line\r\n",
                               NEXT_VIDEO_NBPL);
                }
                next_vram_active = 1;
                next_vram_mark_clean();
                /* Throttle: render every 50 ticks (~250ms) */
                if (++vram_refresh_count >= 50) {
                    vram_refresh_count = 0;
                    next_video_render();
                    need_refresh = 1;
                }
            } else if (!next_vram_active && text_fb_is_dirty()) {
                text_fb_render();
                text_fb_mark_clean();
                need_refresh = 1;
            }

#ifndef QEMU_MODE
            if (need_refresh) {
                Xil_DCacheFlushRange((UINTPTR)pixel_buf, SCREEN_W*SCREEN_H*4);
                if (dp_ok)
                    dp_video_refresh();
            }
#endif
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
        next_scc_rx_push(ch);    /* SCC serial path */
        next_kms_push_ascii(ch); /* KMS keyboard path (ROM monitor) */
    }
#endif
}
