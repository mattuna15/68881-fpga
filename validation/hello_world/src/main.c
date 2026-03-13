/*
 * main.c
 * ROM-style M68000 system with DisplayPort text output.
 *
 * Boots a 68000 BIOS ROM under Musashi emulation.  Character I/O is
 * intercepted via MC68901 MFP emulation and rendered to a text
 * framebuffer displayed on the DP monitor.  The hardware MC68881 FPU
 * is still available via F-line trapping.
 *
 * Build modes (compile definitions):
 *   ROM_BOOT_MODE  — boot the BIOS ROM (default if defined)
 *   TEST_MODE      — run the original validation test suite
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "musashi/m68k.h"
#include "emu_memory.h"
#include "fline_handler.h"
#include "mfp_emu.h"
#include "text_fb.h"
#include "dp_video.h"
#include "rom_image.h"

#ifdef TEST_MODE
#include "fpu_periph.h"
#include "tests/periph_smoke.h"
#include "tests/basic_fpu.h"
#include "tests/cir_dialog.h"
#endif

/* ROM memory map constants (must match bios.s) */
#define BIOS_ROMBAS  0xFE0000
#define BIOS_STACK   0x001000

/* Number of M68K instructions to execute per main-loop iteration */
#define EMU_CYCLES_PER_TICK  10000

/* Forward declarations */
static void rom_boot(void);
static void poll_uart_rx(void);

#ifdef TEST_MODE
static int run_tests(void);
#endif

int main(void)
{
    init_platform();

    xil_printf("\r\n");
    xil_printf("================================================\r\n");
    xil_printf("  MC68000 ROM System + MC68881 FPU\r\n");
    xil_printf("  DisplayPort text output (1280x720)\r\n");
    xil_printf("================================================\r\n");

#ifdef TEST_MODE
    /* Original test suite mode */
    int failures = run_tests();
    cleanup_platform();
    return failures ? 1 : 0;
#else
    /* ROM boot mode (default) */
    rom_boot();
    /* Should not return */
    cleanup_platform();
    return 0;
#endif
}

/* ------------------------------------------------------------------ */
/* ROM boot: load BIOS, init peripherals, run emulation loop          */
/* ------------------------------------------------------------------ */

static void rom_boot(void)
{
    uint32_t *pixel_buf;
    int status;
    int dp_ok = 0;

    /* Initialise emulated memory (16 MB flat, zeroed) */
    emu_mem_init();

    /* Load ROM image at ROMBAS */
    xil_printf("[ROM] Loading ROM image (%u bytes) at 0x%06X\r\n",
               rom_image_size, BIOS_ROMBAS);
    status = emu_mem_load(BIOS_ROMBAS, rom_image_data, rom_image_size);
    if (status != 0) {
        xil_printf("[ROM] ERROR: ROM load failed\r\n");
        return;
    }

    /* Set initial SSP and PC in vector table */
    emu_mem_set_vectors(BIOS_STACK, BIOS_ROMBAS);

    /* Initialise MFP emulation */
    mfp_init();

    /* Initialise F-line handler (hardware FPU via AXI-Lite) */
    fline_init();

    /* Initialise text framebuffer */
    pixel_buf = text_fb_init();
    xil_printf("[ROM] Text framebuffer initialised (%dx%d chars)\r\n",
               TEXT_COLS, TEXT_ROWS);

    /* Initial render — black screen with no text */
    text_fb_render();
    Xil_DCacheFlushRange((UINTPTR)pixel_buf, PIXEL_BUF_SIZE);

    /* Initialise DisplayPort output.
     * Returns: 0 = success, 1 = no monitor, <0 = error */
    status = dp_video_init(pixel_buf);
    if (status < 0) {
        xil_printf("[ROM] WARNING: DP init failed (%d), "
                   "continuing with UART-only output\r\n", status);
    } else if (status == 0) {
        dp_ok = 1;
    } else {
        xil_printf("[ROM] No DP monitor — UART-only output\r\n");
    }

    /* Initialise Musashi 68000 core */
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_init();
    m68k_pulse_reset();

    xil_printf("[ROM] M68000 reset — PC=$%06X SSP=$%06X\r\n",
               BIOS_ROMBAS, BIOS_STACK);
    xil_printf("[ROM] Entering emulation loop...\r\n");

    /* Main emulation loop */
    while (1) {
        /* Execute a batch of M68K instructions */
        m68k_execute(EMU_CYCLES_PER_TICK);

        /* Re-render text to pixel buffer if anything changed */
        if (text_fb_is_dirty()) {
            text_fb_render();
            Xil_DCacheFlushRange((UINTPTR)pixel_buf, PIXEL_BUF_SIZE);
            if (dp_ok)
                dp_video_refresh();
            text_fb_mark_clean();
        }

        /* Feed ARM UART RX into MFP RX buffer for keyboard input */
        poll_uart_rx();
    }
}

/* ------------------------------------------------------------------ */
/* UART RX polling — pass ARM UART input to MFP RX buffer             */
/* ------------------------------------------------------------------ */

static void poll_uart_rx(void)
{
    /*
     * XUartPs_IsReceiveData() / XUartPs_ReadReg() could be used here,
     * but for portability we use the BSP's inbyte() if data is available.
     * The Vitis BSP provides XUartPs_IsReceiveData(STDIN_BASEADDR).
     */
#ifdef XPAR_XUARTPS_0_BASEADDR
    extern u8 XUartPs_RecvByte(u32 BaseAddress);
    volatile u32 *uart_sr = (volatile u32 *)(XPAR_XUARTPS_0_BASEADDR + 0x2C);
    /* Channel Status Register bit 1: RX FIFO empty */
    while (!((*uart_sr) & 0x02)) {
        u8 ch = XUartPs_RecvByte(XPAR_XUARTPS_0_BASEADDR);
        if (mfp_rx_push(ch) < 0)
            xil_printf("[UART] RX buffer full, character dropped\r\n");
    }
#endif
}

/* ------------------------------------------------------------------ */
/* Test mode (original validation suite)                               */
/* ------------------------------------------------------------------ */

#ifdef TEST_MODE
static int run_tests(void)
{
    int total_failures = 0;

    xil_printf("  Running validation test suite\r\n");
    xil_printf("================================================\r\n");

    /* Phase 1: Peripheral driver smoke test (no Musashi) */
    total_failures += periph_smoke_run();

    /* Phase 2: CIR dialog protocol (AN-947 coprocessor interface) */
    total_failures += cir_dialog_run();

    /* Phase 3: Musashi + F-line handler integration */
    total_failures += basic_fpu_run();

    /* Summary */
    xil_printf("\r\n================================================\r\n");
    if (total_failures == 0)
        xil_printf("ALL TESTS PASSED\r\n");
    else
        xil_printf("TOTAL FAILURES: %d\r\n", total_failures);
    xil_printf("================================================\r\n");

    return total_failures;
}
#endif
