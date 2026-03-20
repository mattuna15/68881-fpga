/*
 * merlin2_mouse.c -- TRAP #15 mouse wrappers for the Merlin 2 BIOS.
 */

#include "merlin2_mouse.h"

#define TRAP_GET_MOUSE      26
#define TRAP_GET_MOUSE_POS  27
#define TRAP_SET_MOUSE_POS  28

void mouse_get(mouse_event_t *evt)
{
    register long d0 __asm__("d0") = TRAP_GET_MOUSE;
    register long d1 __asm__("d1");
    register long d2 __asm__("d2");
    register long d3 __asm__("d3");
    __asm__ volatile("trap #15"
        : "+d"(d0), "=d"(d1), "=d"(d2), "=d"(d3)
        : : "a0", "a1", "memory", "cc");
    if (evt) {
        evt->buttons = (uint8_t)(d1 & 0xFF);
        evt->dx = (int16_t)(d2 & 0xFFFF);
        evt->dy = (int16_t)(d3 & 0xFFFF);
    }
}

void mouse_get_pos(int *x, int *y)
{
    register long d0 __asm__("d0") = TRAP_GET_MOUSE_POS;
    register long d1 __asm__("d1");
    register long d2 __asm__("d2");
    __asm__ volatile("trap #15"
        : "+d"(d0), "=d"(d1), "=d"(d2)
        : : "a0", "a1", "memory", "cc");
    if (x) *x = (int)(d1 & 0xFFFF);
    if (y) *y = (int)(d2 & 0xFFFF);
}

void mouse_set_pos(int x, int y)
{
    register long d0 __asm__("d0") = TRAP_SET_MOUSE_POS;
    register long d1 __asm__("d1") = x;
    register long d2 __asm__("d2") = y;
    __asm__ volatile("trap #15"
        : "+d"(d0), "+d"(d1), "+d"(d2)
        : : "a0", "a1", "memory", "cc");
}
