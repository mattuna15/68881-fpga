/*
 * dp_video.h
 * PS DisplayPort TX + DPDMA output driver.
 *
 * Initialises the ZynqMP PS-side DisplayPort transmitter and DMA engine
 * to output a 1280x720@60Hz ARGB8888 frame from a DDR pixel buffer.
 * No PL fabric IP required — entirely PS-side.
 */

#ifndef DP_VIDEO_H
#define DP_VIDEO_H

#include <stdint.h>

/* Initialize the DisplayPort TX subsystem (DP controller, AVBuf, DPDMA).
 * pixel_buf: pointer to the ARGB8888 pixel buffer in DDR.
 * Returns 0 on success, non-zero on failure. */
int dp_video_init(uint32_t *pixel_buf);

/* Re-point DPDMA to a new pixel buffer address (e.g. for double-buffering) */
void dp_video_set_buffer(uint32_t *pixel_buf);

/* Trigger a single DPDMA refresh (if not in continuous mode) */
void dp_video_refresh(void);

#endif /* DP_VIDEO_H */
