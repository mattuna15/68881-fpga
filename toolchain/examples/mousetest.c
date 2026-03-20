/*
 * mousetest.c -- USB mouse demo for Merlin 2.
 *
 * Draws a crosshair cursor that follows the mouse.  Clicks print
 * the position and button to the top of the screen.  Press any key
 * on the keyboard to exit.
 *
 * Build:  make mousetest.srec
 * Load:   L (from BIOS prompt, paste S-record)
 * Run:    G 2000
 */

#include <stdio.h>
#include "../lib/merlin2_gfx.h"
#include "../lib/merlin2_mouse.h"

/* Direct memory-mapped mouse I/O (works without updated BIOS ROM).
 * These read the ARM-side mouse state registers directly. */
#define MOUSE_IO_BASE   0xFD0050
#define MOUSE_BTN       (*(volatile uint8_t  *)(MOUSE_IO_BASE + 0x00))
#define MOUSE_DX        (*(volatile int16_t  *)(MOUSE_IO_BASE + 0x02))
#define MOUSE_DY        (*(volatile int16_t  *)(MOUSE_IO_BASE + 0x04))
#define MOUSE_ABS_X     (*(volatile uint16_t *)(MOUSE_IO_BASE + 0x06))
#define MOUSE_ABS_Y     (*(volatile uint16_t *)(MOUSE_IO_BASE + 0x08))

/* Screen dimensions */
#define SCR_W   GFX_SCREEN_W   /* 1280 */
#define SCR_H   GFX_SCREEN_H   /* 720 */

/* Cursor size (half-arm length) */
#define CUR_SIZE  10

/* Colours */
#define COL_BG      0xFF101020  /* dark blue-grey background */
#define COL_CURSOR  0xFF00FF00  /* green crosshair */
#define COL_CLICK_L 0xFFFF4040  /* red dot for left click */
#define COL_CLICK_R 0xFF4040FF  /* blue dot for right click */
#define COL_CLICK_M 0xFFFFFF40  /* yellow dot for middle click */
#define COL_TEXT    0xFFFFFFFF  /* white text */
#define COL_BANNER  0xFF202040  /* banner background */

/* Simple 5x7 font for on-screen text (digits + a few chars) */
static void draw_char(int x, int y, char ch, uint32_t colour);
static void draw_string(int x, int y, const char *s, uint32_t colour);
static void draw_number(int x, int y, int num, uint32_t colour);

/* Draw a horizontal line */
static void hline(int x0, int x1, int y, uint32_t c)
{
    if (y < 0 || y >= SCR_H) return;
    if (x0 < 0) x0 = 0;
    if (x1 >= SCR_W) x1 = SCR_W - 1;
    volatile uint32_t *fb = gfx_fb_ptr(x0, y);
    for (int x = x0; x <= x1; x++)
        *fb++ = c;
}

/* Draw a vertical line */
static void vline(int x, int y0, int y1, uint32_t c)
{
    if (x < 0 || x >= SCR_W) return;
    if (y0 < 0) y0 = 0;
    if (y1 >= SCR_H) y1 = SCR_H - 1;
    for (int y = y0; y <= y1; y++)
        *gfx_fb_ptr(x, y) = c;
}

/* Draw crosshair cursor at (cx, cy) */
static void draw_cursor(int cx, int cy, uint32_t colour)
{
    hline(cx - CUR_SIZE, cx - 2, cy, colour);
    hline(cx + 2, cx + CUR_SIZE, cy, colour);
    vline(cx, cy - CUR_SIZE, cy - 2, colour);
    vline(cx, cy + 2, cy + CUR_SIZE, colour);
    /* Centre dot */
    if ((unsigned)cx < SCR_W && (unsigned)cy < SCR_H)
        *gfx_fb_ptr(cx, cy) = colour;
}

/* Draw a filled circle (click marker) */
static void draw_dot(int cx, int cy, int radius, uint32_t colour)
{
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            if (dx * dx + dy * dy <= radius * radius) {
                int px = cx + dx, py = cy + dy;
                if ((unsigned)px < SCR_W && (unsigned)py < SCR_H)
                    *gfx_fb_ptr(px, py) = colour;
            }
        }
    }
}

/* Erase cursor by redrawing with background colour */
static void erase_cursor(int cx, int cy)
{
    draw_cursor(cx, cy, COL_BG);
}

