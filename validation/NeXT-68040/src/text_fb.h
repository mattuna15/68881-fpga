/*
 * text_fb.h
 * Text-mode framebuffer — 80x30 character cells rendered to an
 * ARGB8888 pixel buffer for DisplayPort output.
 *
 * Characters are stored in a backing buffer with attributes.
 * text_fb_render() rasterises the text to pixels using an 8x16 font.
 * Resolution: 640x480 text area centred in a 1280x720 frame.
 */

#ifndef TEXT_FB_H
#define TEXT_FB_H

#include <stdint.h>

/* Text dimensions */
#define TEXT_COLS    80
#define TEXT_ROWS    30

/* Pixel buffer dimensions (720p) */
#define SCREEN_W     1280
#define SCREEN_H     720

/* Font cell size */
#define FONT_W       8
#define FONT_H       16

/* Text area pixel dimensions */
#define TEXT_PX_W    (TEXT_COLS * FONT_W)    /* 640 */
#define TEXT_PX_H    (TEXT_ROWS * FONT_H)    /* 480 */

/* Centering offsets within the 1280x720 frame */
#define TEXT_OFS_X   ((SCREEN_W - TEXT_PX_W) / 2)   /* 320 */
#define TEXT_OFS_Y   ((SCREEN_H - TEXT_PX_H) / 2)   /* 120 */

/* Pixel buffer size in bytes (ARGB8888 = 4 bytes/pixel) */
#define PIXEL_BUF_SIZE  (SCREEN_W * SCREEN_H * 4)

/* Text attribute byte layout (CGA-style):
 * bits [3:0] = foreground colour index
 * bits [6:4] = background colour index
 * bit  [7]   = blink (ignored for now)
 *
 * Default: light grey on black = 0x07
 */
#define TEXT_ATTR_DEFAULT  0x07

/* Initialize the text framebuffer — clears text buffer and pixel buffer.
 * Returns pointer to the pixel buffer (256-byte aligned, in DDR). */
uint32_t *text_fb_init(void);

/* Write a character at the current cursor position and advance cursor.
 * Handles CR, LF, BS, TAB, and printable ASCII. Scrolls when needed. */
void text_fb_putc(char ch);

/* Set cursor position (0-based). Clamps to valid range. */
void text_fb_set_cursor(int col, int row);

/* Get current cursor position */
void text_fb_get_cursor(int *col, int *row);

/* Clear the entire text buffer and reset cursor to (0,0) */
void text_fb_clear(void);

/* Render the text buffer to the pixel buffer.
 * Call this periodically from the main loop when dirty. */
void text_fb_render(void);

/* Check/clear dirty flag */
int  text_fb_is_dirty(void);
void text_fb_mark_clean(void);

/* Get pointer to the pixel buffer (for DPDMA configuration) */
uint32_t *text_fb_get_pixel_buf(void);

#endif /* TEXT_FB_H */
