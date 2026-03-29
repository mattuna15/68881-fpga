/*
 * gfx_fb.h
 * Pixel-addressable graphics framebuffer for M68K emulator.
 *
 * Provides a 1280x720 ARGB8888 framebuffer mapped at 0x800000 in the
 * 68k address space.  When graphics mode is active, writes to this
 * region go directly into the shared pixel buffer used by DPDMA.
 *
 * Control registers at 0xFD0040 handle mode switching and commands.
 */

#ifndef GFX_FB_H
#define GFX_FB_H

#include <stdint.h>

/* Framebuffer mapping in 68k address space */
#define GFX_FB_BASE   0x800000
#define GFX_FB_SIZE   (1280 * 720 * 4)   /* 3,686,400 bytes */
#define GFX_FB_END    (GFX_FB_BASE + GFX_FB_SIZE)  /* 0xB84000 */

/* Graphics I/O control register block */
#define GFX_IO_BASE   0xFD0040
#define GFX_IO_SIZE   0x10

/* Screen dimensions — must match SCREEN_W/SCREEN_H in text_fb.h */
#define GFX_SCREEN_W  1920
#define GFX_SCREEN_H  1080

/* Initialize graphics subsystem with pointer to shared pixel buffer */
void gfx_init(uint32_t *pixel_buf);

/* Mode control */
void gfx_set_mode(int mode);
int  gfx_get_mode(void);

/* Fast inline check: is this address in the graphics framebuffer? */
static inline int gfx_is_fb(unsigned int addr)
{
    extern int gfx_mode;
    return gfx_mode && (addr >= GFX_FB_BASE) && (addr < GFX_FB_END);
}

/* Fast inline check: is this address in the graphics I/O registers? */
static inline int gfx_is_io(unsigned int addr)
{
    return (addr >= GFX_IO_BASE) && (addr < GFX_IO_BASE + GFX_IO_SIZE);
}

/* Framebuffer read/write (big-endian byte mapping) */
unsigned int gfx_read_8(unsigned int addr);
unsigned int gfx_read_16(unsigned int addr);
unsigned int gfx_read_32(unsigned int addr);
void gfx_write_8(unsigned int addr, unsigned int value);
void gfx_write_16(unsigned int addr, unsigned int value);
void gfx_write_32(unsigned int addr, unsigned int value);

/* Control register access */
unsigned int gfx_io_read(unsigned int offset);
void gfx_io_write(unsigned int offset, unsigned int value);

/* Dirty tracking for display refresh */
int  gfx_is_dirty(void);
void gfx_mark_clean(void);

/* Fill entire framebuffer with a colour */
void gfx_clear(uint32_t color);

#endif /* GFX_FB_H */
