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
#include "gfx_fb.h"
#include "dp_video.h"
#include "rom_image.h"
#include "usb_hid.h"
#include "acia_emu.h"
#include "atari_video.h"
#include "psg_emu.h"
#include "floppy_emu.h"
#include "sd_floppy.h"

#ifdef TEST_MODE
#include "fpu_periph.h"
#include "tests/periph_smoke.h"
#include "tests/basic_fpu.h"
#include "tests/cir_dialog.h"
#endif

/* ROM memory map constants */
#define BIOS_ROMBAS  0xE00000       /* EmuTOS 256K ROM origin */

/* Number of M68K instructions to execute per main-loop iteration */
#define EMU_CYCLES_PER_TICK  10000

/* Static buffer for .ST floppy image (max ~880 KB) */
static uint8_t floppy_image[ST_IMAGE_MAX_SIZE];

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
/* Musashi interrupt acknowledge callback                              */
/* ------------------------------------------------------------------ */

int emu_int_ack_callback(int int_level)
{
    if (int_level == 6 && acia_mode_active()) {
        int vec = atari_mfp_acknowledge();
        if (vec >= 0)
            return vec;
    }
    return M68K_INT_ACK_AUTOVECTOR;
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
               ROM_IMAGE_SIZE, BIOS_ROMBAS);
    status = emu_mem_load(BIOS_ROMBAS, rom_image_data, ROM_IMAGE_SIZE);
    if (status != 0) {
        xil_printf("[ROM] ERROR: ROM load failed\r\n");
        return;
    }

    /* Set up M68K reset vectors from the TOS ROM header.
     * TOS header layout: BRA.S(2) + version(2) + reseth(4) + ...
     * Offset 4 = reseth: the reset handler entry point.
     * The first longword is a BRA.S instruction (not a valid SSP),
     * so we use a fixed initial SSP.  EmuTOS sets its own SSP
     * immediately in startup.S before using the stack. */
    {
        uint32_t rom_pc  = ((uint32_t)rom_image_data[4] << 24) |
                           ((uint32_t)rom_image_data[5] << 16) |
                           ((uint32_t)rom_image_data[6] <<  8) |
                            (uint32_t)rom_image_data[7];
        uint32_t init_ssp = 0x800;  /* matches EmuTOS STKBOT */
        emu_mem_set_vectors(init_ssp, rom_pc);
        xil_printf("[ROM] TOS header: version=%d.%02d, reseth=$%06X\r\n",
                   rom_image_data[2], rom_image_data[3], rom_pc);
    }

    /* Initialise MFP emulation */
    mfp_init();

    /* Initialise F-line handler (hardware FPU via AXI-Lite).
     * Skip under QEMU — PL fabric not present. */
#ifndef QEMU_MODE
    if (fline_init() != 0) {
        xil_printf("[ROM] WARNING: F-line handler init failed\r\n");
    }
#else
    xil_printf("[ROM] QEMU mode — F-line handler skipped (no PL)\r\n");
#endif

    /* Initialise text framebuffer */
    pixel_buf = text_fb_init();
    xil_printf("[ROM] Text framebuffer initialised (%dx%d chars)\r\n",
               TEXT_COLS, TEXT_ROWS);

    /* Initialise graphics framebuffer (shares pixel buffer with text) */
    gfx_init(pixel_buf);

    /* Initialise Atari ST video shifter emulation */
    atari_vid_init(pixel_buf);

    /* Initial render — black screen with no text */
    text_fb_render();
    Xil_DCacheFlushRange((UINTPTR)pixel_buf, PIXEL_BUF_SIZE);

    /* Initialise DisplayPort output (skip under QEMU — DP hardware not present).
     * Returns: 0 = success, 1 = no monitor, <0 = error */
#ifndef QEMU_MODE
    status = dp_video_init(pixel_buf);
    if (status < 0) {
        xil_printf("[ROM] WARNING: DP init failed (%d), "
                   "continuing with UART-only output\r\n", status);
    } else if (status == 0) {
        dp_ok = 1;
    } else {
        xil_printf("[ROM] No DP monitor — UART-only output\r\n");
    }
#else
    xil_printf("[ROM] QEMU mode — DP init skipped\r\n");
#endif

    /* Initialise Musashi 68000 core */
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_init();
    m68k_pulse_reset();

    /* Initialise ACIA + Atari MFP for IKBD emulation */
    acia_init();
    atari_mfp_init();

    /* Initialise PSG (drive/side select) and floppy emulation */
    psg_init();
    {
        uint32_t floppy_size = sd_floppy_load("DISK_A.ST", floppy_image,
                                               sizeof(floppy_image));
        floppy_init(floppy_image, floppy_size);
    }

    /* Initialise USB HID keyboard (non-fatal if no device present) */
    if (usb_hid_init() == 0) {
        xil_printf("[ROM] USB keyboard ready\r\n");
        usb_hid_set_ikbd_mode(1);
    } else {
        xil_printf("[ROM] No USB keyboard (UART-only input)\r\n");
    }

    xil_printf("[ROM] M68000 reset — ROM at $%06X\r\n", BIOS_ROMBAS);
    xil_printf("[ROM] Entering emulation loop...\r\n");

    /* Main emulation loop */
    while (1) {
        /* Execute a batch of M68K instructions */
        m68k_execute(EMU_CYCLES_PER_TICK);

        /* Timer C + ACIA interrupt logic.
         * Both share IPL 6 through the Atari MFP interrupt controller.
         * Musashi checks pending interrupts at the start of m68k_execute(). */
        {
            int irq = 0;
            if (mfp_timer_tick(EMU_CYCLES_PER_TICK)) {
                if (acia_mode_active())
                    atari_mfp_set_timer_c_pending();
                irq = 6;
            }
            if (acia_has_irq()) {
                atari_mfp_update_acia_irq();
                irq = 6;
            }
            m68k_set_irq(irq);
        }

        /* Refresh display based on active mode.
         * Atari video takes priority when its resolution register has been written. */
        if (atari_vid_active()) {
            static int vid_skip = 0;
            if (++vid_skip >= 8) {
                vid_skip = 0;
                atari_vid_render();
                Xil_DCacheFlushRange((UINTPTR)pixel_buf, PIXEL_BUF_SIZE);
                if (dp_ok)
                    dp_video_refresh();
            }
        } else if (gfx_get_mode()) {
            /* Graphics mode: flush pixel buffer directly */
            if (gfx_is_dirty()) {
                Xil_DCacheFlushRange((UINTPTR)pixel_buf, PIXEL_BUF_SIZE);
                if (dp_ok)
                    dp_video_refresh();
                gfx_mark_clean();
            }
        } else {
            /* Text mode: re-render text to pixel buffer if changed */
            if (text_fb_is_dirty()) {
                text_fb_render();
                Xil_DCacheFlushRange((UINTPTR)pixel_buf, PIXEL_BUF_SIZE);
                if (dp_ok)
                    dp_video_refresh();
                text_fb_mark_clean();
            }
        }

        /* Feed ARM UART RX into MFP RX buffer for keyboard input */
        poll_uart_rx();

        /* Poll USB HID keyboard for keypresses */
        usb_hid_poll();
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
