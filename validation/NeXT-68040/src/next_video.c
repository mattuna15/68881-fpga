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

/* Output display dimensions */
#define OUT_W  SCREEN_W
#define OUT_H  SCREEN_H

/* Centering offsets */
#define OFS_X  ((OUT_W - NEXT_VIDEO_W) / 2)   /* (1920-1120)/2 = 400 */
#define OFS_Y  ((OUT_H - NEXT_VIDEO_H) / 2)   /* (1080-832)/2  = 124 */

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

    /* Debug: one-shot dump of VRAM content to verify it has real display data */
    {
        static int dumped = 0;
        static int call_count = 0;
        call_count++;
        if (!dumped && call_count > 10) {
            /* Check what's actually in VRAM */
            int zeros = 0, ffs = 0, aas = 0, other = 0;
            for (int i = 0; i < 232960; i++) {
                if (vram[i] == 0x00) zeros++;
                else if (vram[i] == 0xFF) ffs++;
                else if (vram[i] == 0xAA) aas++;
                else other++;
            }
            xil_printf("[VRAM] Content: zeros=%d ffs=%d AAs=%d other=%d (of 232960)\r\n",
                       zeros, ffs, aas, other);
            /* Dump a few bytes from middle of screen */
            int mid = 288 * 400;  /* line 400 */
            xil_printf("[VRAM] @line400: %02X %02X %02X %02X %02X %02X %02X %02X\r\n",
                       vram[mid], vram[mid+1], vram[mid+2], vram[mid+3],
                       vram[mid+4], vram[mid+5], vram[mid+6], vram[mid+7]);
            dumped = 1;
        }
    }



    /* Render up to 720 scanlines (the NeXT has 832, we crop the bottom).
     * Each VRAM byte contains 4 pixels at 2bpp, MSB first. */
    int max_y = (NEXT_VIDEO_H < OUT_H) ? NEXT_VIDEO_H : OUT_H;

    for (int y = 0; y < max_y; y++) {
        const uint8_t *src = &vram[(uint32_t)y * NEXT_VIDEO_NBPL];
        uint32_t *dst = &pbuf[(uint32_t)(y + OFS_Y) * OUT_W + OFS_X];

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

    /* Clear borders around the centred NeXT display */
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
