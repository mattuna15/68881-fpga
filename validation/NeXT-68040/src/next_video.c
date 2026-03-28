/*
 * next_video.c
 * NeXT 2bpp mono framebuffer → 1280x720 ARGB8888 converter.
 *
 * The NeXT mono display is 1120x832 at 2 bits per pixel.
 * Each byte encodes 4 pixels, MSB first:
 *   bits 7-6 = leftmost pixel, bits 1-0 = rightmost pixel
 *   00 = white, 01 = light grey, 10 = dark grey, 11 = black
 *
 * Stride: VIDEO_MW (1152) pixels / 4 = 288 bytes per scanline.
 * Only 1120 of 1152 pixels per line are visible.
 *
 * We render into a 1280x720 ARGB8888 buffer.  The NeXT image is
 * scaled down to fit: 1120x832 → 1120x720 (crop bottom 112 lines)
 * then centred horizontally with 80px black bars on each side.
 *
 * For DPDMA: the ARGB pixel is stored as ABGR in memory (R/B swap).
 * Since our greyscale palette has R=G=B, no swap is needed.
 */

#include "next_video.h"
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

/* Output display dimensions */
#define OUT_W  1280
#define OUT_H  720

/* Horizontal centering: (1280 - 1120) / 2 = 80 pixels */
#define OFS_X  ((OUT_W - NEXT_VIDEO_W) / 2)

void next_video_init(uint32_t *pixel_buf, const uint8_t *next_vram)
{
    pbuf = pixel_buf;
    vram = next_vram;
    dirty_flag = 0;

    /* Clear pixel buffer to black */
    if (pbuf) {
        for (int i = 0; i < OUT_W * OUT_H; i++)
            pbuf[i] = 0xFF000000;
    }
}

void next_video_render(void)
{
    if (!pbuf || !vram)
        return;



    /* Render up to 720 scanlines (the NeXT has 832, we crop the bottom).
     * Each VRAM byte contains 4 pixels at 2bpp, MSB first. */
    int max_y = (NEXT_VIDEO_H < OUT_H) ? NEXT_VIDEO_H : OUT_H;

    for (int y = 0; y < max_y; y++) {
        const uint8_t *src = &vram[(uint32_t)y * NEXT_VIDEO_NBPL];
        uint32_t *dst = &pbuf[(uint32_t)y * OUT_W + OFS_X];

        /* Decode 1120 pixels (280 bytes of visible data per line) */
        int visible_bytes = NEXT_VIDEO_W / 4;  /* 1120/4 = 280 */
        for (int bx = 0; bx < visible_bytes; bx++) {
            uint8_t byte = src[bx];
            /* 4 pixels per byte, MSB = leftmost */
            dst[0] = palette[(byte >> 6) & 3];
            dst[1] = palette[(byte >> 4) & 3];
            dst[2] = palette[(byte >> 2) & 3];
            dst[3] = palette[(byte >> 0) & 3];
            dst += 4;
        }
    }

    /* Clear the left/right borders (in case of prior content) */
    for (int y = 0; y < max_y; y++) {
        uint32_t *row = &pbuf[y * OUT_W];
        for (int x = 0; x < OFS_X; x++)
            row[x] = 0xFF000000;
        for (int x = OFS_X + NEXT_VIDEO_W; x < OUT_W; x++)
            row[x] = 0xFF000000;
    }

    /* Clear bottom rows if NeXT image is shorter than 720 */
    for (int y = max_y; y < OUT_H; y++) {
        uint32_t *row = &pbuf[y * OUT_W];
        for (int x = 0; x < OUT_W; x++)
            row[x] = 0xFF000000;
    }

    dirty_flag = 0;
}

int next_video_is_dirty(void)
{
    return dirty_flag;
}

void next_video_mark_clean(void)
{
    dirty_flag = 0;
}
