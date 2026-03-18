/*
 * merlin2_gfx.c -- TRAP #15 graphics wrappers for the Merlin 2 BIOS.
 *
 * Each function loads a function number into D0.B and parameters into
 * D1/D2/D3, then executes TRAP #15.  Results are returned in D1/D2.
 * See merlin2.h for the full dispatch table.
 */

#include "merlin2_gfx.h"

/* TRAP #15 function numbers (from merlin2.h / bios.s dispatch table) */
#define TRAP_CHAR_READY     7
#define TRAP_GET_TIME       8
#define TRAP_SET_MODE      17
#define TRAP_CLEAR_FB      18
#define TRAP_SET_PIXEL     19
#define TRAP_SCREEN_INFO   21

void gfx_set_mode(int mode)
{
    register long d0 __asm__("d0") = TRAP_SET_MODE;
    register long d1 __asm__("d1") = mode;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1) : : "a0", "a1", "memory", "cc");
}

void gfx_clear(uint32_t colour)
{
    register long d0 __asm__("d0") = TRAP_CLEAR_FB;
    register long d1 __asm__("d1") = (long)colour;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1) : : "a0", "a1", "memory", "cc");
}

void gfx_set_pixel(int x, int y, uint32_t argb)
{
    register long d0 __asm__("d0") = TRAP_SET_PIXEL;
    register long d1 __asm__("d1") = x;
    register long d2 __asm__("d2") = y;
    register long d3 __asm__("d3") = (long)argb;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1), "+d"(d2), "+d"(d3) : : "a0", "a1", "memory", "cc");
}

void gfx_screen_info(int *w, int *h)
{
    register long d0 __asm__("d0") = TRAP_SCREEN_INFO;
    register long d1 __asm__("d1");
    register long d2 __asm__("d2");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1), "=d"(d2) : : "a0", "a1", "memory", "cc");
    if (w) *w = (int)(d1 & 0xFFFF);
    if (h) *h = (int)(d2 & 0xFFFF);
}

uint32_t gfx_get_time(void)
{
    register long d0 __asm__("d0") = TRAP_GET_TIME;
    register long d1 __asm__("d1");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1) : : "a0", "a1", "memory", "cc");
    return (uint32_t)d1;
}

int gfx_char_ready(void)
{
    register long d0 __asm__("d0") = TRAP_CHAR_READY;
    register long d1 __asm__("d1");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1) : : "a0", "a1", "memory", "cc");
    return (int)(d1 & 1);
}
