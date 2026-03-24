#ifndef MERLIN2_MOUSE_H
#define MERLIN2_MOUSE_H

#include <stdint.h>

typedef struct {
    uint8_t  buttons;   /* bit 0=left, bit 1=right, bit 2=middle */
    int16_t  dx;        /* X delta since last call (cleared on read) */
    int16_t  dy;        /* Y delta since last call (cleared on read) */
} mouse_event_t;

/* TRAP #15 D0=26: read buttons + delta (clears deltas) */
void mouse_get(mouse_event_t *evt);

/* TRAP #15 D0=27: read absolute position */
void mouse_get_pos(int *x, int *y);

/* TRAP #15 D0=28: set absolute position */
void mouse_set_pos(int x, int y);

/* Convenience: is button pressed? */
#define MOUSE_BTN_LEFT   1
#define MOUSE_BTN_RIGHT  2
#define MOUSE_BTN_MIDDLE 4

#endif /* MERLIN2_MOUSE_H */
