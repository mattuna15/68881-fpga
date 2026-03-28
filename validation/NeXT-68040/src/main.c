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
#include "text_fb.h"
#include "dp_video.h"

/* Number of M68K instructions to execute per main-loop tick */
#define EMU_CYCLES_PER_TICK  10000

/* ------------------------------------------------------------------ */
/* Early instruction trace (first N instructions for boot debugging)   */
/* ------------------------------------------------------------------ */
#define TRACE_LIMIT  0  /* Disabled */
static int trace_count = 0;

void emu_instr_hook(unsigned int pc)
{
    /* Start tracing when we reach the second DSP poll at $C4E0 */
    static int trace_armed = 0;
    static int seen_c474 = 0;
    if (pc == 0x0100C474) seen_c474++;
    if (!trace_armed && pc == 0x0100C4E0 && seen_c474 > 0) {
        trace_armed = 1;
        trace_count = 0;
    }
    if (trace_armed && trace_count < TRACE_LIMIT) {
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

        /* Advance timer, RTC, and check for interrupts */
        next_timer_tick(EMU_CYCLES_PER_TICK);
        next_rtc_tick(EMU_CYCLES_PER_TICK);

        int ipl = next_intr_pending_ipl();
        m68k_set_irq(ipl);

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
                        xil_printf("[HALT] PC stuck at $%08X - stopping\r\n", pc);
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
