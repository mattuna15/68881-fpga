/*
 * text_fb.c
 * Software text-to-pixel renderer for 80x30 character display.
 *
 * Maintains an 80x30 character+attribute backing store and renders
 * to a 1280x720 ARGB8888 pixel buffer using an 8x16 VGA font.
 * The 640x480 text area is centred in the 720p frame with black borders.
 */

#include <string.h>
#include "text_fb.h"
#include "font8x16.h"

/* Text backing store: [row][col][0]=character, [1]=attribute */
static uint8_t text_buf[TEXT_ROWS][TEXT_COLS][2];

/* Pixel buffer — 256-byte aligned for DPDMA.
 * 1280*720*4 = 3,686,400 bytes (~3.5 MB) */
static uint32_t pixel_fb[SCREEN_W * SCREEN_H] __attribute__((aligned(256)));

/* Cursor state */
static int cursor_col;
static int cursor_row;

/* Dirty flag — set on any text change, cleared after render */
static volatile int dirty;

/* CGA 16-colour palette (ARGB8888) */
static const uint32_t cga_palette[16] = {
    0xFF000000, /* 0  Black */
    0xFF0000AA, /* 1  Blue */
    0xFF00AA00, /* 2  Green */
    0xFF00AAAA, /* 3  Cyan */
    0xFFAA0000, /* 4  Red */
    0xFFAA00AA, /* 5  Magenta */
    0xFFAA5500, /* 6  Brown */
    0xFFAAAAAA, /* 7  Light Grey */
    0xFF555555, /* 8  Dark Grey */
    0xFF5555FF, /* 9  Light Blue */
    0xFF55FF55, /* 10 Light Green */
    0xFF55FFFF, /* 11 Light Cyan */
    0xFFFF5555, /* 12 Light Red */
    0xFFFF55FF, /* 13 Light Magenta */
    0xFFFFFF55, /* 14 Yellow */
    0xFFFFFFFF, /* 15 White */
};

/* Scroll the text buffer up by one line */
static void scroll_up(void)
{
    /* Move rows 1..29 to 0..28 */
    memmove(&text_buf[0], &text_buf[1],
            (TEXT_ROWS - 1) * TEXT_COLS * 2);

    /* Clear the last row */
    int c;
    for (c = 0; c < TEXT_COLS; c++) {
        text_buf[TEXT_ROWS - 1][c][0] = ' ';
        text_buf[TEXT_ROWS - 1][c][1] = TEXT_ATTR_DEFAULT;
    }
}

uint32_t *text_fb_init(void)
{
    text_fb_clear();

    /* Clear pixel buffer to black */
    memset(pixel_fb, 0, sizeof(pixel_fb));

    return pixel_fb;
}

void text_fb_clear(void)
{
    int r, c;
    for (r = 0; r < TEXT_ROWS; r++) {
        for (c = 0; c < TEXT_COLS; c++) {
            text_buf[r][c][0] = ' ';
            text_buf[r][c][1] = TEXT_ATTR_DEFAULT;
        }
    }
    cursor_col = 0;
    cursor_row = 0;
    dirty = 1;
}

void text_fb_putc(char ch)
{
    switch ((unsigned char)ch) {
    case '\r':
        cursor_col = 0;
        break;

    case '\n':
        cursor_row++;
        if (cursor_row >= TEXT_ROWS) {
            scroll_up();
            cursor_row = TEXT_ROWS - 1;
        }
        break;

    case '\b':
        if (cursor_col > 0)
            cursor_col--;
        break;

    case '\t':
        /* Tab to next 8-column boundary */
        cursor_col = (cursor_col + 8) & ~7;
        if (cursor_col >= TEXT_COLS) {
            cursor_col = 0;
            cursor_row++;
            if (cursor_row >= TEXT_ROWS) {
                scroll_up();
                cursor_row = TEXT_ROWS - 1;
            }
        }
        break;

    default:
        if ((unsigned char)ch >= 0x20) {
            text_buf[cursor_row][cursor_col][0] = (uint8_t)ch;
            text_buf[cursor_row][cursor_col][1] = TEXT_ATTR_DEFAULT;
            cursor_col++;
            if (cursor_col >= TEXT_COLS) {
                cursor_col = 0;
                cursor_row++;
                if (cursor_row >= TEXT_ROWS) {
                    scroll_up();
                    cursor_row = TEXT_ROWS - 1;
                }
            }
        }
        break;
    }

    dirty = 1;
}

