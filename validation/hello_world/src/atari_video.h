/*
 * atari_video.h
 * Atari ST video shifter emulation.
 *
 * Emulates the Atari ST video registers at $FF8200-$FF8261:
 * video base address, palette (16 entries), and shifter resolution.
 * Converts interleaved bitplane framebuffer data from emu_ram[] into
 * ABGR pixels scaled to fit the 1280x720 DisplayPort output.
 */

#ifndef ATARI_VIDEO_H
#define ATARI_VIDEO_H

#include <stdint.h>

/* Video register range in 68K address space */
#define ATARI_VID_BASE  0xFF8200
#define ATARI_VID_SIZE  0x62

/* Fast inline range check */
static inline int atari_vid_is_reg(unsigned int addr)
{
    return (addr >= ATARI_VID_BASE) && (addr < ATARI_VID_BASE + ATARI_VID_SIZE);
}

/* Initialise video state with pointer to shared ABGR pixel buffer */
void atari_vid_init(uint32_t *pixel_buf);

/* Read a video register (offset = addr - ATARI_VID_BASE) */
unsigned int atari_vid_read(unsigned int offset);

/* Write a video register (offset = addr - ATARI_VID_BASE) */
void atari_vid_write(unsigned int offset, unsigned int value);

/* Render current bitplane framebuffer to pixel_buf.
 * Returns 1 if a frame was rendered, 0 if not active. */
int atari_vid_render(void);

/* Check if Atari video mode is active (resolution register written) */
int atari_vid_active(void);

#endif /* ATARI_VIDEO_H */
