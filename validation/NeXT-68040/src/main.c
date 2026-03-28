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
 * mg_putc is at $010081C8; character is at SP+7 on entry (low byte
 * of the 4-byte argument after the return address). */
#define ROM_PUTC_ADDR  0x010081C8

void emu_instr_hook(unsigned int pc)
{
    /* Mirror ROM's bitmap console output to serial.
     * The ROM's mg_putc renders to VRAM (bitmap framebuffer).
     * We intercept each call and echo the character to the ARM UART
     * so console output is visible under QEMU (no video display). */
    if (pc == ROM_PUTC_ADDR) {
        uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
        uint8_t ch = m68k_read_memory_8(sp + 7);
        if (ch >= 0x20 && ch < 0x7F)
            xil_printf("%c", ch);
        else if (ch == '\r' || ch == '\n' || ch == '\t' || ch == '\b')
            xil_printf("%c", ch);
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
    xil_printf("[NEXT] ROM loaded: %u bytes (Rev 3.3 v74 Turbo)\r\n",
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

    /* Initialise F-line handler (hardware FPU via AXI-Lite) */
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
                    mg_dumped = 1;
                }
            }
        }

        /* PC trace (debug: print every ~2 seconds) */
        {
            static int sample_count = 0;
            if (++sample_count >= 500) {
                sample_count = 0;
                uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
                uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
                uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
                xil_printf("[PC] $%08X SR=$%04X SP=$%08X\r\n", pc, sr, sp);

                /* Detect stuck PC */
                static uint32_t prev_pc = 0;
                static int stuck = 0;
                if (pc == prev_pc) {
                    if (++stuck >= 10) {
                        /* Don't halt if PC is in the ROM monitor input
                         * poll — that's normal idle behaviour. */
                        if (pc < 0x01002000 || pc > 0x01003000) {
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
                Xil_DCacheFlushRange((UINTPTR)pixel_buf, 1280*720*4);
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
        next_scc_rx_push(ch);
    }
#endif
}
