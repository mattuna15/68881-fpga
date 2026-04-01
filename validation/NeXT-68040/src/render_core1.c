/*
 * render_core1.c
 * Display rendering on Cortex-A53 core 1.
 *
 * Core 0 runs the 68K emulator. Core 1 runs this render loop which
 * continuously converts NeXT 2bpp VRAM to the ARGB8888 pixel buffer
 * and triggers DisplayPort refresh.
 *
 * Communication: core 0 sets render_request = 1 when VRAM is dirty.
 * Core 1 polls this flag and renders when set. No locking needed —
 * the render is read-only on VRAM and write-only on pixel_buf.
 */

#include "render_core1.h"
#include "next_video.h"
#include "next_memory.h"
#include "text_fb.h"
#include "dp_video.h"
#include "xil_printf.h"
#include "xil_cache.h"

/* Shared state between core 0 and core 1 */
static volatile int render_active = 0;    /* 1 = core 1 is running */
static volatile int render_request = 0;   /* 1 = VRAM dirty, please render */
static volatile int render_mode = 0;      /* 0 = text_fb, 1 = next_vram */
static uint32_t *render_pixel_buf = 0;
static int render_dp_ok = 0;

/* Core 1 stack (16KB, aligned) — referenced by core1_boot.S */
uint8_t core1_stack[16384] __attribute__((aligned(64)));

/* ZynqMP APU registers for core release */
#define RVBAR1_L        0xFD5C0048  /* Reset Vector Base Address Register core 1 low */
#define RVBAR1_H        0xFD5C004C  /* Reset Vector Base Address Register core 1 high */
#define RST_FPD_APU     0xFD1A0104  /* APU reset control */
#define RST_ACPU1       (1u << 1)   /* Core 1 reset bit */
#define RST_ACPU1_PWRON (1u << 11)  /* Core 1 power-on reset bit */

static inline void mmio_write32(uintptr_t addr, uint32_t val)
{
    *(volatile uint32_t *)addr = val;
}

static inline uint32_t mmio_read32(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}

/* ------------------------------------------------------------------ */
/* Core 1 entry + main — core1_boot.S does EL3 init then branches here */
/* ------------------------------------------------------------------ */

/* Assembly entry point in core1_boot.S */
extern void core1_entry(void);

void __attribute__((noreturn)) core1_main(void)
{
    render_active = 1;
    __asm__ volatile ("dsb sy" ::: "memory");

    while (1) {
        /* Wait for render request */
        if (!render_request) {
            __asm__ volatile ("wfe");  /* low-power wait */
            continue;
        }

        render_request = 0;
        __asm__ volatile ("dsb sy" ::: "memory");

        /* Render */
        if (render_mode) {
            next_video_render();
        } else {
            if (text_fb_is_dirty()) {
                text_fb_render();
                text_fb_mark_clean();
            }
        }

        /* Flush pixel buffer and refresh display */
#ifndef QEMU_MODE
        if (render_dp_ok && render_pixel_buf) {
            if (render_mode) {
                /* NeXT VRAM: flush display area (rows 124-956) */
                UINTPTR flush_start = (UINTPTR)render_pixel_buf + (124 * SCREEN_W * 4);
                Xil_DCacheFlushRange(flush_start, 832 * SCREEN_W * 4);
            } else {
                /* Text mode: flush from TEXT_OFS_Y (row 120) through text area */
                UINTPTR flush_start = (UINTPTR)render_pixel_buf + (TEXT_OFS_Y * SCREEN_W * 4);
                Xil_DCacheFlushRange(flush_start, (SCREEN_H - TEXT_OFS_Y) * SCREEN_W * 4);
            }
            dp_video_refresh();
        }
#endif
    }
}

/* ------------------------------------------------------------------ */
/* Core 0 API: start core 1 and request renders                        */
/* ------------------------------------------------------------------ */

void render_core1_start(uint32_t *pixel_buf, int dp_ok)
{
#ifdef QEMU_MODE
    /* QEMU doesn't support multi-core in this configuration */
    (void)pixel_buf;
    (void)dp_ok;
    return;
#else
    render_pixel_buf = pixel_buf;
    render_dp_ok = dp_ok;
    render_mode = 0;  /* start in text mode */

    uintptr_t entry = (uintptr_t)core1_entry;

    xil_printf("[CORE1] Entry point: 0x%08X\r\n", (uint32_t)entry);
    xil_printf("[CORE1] Stack: 0x%08X (16KB)\r\n", (uint32_t)(uintptr_t)core1_stack);

    /* Set core 1 reset vector to our entry point */
    mmio_write32(RVBAR1_L, (uint32_t)(entry & 0xFFFFFFFF));
    mmio_write32(RVBAR1_H, (uint32_t)(entry >> 32));

    /* Release core 1 from reset */
    uint32_t rst = mmio_read32(RST_FPD_APU);
    rst &= ~(RST_ACPU1 | RST_ACPU1_PWRON);
    mmio_write32(RST_FPD_APU, rst);

    /* Wait for core 1 to signal it's running */
    int timeout = 1000000;
    while (!render_active && --timeout > 0)
        ;

    if (render_active)
        xil_printf("[CORE1] Render core started OK\r\n");
    else
        xil_printf("[CORE1] WARNING: core 1 did not start!\r\n");
#endif
}

void render_core1_request(int mode)
{
#ifdef QEMU_MODE
    (void)mode;
    return;
#else
    render_mode = mode;
    render_request = 1;
    __asm__ volatile ("dsb sy\n sev" ::: "memory");  /* wake core 1 */
#endif
}

int render_core1_is_active(void)
{
    return render_active;
}