/* Draw the info banner at top of screen */
static void draw_banner(int mx, int my, uint8_t buttons)
{
    /* Clear banner area */
    for (int y = 0; y < 20; y++)
        hline(0, SCR_W - 1, y, COL_BANNER);

    draw_string(10, 6, "Mouse Demo", COL_TEXT);

    /* Position */
    draw_string(200, 6, "X:", COL_TEXT);
    draw_number(220, 6, mx, COL_TEXT);
    draw_string(320, 6, "Y:", COL_TEXT);
    draw_number(340, 6, my, COL_TEXT);

    /* Buttons */
    draw_string(440, 6, "Btn:", COL_TEXT);
    if (buttons & MOUSE_BTN_LEFT)
        draw_string(488, 6, "L", COL_CLICK_L);
    if (buttons & MOUSE_BTN_RIGHT)
        draw_string(500, 6, "R", COL_CLICK_R);
    if (buttons & MOUSE_BTN_MIDDLE)
        draw_string(512, 6, "M", COL_CLICK_M);

    draw_string(600, 6, "[Press key to exit]", COL_TEXT);
}

int main(void)
{
    printf("Mouse demo - move mouse, click to mark, press key to exit\n");

    gfx_set_mode(1);
    gfx_clear(COL_BG);

    /* Centre the mouse (direct write — works without updated BIOS) */
    MOUSE_ABS_X = SCR_W / 2;
    MOUSE_ABS_Y = SCR_H / 2;

    int old_x = SCR_W / 2, old_y = SCR_H / 2;
    uint8_t old_buttons = 0;

    draw_cursor(old_x, old_y, COL_CURSOR);
    draw_banner(old_x, old_y, 0);

    while (!gfx_char_ready()) {
        /* Read mouse state directly from memory-mapped I/O */
        uint8_t buttons = MOUSE_BTN;
        (void)MOUSE_DX;  /* read to clear deltas */
        (void)MOUSE_DY;
        int mx = (int)MOUSE_ABS_X;
        int my = (int)MOUSE_ABS_Y;

        /* Clamp to screen (safety) */
        if (mx < 0) mx = 0;
        if (mx >= SCR_W) mx = SCR_W - 1;
        if (my < 0) my = 0;
        if (my >= SCR_H) my = SCR_H - 1;

        /* Only redraw if something changed */
        if (mx != old_x || my != old_y || buttons != old_buttons) {
            /* Erase old cursor */
            erase_cursor(old_x, old_y);

            /* Draw click markers on button press (not held) */
            if ((buttons & MOUSE_BTN_LEFT) && !(old_buttons & MOUSE_BTN_LEFT))
                draw_dot(mx, my, 4, COL_CLICK_L);
            if ((buttons & MOUSE_BTN_RIGHT) && !(old_buttons & MOUSE_BTN_RIGHT))
                draw_dot(mx, my, 4, COL_CLICK_R);
            if ((buttons & MOUSE_BTN_MIDDLE) && !(old_buttons & MOUSE_BTN_MIDDLE))
                draw_dot(mx, my, 4, COL_CLICK_M);

            /* Draw new cursor */
            draw_cursor(mx, my, COL_CURSOR);

            /* Update banner */
            draw_banner(mx, my, buttons);

            old_x = mx;
            old_y = my;
            old_buttons = buttons;
        }
    }

    gfx_set_mode(0);
    printf("Done.\n");
    return 0;
}

/* ------------------------------------------------------------------ */
/* Minimal bitmap font for on-screen text (5x7, ASCII 32-127)         */
/* ------------------------------------------------------------------ */

