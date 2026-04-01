/*
 * next_video.h
 * NeXT mono framebuffer → ARGB8888 pixel buffer converter.
 *
 * Converts the NeXT 2bpp mono framebuffer (1120x832 at 0x0B000000)
 * into the ARGB8888 pixel buffer used by the DP/DPDMA display.
 * The NeXT image is centred within the output frame (1920x1080).
 *
 * On real hardware: pixel_buf feeds DPDMA → DisplayPort.
 * On QEMU: no display, but the conversion still runs (can be disabled).
 */

#ifndef NEXT_VIDEO_H
#define NEXT_VIDEO_H

#include <stdint.h>

/* NeXT mono display parameters (from mk-108.1 nextdev/video.h) */
#define NEXT_VIDEO_W     1120   /* visible pixels per scanline */
#define NEXT_VIDEO_MW    1152   /* actual pixels per scanline (non-Turbo, with 32px pad) */
#define NEXT_VIDEO_H     832    /* visible scanlines */

/* Stride: Turbo models have NO padding (280 bytes/line).
 * Non-Turbo models pad to 1152 pixels (288 bytes/line).
 * Source: Previous emulator src/fast_screen.c blitBW(). */
#define NEXT_VIDEO_NBPL_TURBO    (NEXT_VIDEO_W >> 2)     /* 280 bytes/line */
#define NEXT_VIDEO_NBPL_NONTURBO (NEXT_VIDEO_MW >> 2)    /* 288 bytes/line */
#define NEXT_VIDEO_NBPL          NEXT_VIDEO_NBPL_NONTURBO  /* SCR1 reports non-Turbo → stride 288 */

/* 2bpp greyscale values → ARGB8888 */
#define NEXT_WHITE    0xFFFFFFFF   /* 00 */
#define NEXT_LTGRAY   0xFFAAAAAA   /* 01 */
#define NEXT_DKGRAY   0xFF555555   /* 10 */
#define NEXT_BLACK    0xFF000000   /* 11 */

/* Initialise the video converter.
 * pixel_buf: the ARGB8888 buffer for DP output (1280x720).
 * vram: the NeXT emulated VRAM (256 KB at 0x0B000000). */
void next_video_init(uint32_t *pixel_buf, const uint8_t *vram);

/* Render dirty NeXT VRAM scanlines into the pixel buffer.
 * Converts 2bpp mono → ABGR8888, centred within 1920x1080.
 * Sets *min_y/*max_y to the screen-space row range that was updated
 * (for targeted cache flush). Returns 0 if nothing was rendered. */
int next_video_render_dirty(int *min_y, int *max_y);

/* Render all scanlines (legacy, calls mark_all_dirty + render_dirty). */
void next_video_render(void);

/* Check if VRAM has been written to since last render */
int next_video_is_dirty(void);
void next_video_mark_clean(void);

#endif /* NEXT_VIDEO_H */
