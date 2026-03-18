#ifndef MERLIN2_GFX_H
#define MERLIN2_GFX_H

#include <stdint.h>

/* M68K-visible framebuffer: 1280x720 ARGB8888 (0xAARRGGBB), 3.6 MB */
#define GFX_FB_BASE     0x800000
#define GFX_SCREEN_W    1280
#define GFX_SCREEN_H    720

/* TRAP #15 wrappers (see merlin2.h for dispatch table) */
void gfx_set_mode(int mode);            /* D0=17: 0=text, 1=graphics */
void gfx_clear(uint32_t colour);        /* D0=18: fill FB with ARGB colour */
void gfx_set_pixel(int x, int y, uint32_t argb); /* D0=19: bounds-checked */
void gfx_screen_info(int *w, int *h);   /* D0=21: query display dimensions */
uint32_t gfx_get_time(void);            /* D0=8:  milliseconds since boot */
int gfx_char_ready(void);               /* D0=7:  1 if key pressed */

/*
 * Direct framebuffer pointer — NO bounds checking.
 * Caller MUST ensure 0 <= x < GFX_SCREEN_W and 0 <= y < GFX_SCREEN_H.
 * Out-of-bounds access will corrupt stack, I/O registers, or unmapped memory.
 */
static inline volatile uint32_t *gfx_fb_ptr(int x, int y)
{
    return (volatile uint32_t *)(GFX_FB_BASE + (y * GFX_SCREEN_W + x) * 4);
}

#endif /* MERLIN2_GFX_H */