/* Compact 5x7 font — each char is 5 bytes (columns), each byte has 7 row bits */
static const uint8_t font5x7[][5] = {
    /* 32 space */ {0x00,0x00,0x00,0x00,0x00},
    /* 33 !     */ {0x00,0x00,0x5F,0x00,0x00},
    /* 34 "     */ {0x00,0x07,0x00,0x07,0x00},
    /* 35 #     */ {0x14,0x7F,0x14,0x7F,0x14},
    /* 36 $     */ {0x24,0x2A,0x7F,0x2A,0x12},
    /* 37 %     */ {0x23,0x13,0x08,0x64,0x62},
    /* 38 &     */ {0x36,0x49,0x55,0x22,0x50},
    /* 39 '     */ {0x00,0x05,0x03,0x00,0x00},
    /* 40 (     */ {0x00,0x1C,0x22,0x41,0x00},
    /* 41 )     */ {0x00,0x41,0x22,0x1C,0x00},
    /* 42 *     */ {0x14,0x08,0x3E,0x08,0x14},
    /* 43 +     */ {0x08,0x08,0x3E,0x08,0x08},
    /* 44 ,     */ {0x00,0x50,0x30,0x00,0x00},
    /* 45 -     */ {0x08,0x08,0x08,0x08,0x08},
    /* 46 .     */ {0x00,0x60,0x60,0x00,0x00},
    /* 47 /     */ {0x20,0x10,0x08,0x04,0x02},
    /* 48 0     */ {0x3E,0x51,0x49,0x45,0x3E},
    /* 49 1     */ {0x00,0x42,0x7F,0x40,0x00},
    /* 50 2     */ {0x42,0x61,0x51,0x49,0x46},
    /* 51 3     */ {0x21,0x41,0x45,0x4B,0x31},
    /* 52 4     */ {0x18,0x14,0x12,0x7F,0x10},
    /* 53 5     */ {0x27,0x45,0x45,0x45,0x39},
    /* 54 6     */ {0x3C,0x4A,0x49,0x49,0x30},
    /* 55 7     */ {0x01,0x71,0x09,0x05,0x03},
    /* 56 8     */ {0x36,0x49,0x49,0x49,0x36},
    /* 57 9     */ {0x06,0x49,0x49,0x29,0x1E},
    /* 58 :     */ {0x00,0x36,0x36,0x00,0x00},
    /* 59 ;     */ {0x00,0x56,0x36,0x00,0x00},
    /* 60 <     */ {0x08,0x14,0x22,0x41,0x00},
    /* 61 =     */ {0x14,0x14,0x14,0x14,0x14},
    /* 62 >     */ {0x00,0x41,0x22,0x14,0x08},
    /* 63 ?     */ {0x02,0x01,0x51,0x09,0x06},
    /* 64 @     */ {0x32,0x49,0x79,0x41,0x3E},
    /* 65 A     */ {0x7E,0x11,0x11,0x11,0x7E},
    /* 66 B     */ {0x7F,0x49,0x49,0x49,0x36},
    /* 67 C     */ {0x3E,0x41,0x41,0x41,0x22},
    /* 68 D     */ {0x7F,0x41,0x41,0x22,0x1C},
    /* 69 E     */ {0x7F,0x49,0x49,0x49,0x41},
    /* 70 F     */ {0x7F,0x09,0x09,0x09,0x01},
    /* 71 G     */ {0x3E,0x41,0x49,0x49,0x7A},
    /* 72 H     */ {0x7F,0x08,0x08,0x08,0x7F},
    /* 73 I     */ {0x00,0x41,0x7F,0x41,0x00},
    /* 74 J     */ {0x20,0x40,0x41,0x3F,0x01},
    /* 75 K     */ {0x7F,0x08,0x14,0x22,0x41},
    /* 76 L     */ {0x7F,0x40,0x40,0x40,0x40},
    /* 77 M     */ {0x7F,0x02,0x0C,0x02,0x7F},
    /* 78 N     */ {0x7F,0x04,0x08,0x10,0x7F},
    /* 79 O     */ {0x3E,0x41,0x41,0x41,0x3E},
    /* 80 P     */ {0x7F,0x09,0x09,0x09,0x06},
    /* 81 Q     */ {0x3E,0x41,0x51,0x21,0x5E},
    /* 82 R     */ {0x7F,0x09,0x19,0x29,0x46},
    /* 83 S     */ {0x46,0x49,0x49,0x49,0x31},
    /* 84 T     */ {0x01,0x01,0x7F,0x01,0x01},
    /* 85 U     */ {0x3F,0x40,0x40,0x40,0x3F},
    /* 86 V     */ {0x1F,0x20,0x40,0x20,0x1F},
    /* 87 W     */ {0x3F,0x40,0x38,0x40,0x3F},
    /* 88 X     */ {0x63,0x14,0x08,0x14,0x63},
    /* 89 Y     */ {0x07,0x08,0x70,0x08,0x07},
    /* 90 Z     */ {0x61,0x51,0x49,0x45,0x43},
    /* 91 [     */ {0x00,0x7F,0x41,0x41,0x00},
    /* 92 \     */ {0x02,0x04,0x08,0x10,0x20},
    /* 93 ]     */ {0x00,0x41,0x41,0x7F,0x00},
    /* 94 ^     */ {0x04,0x02,0x01,0x02,0x04},
    /* 95 _     */ {0x40,0x40,0x40,0x40,0x40},
    /* 96 `     */ {0x00,0x01,0x02,0x04,0x00},
    /* 97 a     */ {0x20,0x54,0x54,0x54,0x78},
    /* 98 b     */ {0x7F,0x48,0x44,0x44,0x38},
    /* 99 c     */ {0x38,0x44,0x44,0x44,0x20},
    /*100 d     */ {0x38,0x44,0x44,0x48,0x7F},
    /*101 e     */ {0x38,0x54,0x54,0x54,0x18},
    /*102 f     */ {0x08,0x7E,0x09,0x01,0x02},
    /*103 g     */ {0x0C,0x52,0x52,0x52,0x3E},
    /*104 h     */ {0x7F,0x08,0x04,0x04,0x78},
    /*105 i     */ {0x00,0x44,0x7D,0x40,0x00},
    /*106 j     */ {0x20,0x40,0x44,0x3D,0x00},
    /*107 k     */ {0x7F,0x10,0x28,0x44,0x00},
    /*108 l     */ {0x00,0x41,0x7F,0x40,0x00},
    /*109 m     */ {0x7C,0x04,0x18,0x04,0x78},
    /*110 n     */ {0x7C,0x08,0x04,0x04,0x78},
    /*111 o     */ {0x38,0x44,0x44,0x44,0x38},
    /*112 p     */ {0x7C,0x14,0x14,0x14,0x08},
    /*113 q     */ {0x08,0x14,0x14,0x18,0x7C},
    /*114 r     */ {0x7C,0x08,0x04,0x04,0x08},
    /*115 s     */ {0x48,0x54,0x54,0x54,0x20},
    /*116 t     */ {0x04,0x3F,0x44,0x40,0x20},
    /*117 u     */ {0x3C,0x40,0x40,0x20,0x7C},
    /*118 v     */ {0x1C,0x20,0x40,0x20,0x1C},
    /*119 w     */ {0x3C,0x40,0x30,0x40,0x3C},
    /*120 x     */ {0x44,0x28,0x10,0x28,0x44},
    /*121 y     */ {0x0C,0x50,0x50,0x50,0x3C},
    /*122 z     */ {0x44,0x64,0x54,0x4C,0x44},
    /*123 {     */ {0x00,0x08,0x36,0x41,0x00},
    /*124 |     */ {0x00,0x00,0x7F,0x00,0x00},
    /*125 }     */ {0x00,0x41,0x36,0x08,0x00},
    /*126 ~     */ {0x10,0x08,0x08,0x10,0x08},
};

