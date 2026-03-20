/*
 * atari_video.c
 * Atari ST video shifter emulation — bitplane decode + palette + scaling.
 *
 * Supports all three ST resolutions:
 *   Low:  320x200, 4 planes, 16 colours → 4x3 scale → 1280x600
 *   Med:  640x200, 2 planes, 4 colours  → 2x3 scale → 1280x600
 *   High: 640x400, 1 plane,  2 colours  → 2x1 scale → 1280x400
 *
 * Palette entries are pre-expanded from 3-bit ST RGB to 8-bit ABGR
 * on write, so the render loop needs no per-pixel colour conversion.
 */

#include <string.h>
#include "atari_video.h"
#include "emu_memory.h"
#include "xil_printf.h"

/* Screen dimensions (must match dp_video / text_fb) */
#define SCREEN_W  1280
#define SCREEN_H  720

/* ---------- internal state ---------- */

static uint32_t *pbuf;          /* shared pixel buffer (ABGR) */
static int       active;        /* set when $FF8260 written */

/* Video base address registers */
static uint8_t vid_base_hi;     /* $FF8201 */
static uint8_t vid_base_mid;    /* $FF8203 */
static uint8_t vid_base_lo;     /* $FF820D (STe) */

static uint8_t sync_mode;       /* $FF820A */
static uint8_t shifter_res;     /* $FF8260: 0=low, 1=med, 2=high */

/* Palette: ST format and pre-expanded ABGR */
static uint16_t palette[16];
static uint32_t palette_abgr[16];

/* Last rendered resolution (to detect mode changes for border clear) */
static int last_res = -1;

/* ---------- palette expansion ---------- */

/* Expand 3-bit ST colour component (0-7) to 8-bit (0-255) */
static inline uint32_t expand_st_color(uint16_t stc)
{
    unsigned r3 = (stc >> 8) & 7;
    unsigned g3 = (stc >> 4) & 7;
    unsigned b3 = stc & 7;
    /* Replicate 3 bits into 8: abc -> abcabcab */
    unsigned r8 = (r3 << 5) | (r3 << 2) | (r3 >> 1);
    unsigned g8 = (g3 << 5) | (g3 << 2) | (g3 >> 1);
    unsigned b8 = (b3 << 5) | (b3 << 2) | (b3 >> 1);
    /* ABGR format for DPDMA */
    return 0xFF000000u | (b8 << 16) | (g8 << 8) | r8;
}

/* ---------- default ST palette ---------- */

static const uint16_t default_palette[16] = {
    0x0FFF, /* 0: white */
    0x0F00, /* 1: red */
    0x00F0, /* 2: green */
    0x0FF0, /* 3: yellow */
    0x000F, /* 4: blue */
    0x0F0F, /* 5: magenta */
    0x00FF, /* 6: cyan */
    0x0555, /* 7: light grey */
    0x0333, /* 8: dark grey */
    0x0F33, /* 9: light red */
    0x03F3, /* 10: light green */
    0x0FF3, /* 11: light yellow */
    0x033F, /* 12: light blue */
    0x0F3F, /* 13: light magenta */
    0x03FF, /* 14: light cyan */
    0x0000, /* 15: black */
};

/* ---------- public API ---------- */

void atari_vid_init(uint32_t *pixel_buf)
{
    pbuf = pixel_buf;
    active = 0;
    last_res = -1;

    /* Default video base: $F80000 */
    vid_base_hi  = 0xF8;
    vid_base_mid = 0x00;
    vid_base_lo  = 0x00;

    sync_mode   = 0;
    shifter_res = 0;  /* low res */

    /* Load default palette */
    for (int i = 0; i < 16; i++) {
        palette[i] = default_palette[i];
        palette_abgr[i] = expand_st_color(default_palette[i]);
    }

    xil_printf("[VID] Atari video init (base=$%02X%02X%02X)\r\n",
               vid_base_hi, vid_base_mid, vid_base_lo);
}

int atari_vid_active(void)
{
    return active;
}

unsigned int atari_vid_read(unsigned int offset)
{
    if (offset == 0x01) return vid_base_hi;
    if (offset == 0x03) return vid_base_mid;
    if (offset == 0x0A) return sync_mode;
    if (offset == 0x0D) return vid_base_lo;
    if (offset == 0x60) return shifter_res;

    /* Palette registers: 0x40-0x5E (16 words) */
    if (offset >= 0x40 && offset <= 0x5F) {
        int idx = (offset - 0x40) >> 1;
        if (offset & 1)
            return palette[idx] & 0xFF;        /* low byte */
        else
            return (palette[idx] >> 8) & 0xFF; /* high byte */
    }

    return 0;
}