void text_fb_set_cursor(int col, int row)
{
    if (col < 0) col = 0;
    if (col >= TEXT_COLS) col = TEXT_COLS - 1;
    if (row < 0) row = 0;
    if (row >= TEXT_ROWS) row = TEXT_ROWS - 1;
    cursor_col = col;
    cursor_row = row;
}

void text_fb_get_cursor(int *col, int *row)
{
    if (col) *col = cursor_col;
    if (row) *row = cursor_row;
}

void text_fb_render(void)
{
    int row, col, py, px;

    /* Clear borders to black (only needed once, but safe to repeat) */
    /* Top border */
    memset(&pixel_fb[0], 0, TEXT_OFS_Y * SCREEN_W * 4);
    /* Bottom border */
    memset(&pixel_fb[(TEXT_OFS_Y + TEXT_PX_H) * SCREEN_W], 0,
           (SCREEN_H - TEXT_OFS_Y - TEXT_PX_H) * SCREEN_W * 4);

    for (row = 0; row < TEXT_ROWS; row++) {
        for (col = 0; col < TEXT_COLS; col++) {
            uint8_t ch   = text_buf[row][col][0];
            uint8_t attr = text_buf[row][col][1];

            uint32_t fg_color = cga_palette[attr & 0x0F];
            uint32_t bg_color = cga_palette[(attr >> 4) & 0x07];

            const uint8_t *glyph = &font8x16_data[(unsigned)ch * FONT_H];

            int base_y = TEXT_OFS_Y + row * FONT_H;
            int base_x = TEXT_OFS_X + col * FONT_W;

            for (py = 0; py < FONT_H; py++) {
                uint8_t bits = glyph[py];
                uint32_t *scanline = &pixel_fb[(base_y + py) * SCREEN_W + base_x];

                /* Left border pixels for this row (only on first column) */
                if (col == 0) {
                    memset(&pixel_fb[(base_y + py) * SCREEN_W], 0,
                           TEXT_OFS_X * 4);
                }

                for (px = 0; px < FONT_W; px++) {
                    scanline[px] = (bits & 0x80) ? fg_color : bg_color;
                    bits <<= 1;
                }

                /* Right border pixels (only on last column) */
                if (col == TEXT_COLS - 1) {
                    int right_start = TEXT_OFS_X + TEXT_PX_W;
                    memset(&pixel_fb[(base_y + py) * SCREEN_W + right_start], 0,
                           (SCREEN_W - right_start) * 4);
                }
            }
        }
    }

    /* Render underline cursor at current position (last 2 scanlines, white) */
    if (cursor_row < TEXT_ROWS && cursor_col < TEXT_COLS) {
        int base_y = TEXT_OFS_Y + cursor_row * FONT_H;
        int base_x = TEXT_OFS_X + cursor_col * FONT_W;

        /* Draw cursor on last 2 scanlines of the cell (underline cursor) */
        for (py = FONT_H - 2; py < FONT_H; py++) {
            uint32_t *scanline = &pixel_fb[(base_y + py) * SCREEN_W + base_x];
            for (px = 0; px < FONT_W; px++) {
                scanline[px] = cga_palette[15]; /* white cursor */
            }
        }
    }
}

int text_fb_is_dirty(void)
{
    return dirty;
}

void text_fb_mark_clean(void)
{
    dirty = 0;
}

uint32_t *text_fb_get_pixel_buf(void)
{
    return pixel_fb;
}
