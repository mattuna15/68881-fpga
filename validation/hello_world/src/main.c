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
#include "merlin2_rom.h"
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
#define EMUTOS_ROMBAS   0xE00000    /* EmuTOS 256K ROM origin */
#define MERLIN2_ROMBAS_ADDR  0xFE0000    /* Merlin2 BIOS origin */

/* Boot ROM selection */
#define BOOT_EMUTOS  0
#define BOOT_MERLIN2 1

/* Number of M68K instructions to execute per main-loop iteration */
#define EMU_CYCLES_PER_TICK  10000

/* Static buffer for .ST floppy image (max ~880 KB) */
static uint8_t floppy_image[ST_IMAGE_MAX_SIZE];

/* Forward declarations */
static int  boot_menu(void);
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
/* Boot menu: UART selection of ROM image                              */
/* ------------------------------------------------------------------ */

static int boot_menu(void)
{
    xil_printf("\r\n");
    xil_printf("  Select boot ROM:\r\n");
    xil_printf("    1 - EmuTOS (Atari ST desktop)\r\n");
    xil_printf("    2 - Merlin2 BIOS (monitor/assembler)\r\n");
    xil_printf("\r\n");
    xil_printf("  Choice [1]: ");

    /* Wait for a keypress with 10-second auto-boot timeout */
    int timeout = 10000;  /* ms */
#ifdef XPAR_XUARTPS_0_BASEADDR
    volatile u32 *uart_sr = (volatile u32 *)(XPAR_XUARTPS_0_BASEADDR + 0x2C);
    extern u8 XUartPs_RecvByte(u32 BaseAddress);
    while (timeout > 0) {
        if (!((*uart_sr) & 0x02)) {
            u8 ch = XUartPs_RecvByte(XPAR_XUARTPS_0_BASEADDR);
            if (ch == '2') {
                xil_printf("2\r\n");
                return BOOT_MERLIN2;
            }
            /* Any other key (including '1' and Enter) → EmuTOS */
            xil_printf("%c\r\n", ch >= 0x20 ? ch : '1');
            return BOOT_EMUTOS;
        }
        /* Simple busy-wait ~1ms (ARM at ~1 GHz, inner loop ~10 cycles) */
        for (volatile int d = 0; d < 100000; d++) {}
        timeout--;
    }
#endif
    xil_printf("1 (auto)\r\n");
    return BOOT_EMUTOS;
}

/* ------------------------------------------------------------------ */
/* ROM boot: load BIOS, init peripherals, run emulation loop          */
/* ------------------------------------------------------------------ */

