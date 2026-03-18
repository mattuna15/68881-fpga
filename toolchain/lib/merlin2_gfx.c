#include "merlin2_gfx.h"

void gfx_set_mode(int mode)
{
    register long d0 __asm__("d0") = 17;
    register long d1 __asm__("d1") = mode;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1) : : "memory");
}

void gfx_clear(uint32_t colour)
{
    register long d0 __asm__("d0") = 18;
    register long d1 __asm__("d1") = (long)colour;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1) : : "memory");
}

void gfx_set_pixel(int x, int y, uint32_t argb)
{
    register long d0 __asm__("d0") = 19;
    register long d1 __asm__("d1") = x;
    register long d2 __asm__("d2") = y;
    register long d3 __asm__("d3") = (long)argb;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1), "+d"(d2), "+d"(d3) : : "memory");
}

void gfx_screen_info(int *w, int *h)
{
    register long d0 __asm__("d0") = 21;
    register long d1 __asm__("d1");
    register long d2 __asm__("d2");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1), "=d"(d2) : : "memory");
    if (w) *w = (int)(d1 & 0xFFFF);
    if (h) *h = (int)(d2 & 0xFFFF);
}

uint32_t gfx_get_time(void)
{
    register long d0 __asm__("d0") = 8;
    register long d1 __asm__("d1");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1) : : "memory");
    return (uint32_t)d1;
}

int gfx_char_ready(void)
{
    register long d0 __asm__("d0") = 7;
    register long d1 __asm__("d1");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1) : : "memory");
    return (int)(d1 & 1);
}