static void draw_char(int x, int y, char ch, uint32_t colour)
{
    if (ch < 32 || ch > 126) return;
    const uint8_t *glyph = font5x7[ch - 32];
    for (int col = 0; col < 5; col++) {
        uint8_t bits = glyph[col];
        for (int row = 0; row < 7; row++) {
            if (bits & (1 << row)) {
                int px = x + col, py = y + row;
                if ((unsigned)px < SCR_W && (unsigned)py < SCR_H)
                    *gfx_fb_ptr(px, py) = colour;
            }
        }
    }
}

static void draw_string(int x, int y, const char *s, uint32_t colour)
{
    while (*s) {
        draw_char(x, y, *s, colour);
        x += 6;
        s++;
    }
}

static void draw_number(int x, int y, int num, uint32_t colour)
{
    char buf[12];
    int i = 0;
    int neg = 0;

    if (num < 0) { neg = 1; num = -num; }
    if (num == 0) { buf[i++] = '0'; }
    else {
        while (num > 0) {
            buf[i++] = '0' + (num % 10);
            num /= 10;
        }
    }
    if (neg) buf[i++] = '-';

    /* Reverse and draw */
    for (int j = i - 1; j >= 0; j--) {
        draw_char(x, y, buf[j], colour);
        x += 6;
    }
}