static void rom_boot(void)
{
    uint32_t *pixel_buf;
    int status;
    int dp_ok = 0;

    /* Show boot menu and select ROM */
    int boot_choice = boot_menu();

    /* Initialise emulated memory (16 MB flat, zeroed) */
    emu_mem_init();

    if (boot_choice == BOOT_MERLIN2) {
        /* Merlin2 BIOS: load at $FE0000, entry point is load address */
        xil_printf("[ROM] Loading Merlin2 BIOS (%u bytes) at 0x%06X\r\n",
                   MERLIN2_ROM_SIZE, MERLIN2_ROMBAS_ADDR);
        status = emu_mem_load(MERLIN2_ROMBAS_ADDR, merlin2_rom_data,
                              MERLIN2_ROM_SIZE);
        if (status != 0) {
            xil_printf("[ROM] ERROR: Merlin2 load failed\r\n");
            return;
        }
        emu_mem_set_vectors(0x800, MERLIN2_ROMBAS_ADDR);
        xil_printf("[ROM] Merlin2 entry=$%06X\r\n", MERLIN2_ROMBAS_ADDR);
    } else {
        /* EmuTOS: load at $E00000, entry from TOS header */
        /* Pre-populate Atari ST hardware registers in emu_ram so EmuTOS
         * memory detection and machine_detect() find sensible values.
         * $FF8001: memory config — 0x0A = 4MB bank0 + 4MB bank1 (STe style) */
        emu_ram[0xFF8001] = 0x0A;

        xil_printf("[ROM] Loading EmuTOS (%u bytes) at 0x%06X\r\n",
                   ROM_IMAGE_SIZE, EMUTOS_ROMBAS);
        status = emu_mem_load(EMUTOS_ROMBAS, rom_image_data, ROM_IMAGE_SIZE);
        if (status != 0) {
            xil_printf("[ROM] ERROR: EmuTOS load failed\r\n");
            return;
        }

        /* Set up M68K reset vectors from the TOS ROM header.
         * TOS header layout: BRA.S(2) + version(2) + reseth(4) + ...
         * Offset 4 = reseth: the reset handler entry point. */
        {
            uint32_t rom_pc = ((uint32_t)rom_image_data[4] << 24) |
                              ((uint32_t)rom_image_data[5] << 16) |
                              ((uint32_t)rom_image_data[6] <<  8) |
                               (uint32_t)rom_image_data[7];
            uint32_t init_ssp = 0x800;  /* matches EmuTOS STKBOT */
            emu_mem_set_vectors(init_ssp, rom_pc);
            xil_printf("[ROM] TOS header: version=%d.%02d, reseth=$%06X\r\n",
                       rom_image_data[2], rom_image_data[3], rom_pc);
        }
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

    /* Initialise Blitter */
    blitter_init();

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
        /* IKBD mode only for EmuTOS (Atari scancodes + mouse packets) */
        if (boot_choice == BOOT_EMUTOS)
            usb_hid_set_ikbd_mode(1);
    } else {
        xil_printf("[ROM] No USB keyboard (UART-only input)\r\n");
    }

    xil_printf("[ROM] M68000 reset — %s\r\n",
               boot_choice == BOOT_MERLIN2 ? "Merlin2 BIOS" : "EmuTOS");
    /* Enable CIR debug logging for EmuTOS to trace FPU detection/access */
    if (boot_choice == BOOT_EMUTOS)
        emu_cir_debug_enable(1);
    xil_printf("[ROM] Entering emulation loop...\r\n");

    /* Main emulation loop */
    while (1) {
        /* Execute a batch of M68K instructions */
        m68k_execute(EMU_CYCLES_PER_TICK);

        /* PC sampler: print PC every ~2 seconds to trace EmuTOS progress.
         * Disabled for Merlin2 to keep serial output clean for cirtest etc. */
        if (boot_choice == BOOT_EMUTOS) {
            static int sample_count = 0;
            if (++sample_count >= 2000) {
                sample_count = 0;
                uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
                uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
                uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
                xil_printf("[PC] $%06X SR=$%04X SP=$%06X\r\n", pc, sr, sp);

                /* Auto-dump: when PC stays at same address for 5 consecutive samples */
                {
                    static uint32_t prev_pc = 0;
                    static int stuck = 0;
                    static int dumped_pc = 0;
                    if (pc == prev_pc && pc != 0xE13AD4) { /* ignore idle STOP */
                        if (++stuck == 5 && pc != dumped_pc) {
                            dumped_pc = pc;
                            xil_printf("[STUCK] PC=$%06X — dumping instructions:\r\n", pc);
                            for (int i = -10; i < 30; i += 2) {
                                uint16_t w = (m68k_read_memory_8(pc+i) << 8) |
                                              m68k_read_memory_8(pc+i+1);
                                xil_printf("  $%06X: $%04X%s\r\n", pc+i, w,
                                           (i == 0) ? " <<< PC" : "");
                            }
                        }
                    } else {
                        stuck = 0;
                    }
                    prev_pc = pc;
                }
            }
        }

        /* Interrupt logic: VBL (level 4) + MFP Timer C / ACIA (level 6).
         * Only for EmuTOS — Merlin2 uses its own MFP handler and doesn't
         * expect Atari ST-style VBL/ACIA interrupts. */
        if (boot_choice == BOOT_EMUTOS) {
            /* VBL interrupt (level 4, autovector).
             * Real Atari ST: ~70 Hz (NTSC) / ~50 Hz (PAL).
             * At 10000 cycles/tick and 8 MHz 68000, ~12 ticks ≈ 60 Hz.
             *
             * VBL stays pending until delivered — on a real ST, VBL and MFP
             * are independent lines. Musashi only takes one level at a time,
             * so we must keep VBL pending across ticks until the CPU can
             * service it (when MFP isn't also pending). */
            static int vbl_counter = 0;
            static int vbl_pending = 0;
            if (++vbl_counter >= 12) {
                vbl_counter = 0;
                vbl_pending = 1;
            }

            if (mfp_timer_tick(EMU_CYCLES_PER_TICK)) {
                if (acia_mode_active())
                    atari_mfp_set_timer_c_pending();
            }
            if (acia_has_irq()) {
                atari_mfp_update_acia_irq();
            }

            /* Deliver VBL and MFP interrupts. */
            if (atari_mfp_has_pending_irq()) {
                m68k_set_irq(6);
            } else if (vbl_pending) {
                m68k_set_irq(4);
                vbl_pending = 0;
            } else {
                m68k_set_irq(0);
            }
        }

        /* One-shot: patch cookie jar to report MC68882 FPU.
         * EmuTOS's 68000 build has no FPU detection code, but our F-line
         * handler makes the hardware MC68882 fully functional.  Insert
         * _FPU=4 (68882) into the cookie jar after EmuTOS has initialised. */
        {
            static int cookies_patched = 0;
            if (!cookies_patched && boot_choice == BOOT_EMUTOS && atari_vid_active()) {
                cookies_patched = 1;
                uint32_t jar_ptr = m68k_read_memory_32(0x5A0);
                if (jar_ptr != 0 && jar_ptr < EMU_RAM_SIZE - 64) {
                    uint32_t p = jar_ptr;
                    uint32_t max_cookies = 0;
                    int count = 0;
                    while (count < 32) {
                        uint32_t id = m68k_read_memory_32(p);
                        if (id == 0) {
                            max_cookies = m68k_read_memory_32(p + 4);
                            break;
                        }
                        p += 8;
                        count++;
                    }
                    if (max_cookies > 0 && count + 1 < (int)max_cookies) {
                        m68k_write_memory_32(p,      0x5F465055); /* '_FPU' */
                        m68k_write_memory_32(p + 4,   4);         /* 68882 */
                        m68k_write_memory_32(p + 8,   0);         /* terminator */
                        m68k_write_memory_32(p + 12, max_cookies);
                        xil_printf("[ROM] Cookie jar: _FPU=4 (MC68882)\r\n");
                    }
                }
            }
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
