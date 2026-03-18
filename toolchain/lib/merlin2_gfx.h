#ifndef MERLIN2_GFX_H
#define MERLIN2_GFX_H

#include <stdint.h>

/* Framebuffer constants */
#define GFX_FB_BASE     0x800000
#define GFX_SCREEN_W    1280
#define GFX_SCREEN_H    720

/* TRAP #15 wrappers */
void gfx_set_mode(int mode);
void gfx_clear(uint32_t colour);
void gfx_set_pixel(int x, int y, uint32_t argb);
void gfx_screen_info(int *w, int *h);
uint32_t gfx_get_time(void);
int gfx_char_ready(void);

/* Direct framebuffer access */
static inline volatile uint32_t *gfx_fb_ptr(int x, int y)
{
    return (volatile uint32_t *)(GFX_FB_BASE + (y * GFX_SCREEN_W + x) * 4);
}

#endif /* MERLIN2_GFX_H */
