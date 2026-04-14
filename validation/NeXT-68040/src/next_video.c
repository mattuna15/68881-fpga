/*
 * next_video.c
 * NeXT 2bpp mono framebuffer → ABGR8888 converter.
 *
 * The NeXT mono display is 1120x832 at 2 bits per pixel.
 * Each byte encodes 4 pixels, MSB first:
 *   bits 7-6 = leftmost pixel, bits 1-0 = rightmost pixel
 *   00 = white, 01 = light grey, 10 = dark grey, 11 = black
 *
 * Stride: set by NEXT_VIDEO_NBPL in next_video.h.
 *   Turbo:   280 bytes/line (1120 px / 4, no padding).
 *   Classic: 288 bytes/line (1152 px / 4, with 32-px right-edge padding).
 *
 * We render into a 1920x1080 ABGR8888 buffer (SCREEN_W x SCREEN_H
 * from text_fb.h).  The NeXT image is centred with black borders.
 *
 * For DPDMA: the ARGB pixel is stored as ABGR in memory (R/B swap).
 * Since our greyscale palette has R=G=B, no swap is needed.
 *
 * Performance: uses per-scanline dirty tracking to avoid re-rendering
 * unchanged lines, and a 256-entry byte→4-pixel LUT to eliminate
 * per-pixel shift/mask operations.
 */

#include "next_video.h"
#include "next_memory.h"
#include "text_fb.h"
#include <string.h>

static uint32_t *pbuf;
static const uint8_t *vram;
static int dirty_flag;

/* 2bpp pixel value → ARGB colour (greyscale: R=G=B, no ABGR swap needed) */
static const uint32_t palette[4] = {
    0xFFFFFFFF,   /* 00 = white */
    0xFFAAAAAA,   /* 01 = light grey */
    0xFF555555,   /* 10 = dark grey */
    0xFF000000    /* 11 = black */
};

/* Byte → 4-pixel LUT: decode_lut[byte][0..3] = 4 ARGB pixels.
 * Eliminates per-pixel shift/mask in the inner loop. */
static uint32_t decode_lut[256][4];

static void build_decode_lut(void)
{
    for (int b = 0; b < 256; b++) {
        decode_lut[b][0] = palette[(b >> 6) & 3];
        decode_lut[b][1] = palette[(b >> 4) & 3];
        decode_lut[b][2] = palette[(b >> 2) & 3];
        decode_lut[b][3] = palette[(b >> 0) & 3];
    }
}

/* Output display dimensions */
#define OUT_W  SCREEN_W
#define OUT_H  SCREEN_H

#if SCREEN_W < NEXT_VIDEO_W || SCREEN_H < NEXT_VIDEO_H
#error "SCREEN_W/H must be >= NEXT_VIDEO_W/H for NeXT video render"
#endif

/* Centering offsets */
#define OFS_X  ((OUT_W - NEXT_VIDEO_W) / 2)   /* (1920-1120)/2 = 400 */
#define OFS_Y  ((OUT_H - NEXT_VIDEO_H) / 2)   /* (1080-832)/2  = 124 */

void next_video_init(uint32_t *pixel_buf, const uint8_t *next_vram)
{
    pbuf = pixel_buf;
    vram = next_vram;
    dirty_flag = 0;

    build_decode_lut();

    /* Clear pixel buffer to black */
    if (pbuf) {
        for (int i = 0; i < OUT_W * OUT_H; i++)
            pbuf[i] = 0xFF000000;
    }
}

/* Render only dirty scanlines.  Returns 1 if any lines were rendered,
 * 0 if nothing changed.  *out_min_y / *out_max_y are the screen-space
 * row range (inclusive) that was updated — callers can limit cache flush
 * to this range. */
int next_video_render_dirty(int *out_min_y, int *out_max_y)
{
    static int borders_done = 0;

    if (!pbuf || !vram)
        return 0;

    /* Get dirty-line bitmap and clear it atomically */
    uint32_t dirty_lines[26];
    next_vram_get_dirty_lines(dirty_lines);

    int max_y = (NEXT_VIDEO_H < OUT_H) ? NEXT_VIDEO_H : OUT_H;
    int visible_bytes = NEXT_VIDEO_W / 4;  /* 1120/4 = 280 */
    int rmin = max_y, rmax = -1;

    for (int y = 0; y < max_y; y++) {
        /* Check dirty bit for this scanline */
        if (!(dirty_lines[y >> 5] & (1u << (y & 31))))
            continue;

        const uint8_t *src = &vram[(uint32_t)y * NEXT_VIDEO_NBPL];
        uint32_t *dst = &pbuf[(uint32_t)(y + OFS_Y) * OUT_W + OFS_X];

        /* Decode 1120 pixels via LUT (280 bytes → 1120 pixels) */
        for (int bx = 0; bx < visible_bytes; bx++) {
            const uint32_t *px = decode_lut[src[bx]];
            dst[0] = px[0];
            dst[1] = px[1];
            dst[2] = px[2];
            dst[3] = px[3];
            dst += 4;
        }

        if (y < rmin) rmin = y;
        if (y > rmax) rmax = y;
    }

    /* Clear borders only on first render (they never change) */
    if (!borders_done) {
        borders_done = 1;
        /* Top border */
        for (int y = 0; y < OFS_Y; y++) {
            uint32_t *row = &pbuf[y * OUT_W];
            for (int x = 0; x < OUT_W; x++)
                row[x] = 0xFF000000;
        }
        /* Left/right borders */
        for (int y = 0; y < max_y; y++) {
            uint32_t *row = &pbuf[(y + OFS_Y) * OUT_W];
            for (int x = 0; x < OFS_X; x++)
                row[x] = 0xFF000000;
            for (int x = OFS_X + NEXT_VIDEO_W; x < OUT_W; x++)
                row[x] = 0xFF000000;
        }
        /* Bottom border */
        for (int y = OFS_Y + max_y; y < OUT_H; y++) {
            uint32_t *row = &pbuf[y * OUT_W];
            for (int x = 0; x < OUT_W; x++)
                row[x] = 0xFF000000;
        }
        /* First render: flush everything */
        rmin = 0;
        rmax = max_y - 1;
    }

    dirty_flag = 0;

    if (rmax < 0)
        return 0;

    /* Convert from VRAM-space to screen-space */
    *out_min_y = rmin + OFS_Y;
    *out_max_y = rmax + OFS_Y;
    return 1;
}

/* Legacy: render all lines (marks everything dirty first) */
void next_video_render(void)
{
    int dummy_min, dummy_max;
    next_vram_mark_all_dirty();
    next_video_render_dirty(&dummy_min, &dummy_max);
}

int next_video_is_dirty(void)
{
    return dirty_flag;
}

void next_video_mark_clean(void)
{
    dirty_flag = 0;
}
