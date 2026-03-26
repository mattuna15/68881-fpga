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
#include "fline_handler.h"
#include "text_fb.h"
#include "dp_video.h"

/* Number of M68K instructions to execute per main-loop tick */
#define EMU_CYCLES_PER_TICK  10000

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
    init_platform();

    xil_printf("\r\n");
    xil_printf("================================================\r\n");
    xil_printf("  NeXT 68040LC System + MC68882 FPU\r\n");
    xil_printf("  Mach kernel boot emulator\r\n");
    xil_printf("================================================\r\n");

    next_boot();

    cleanup_platform();
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
    xil_printf("[NEXT] Device stubs: SCR1=%08X (WARP9/040)\r\n",
               SCR1_VALUE(NeXT_WARP9, 0));

    /* Build ROM monitor stub (mon_global) in RAM */
    uint32_t mg_addr = next_mon_build(MON_GLOBAL_ADDR,
                                       NEXT_RAM_BASE, NEXT_RAM_SIZE,
                                       NeXT_WARP9);
    xil_printf("[NEXT] mon_global stub @ 0x%08X\r\n", mg_addr);

    /* TODO: Load kernel image into RAM at 0x04000000.
     *
     * For now, we set up a minimal test: the kernel entry point would
     * normally come from the kernel binary. Until we have one, write
     * a tiny test program that reads SCR1 and prints to SCC.
     *
     * To load a real kernel:
     *   #include "next_kernel.h"
     *   next_mem_load(NEXT_RAM_BASE, next_kernel_data, NEXT_KERNEL_SIZE);
     *
     * Then set vectors to the kernel's entry point. */

    /* Minimal test program at 0x04001000:
     *   move.l  0x0200C000, d0    ; read SCR1
     *   move.b  #'N', 0x02018003  ; write 'N' to SCC channel A data
     *   move.b  #'X', 0x02018003  ; write 'X'
     *   move.b  #'T', 0x02018003  ; write 'T'
     *   move.b  #'\r', 0x02018003
     *   move.b  #'\n', 0x02018003
     *   stop    #$2700            ; halt
     */
    {
        static const uint8_t test_prog[] = {
            /* move.l $0200C000, d0 */
            0x20, 0x39, 0x02, 0x00, 0xC0, 0x00,
            /* move.b #'N', $02018003 */
            0x13, 0xFC, 0x00, 0x4E, 0x02, 0x01, 0x80, 0x03,
            /* move.b #'X', $02018003 */
            0x13, 0xFC, 0x00, 0x58, 0x02, 0x01, 0x80, 0x03,
            /* move.b #'T', $02018003 */
            0x13, 0xFC, 0x00, 0x54, 0x02, 0x01, 0x80, 0x03,
            /* move.b #'\r', $02018003 */
            0x13, 0xFC, 0x00, 0x0D, 0x02, 0x01, 0x80, 0x03,
            /* move.b #'\n', $02018003 */
            0x13, 0xFC, 0x00, 0x0A, 0x02, 0x01, 0x80, 0x03,
            /* stop #$2700 */
            0x4E, 0x72, 0x27, 0x00,
        };
        next_mem_load(NEXT_RAM_BASE + 0x1000, test_prog, sizeof(test_prog));
    }

    /* Set exception vectors: SSP = top of 64KB scratch area, PC = test program */
    next_mem_set_vectors(NEXT_RAM_BASE + 0x10000,  /* SSP */
                         NEXT_RAM_BASE + 0x1000);  /* PC -> test program */

    /* Verify vectors were written correctly */
    xil_printf("[NEXT] Vec0(SSP)=%08X Vec1(PC)=%08X Vec2(BusErr)=%08X\r\n",
               m68k_read_memory_32(0x00000000),
               m68k_read_memory_32(0x00000004),
               m68k_read_memory_32(0x00000008));

    /* Initialise F-line handler (hardware FPU via AXI-Lite) */
#ifndef QEMU_MODE
    if (fline_init() != 0)
        xil_printf("[NEXT] WARNING: F-line handler init failed\r\n");
#endif

    /* Initialise text framebuffer for serial mirror / debug display */
    pixel_buf = text_fb_init();

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

        /* Advance timer and check for interrupts */
        next_timer_tick(EMU_CYCLES_PER_TICK);

        int ipl = next_intr_pending_ipl();
        m68k_set_irq(ipl);

        /* PC trace (debug: print every ~2 seconds) */
        {
            static int sample_count = 0;
            if (++sample_count >= 2000) {
                sample_count = 0;
                uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
                uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
                uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
                xil_printf("[PC] $%08X SR=$%04X SP=$%08X\r\n", pc, sr, sp);

                /* Detect stuck PC */
                static uint32_t prev_pc = 0;
                static int stuck = 0;
                if (pc == prev_pc) {
                    if (++stuck >= 3) {
                        xil_printf("[HALT] PC stuck at $%08X — stopping\r\n", pc);
                        return;
                    }
                } else {
                    stuck = 0;
                }
                prev_pc = pc;
            }
        }

        /* Refresh text display */
        if (text_fb_is_dirty()) {
            text_fb_render();
            Xil_DCacheFlushRange((UINTPTR)pixel_buf, 1280*720*4);
            if (dp_ok)
                dp_video_refresh();
            text_fb_mark_clean();
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
    extern u8 XUartPs_RecvByte(u32 BaseAddress);
    volatile u32 *uart_sr = (volatile u32 *)(XPAR_XUARTPS_0_BASEADDR + 0x2C);
    while (!((*uart_sr) & 0x02)) {
        u8 ch = XUartPs_RecvByte(XPAR_XUARTPS_0_BASEADDR);
        next_scc_rx_push(ch);
    }
#endif
}
