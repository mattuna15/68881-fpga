/*
 * render_core1.h
 * Display rendering on Cortex-A53 core 1.
 */

#ifndef RENDER_CORE1_H
#define RENDER_CORE1_H

#include <stdint.h>

/* Start core 1 render loop. Call once from main() after display init.
 * pixel_buf: the ARGB8888 pixel buffer
 * dp_ok: 1 if DisplayPort is initialized */
void render_core1_start(uint32_t *pixel_buf, int dp_ok);

/* Request a render. mode: 0 = text_fb, 1 = next_vram.
 * Non-blocking — sends event to core 1. */
void render_core1_request(int mode);

/* Returns 1 if core 1 is running */
int render_core1_is_active(void);

#endif /* RENDER_CORE1_H */