void atari_vid_write(unsigned int offset, unsigned int value)
{
    value &= 0xFF;

    if (offset == 0x01) { vid_base_hi  = value; return; }
    if (offset == 0x03) { vid_base_mid = value; return; }
    if (offset == 0x0A) { sync_mode    = value; return; }
    if (offset == 0x0D) { vid_base_lo  = value; return; }

    if (offset == 0x60) {
        shifter_res = value & 3;
        active = 1;
        return;
    }

    /* Palette registers: 0x40-0x5E (16 words, byte-addressable) */
    if (offset >= 0x40 && offset <= 0x5F) {
        int idx = (offset - 0x40) >> 1;
        if (offset & 1)
            palette[idx] = (palette[idx] & 0xFF00) | value;
        else
            palette[idx] = (palette[idx] & 0x00FF) | (value << 8);
        palette_abgr[idx] = expand_st_color(palette[idx]);
        return;
    }
}

/* ---------- bitplane rendering ---------- */

/* Clear entire pixel buffer to black (ABGR) */
static void clear_borders(void)
{
    for (int i = 0; i < SCREEN_W * SCREEN_H; i++)
        pbuf[i] = 0xFF000000u;
}

/* Low res: 320x200, 4 planes → 1280x600 (4x horiz, 3x vert), 60px top border */
static void render_low(const uint8_t *ram, uint32_t base)
{
    const int top_border = 60;

    for (int st_y = 0; st_y < 200; st_y++) {
        const uint8_t *row = ram + base + st_y * 160;
        int out_y_base = top_border + st_y * 3;

        for (int chunk = 0; chunk < 20; chunk++) {
            /* Read 4 bitplane words (big-endian) */
            uint16_t w0 = (row[0] << 8) | row[1];
            uint16_t w1 = (row[2] << 8) | row[3];
            uint16_t w2 = (row[4] << 8) | row[5];
            uint16_t w3 = (row[6] << 8) | row[7];
            row += 8;

            for (int bit = 15; bit >= 0; bit--) {
                int idx = ((w0 >> bit) & 1)
                        | (((w1 >> bit) & 1) << 1)
                        | (((w2 >> bit) & 1) << 2)
                        | (((w3 >> bit) & 1) << 3);
                uint32_t color = palette_abgr[idx];

                int out_x = (chunk * 16 + (15 - bit)) * 4;

                /* Write 4 pixels wide × 3 scanlines tall */
                for (int sy = 0; sy < 3; sy++) {
                    uint32_t *dst = pbuf + (out_y_base + sy) * SCREEN_W + out_x;
                    dst[0] = color;
                    dst[1] = color;
                    dst[2] = color;
                    dst[3] = color;
                }
            }
        }
    }
}

/* Medium res: 640x200, 2 planes → 1280x600 (2x horiz, 3x vert), 60px top border */
static void render_med(const uint8_t *ram, uint32_t base)
{
    const int top_border = 60;

    for (int st_y = 0; st_y < 200; st_y++) {
        const uint8_t *row = ram + base + st_y * 160;
        int out_y_base = top_border + st_y * 3;

        for (int chunk = 0; chunk < 40; chunk++) {
            uint16_t w0 = (row[0] << 8) | row[1];
            uint16_t w1 = (row[2] << 8) | row[3];
            row += 4;

            for (int bit = 15; bit >= 0; bit--) {
                int idx = ((w0 >> bit) & 1)
                        | (((w1 >> bit) & 1) << 1);
                uint32_t color = palette_abgr[idx];

                int out_x = (chunk * 16 + (15 - bit)) * 2;

                for (int sy = 0; sy < 3; sy++) {
                    uint32_t *dst = pbuf + (out_y_base + sy) * SCREEN_W + out_x;
                    dst[0] = color;
                    dst[1] = color;
                }
            }
        }
    }
}

/* High res: 640x400, 1 plane → 1280x400 (2x horiz, 1x vert), 160px top border */
static void render_high(const uint8_t *ram, uint32_t base)
{
    const int top_border = 160;

    for (int st_y = 0; st_y < 400; st_y++) {
        const uint8_t *row = ram + base + st_y * 80;
        int out_y = top_border + st_y;

        for (int chunk = 0; chunk < 40; chunk++) {
            uint16_t w0 = (row[0] << 8) | row[1];
            row += 2;

            for (int bit = 15; bit >= 0; bit--) {
                int idx = (w0 >> bit) & 1;
                uint32_t color = palette_abgr[idx];

                int out_x = (chunk * 16 + (15 - bit)) * 2;

                uint32_t *dst = pbuf + out_y * SCREEN_W + out_x;
                dst[0] = color;
                dst[1] = color;
            }
        }
    }
}

int atari_vid_render(void)
{
    if (!active || !pbuf)
        return 0;

    uint32_t base = ((uint32_t)vid_base_hi << 16)
                  | ((uint32_t)vid_base_mid << 8)
                  | (uint32_t)vid_base_lo;

    /* Ensure base is within emu_ram bounds */
    base &= EMU_RAM_MASK;

    /* Clear borders on resolution change */
    if (shifter_res != last_res) {
        clear_borders();
        last_res = shifter_res;
    }

    switch (shifter_res) {
    case 0: render_low(emu_ram, base);  break;
    case 1: render_med(emu_ram, base);  break;
    case 2: render_high(emu_ram, base); break;
    default: break;
    }

    return 1;
}
