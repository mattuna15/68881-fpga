/*
 * gfx_fb.c
 * Pixel-addressable graphics framebuffer for M68K emulator.
 *
 * Maps a 1280x720 ARGB8888 pixel buffer at 0x800000 in the 68k
 * address space.  Control registers at 0xFD0040 handle mode
 * switching and commands (clear, flush).
 *
 * Byte ordering: 68k stores big-endian ARGB as bytes A,R,G,B.
 * The pixel_fb[] is uint32_t on ARM.  The DPDMA/DisplayPort expects
 * ABGR uint32_t layout, so we swap R and B channels on every access.
 * The 68k programmer always works in ARGB — the swap is transparent.
 */

#include <string.h>
#include "gfx_fb.h"

/* Exposed for the inline gfx_is_fb() check in gfx_fb.h */
int gfx_mode = 0;

static uint32_t *pixel_buf;
static uint32_t  clear_color = 0xFF000000;  /* default: opaque black */
static int       dirty;

void gfx_init(uint32_t *buf)
{
    pixel_buf = buf;
    gfx_mode = 0;
    dirty = 0;
    clear_color = 0xFF000000;
}

void gfx_set_mode(int mode)
{
    gfx_mode = (mode != 0) ? 1 : 0;
}

int gfx_get_mode(void)
{
    return gfx_mode;
}

/* ------------------------------------------------------------------ */
/* ARGB <-> ABGR conversion                                            */
/* ------------------------------------------------------------------ */

/*
 * The 68k programmer works in ARGB: 0xAARRGGBB.
 * The DPDMA/DisplayPort on ZynqMP expects ABGR: 0xAABBGGRR.
 * Swap R (bits 23-16) and B (bits 7-0), keep A and G in place.
 */
static inline uint32_t swap_rb(uint32_t v)
{
    return (v & 0xFF00FF00u) |
           ((v >> 16) & 0x000000FFu) |
           ((v <<  16) & 0x00FF0000u);
}

/* ------------------------------------------------------------------ */
/* Framebuffer access helpers                                          */
/* ------------------------------------------------------------------ */

/*
 * 68k big-endian ARGB byte layout within a 32-bit pixel:
 *   byte 0 = Alpha, byte 1 = Red, byte 2 = Green, byte 3 = Blue
 *
 * In the stored ABGR pixel:
 *   bits [31:24] = A, [23:16] = B, [15:8] = G, [7:0] = R
 *
 * Byte position remapping (ARGB byte -> ABGR bit position):
 *   0 (A) -> shift 24    1 (R) -> shift 0
 *   2 (G) -> shift 8     3 (B) -> shift 16
 */
static const unsigned int byte_shift[4] = { 24, 0, 8, 16 };

unsigned int gfx_read_8(unsigned int addr)
{
    unsigned int offset = addr - GFX_FB_BASE;
    unsigned int pixel_idx = offset >> 2;
    unsigned int byte_pos  = offset & 3;
    uint32_t pixel = pixel_buf[pixel_idx];

    return (pixel >> byte_shift[byte_pos]) & 0xFF;
}

unsigned int gfx_read_16(unsigned int addr)
{
    return ((unsigned int)gfx_read_8(addr) << 8) |
            (unsigned int)gfx_read_8(addr + 1);
}

unsigned int gfx_read_32(unsigned int addr)
{
    unsigned int offset = addr - GFX_FB_BASE;

    /* Fast path: aligned 32-bit read — convert ABGR back to ARGB */
    if ((offset & 3) == 0) {
        return swap_rb(pixel_buf[offset >> 2]);
    }

    /* Unaligned: byte-by-byte (read_8 handles the remapping) */
    return ((unsigned int)gfx_read_8(addr)     << 24) |
           ((unsigned int)gfx_read_8(addr + 1) << 16) |
           ((unsigned int)gfx_read_8(addr + 2) <<  8) |
            (unsigned int)gfx_read_8(addr + 3);
}

void gfx_write_8(unsigned int addr, unsigned int value)
{
    unsigned int offset = addr - GFX_FB_BASE;
    unsigned int pixel_idx = offset >> 2;
    unsigned int byte_pos  = offset & 3;
    unsigned int shift = byte_shift[byte_pos];
    uint32_t mask = ~(0xFFU << shift);

    pixel_buf[pixel_idx] = (pixel_buf[pixel_idx] & mask) |
                           ((value & 0xFF) << shift);
    dirty = 1;
}

void gfx_write_16(unsigned int addr, unsigned int value)
{
    gfx_write_8(addr,     (value >> 8) & 0xFF);
    gfx_write_8(addr + 1,  value       & 0xFF);
}

void gfx_write_32(unsigned int addr, unsigned int value)
{
    unsigned int offset = addr - GFX_FB_BASE;

    /* Fast path: aligned 32-bit write — convert ARGB to ABGR */
    if ((offset & 3) == 0) {
        pixel_buf[offset >> 2] = swap_rb(value);
        dirty = 1;
        return;
    }

    /* Unaligned: byte-by-byte (write_8 handles the remapping) */
    gfx_write_8(addr,     (value >> 24) & 0xFF);
    gfx_write_8(addr + 1, (value >> 16) & 0xFF);
    gfx_write_8(addr + 2, (value >>  8) & 0xFF);
    gfx_write_8(addr + 3,  value        & 0xFF);
}

/* ------------------------------------------------------------------ */
/* Control register access                                             */
/* ------------------------------------------------------------------ */

unsigned int gfx_io_read(unsigned int offset)
{
    switch (offset) {
    case 0x00: return (unsigned int)gfx_mode;
    case 0x04: return clear_color;
    case 0x08: return GFX_SCREEN_W;
    case 0x0A: return GFX_SCREEN_H;
    case 0x0C: return GFX_FB_BASE;
    default:   return 0;
    }
}

void gfx_io_write(unsigned int offset, unsigned int value)
{
    switch (offset) {
    case 0x00:  /* Mode register */
        gfx_set_mode(value & 0xFF);
        break;
    case 0x01:  /* Command register */
        switch (value & 0xFF) {
        case 1:  /* Clear */
            gfx_clear(clear_color);
            break;
        case 2:  /* Flush (mark dirty for display refresh) */
            dirty = 1;
            break;
        }
        break;
    case 0x04:  /* Clear/fill colour */
        clear_color = value;
        break;
    default:
        break;
    }
}

/* ------------------------------------------------------------------ */
/* Utility                                                             */
/* ------------------------------------------------------------------ */

int gfx_is_dirty(void)
{
    return dirty;
}

void gfx_mark_clean(void)
{
    dirty = 0;
}

void gfx_clear(uint32_t color)
{
    uint32_t hw_color = swap_rb(color);
    unsigned int total_pixels = GFX_SCREEN_W * GFX_SCREEN_H;
    for (unsigned int i = 0; i < total_pixels; i++)
        pixel_buf[i] = hw_color;
    dirty = 1;
}
