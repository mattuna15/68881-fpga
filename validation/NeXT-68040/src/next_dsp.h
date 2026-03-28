/*
 * next_dsp.h
 * Motorola DSP56001 host interface register emulation.
 *
 * The NeXT uses a DSP56001 for audio processing.  The host CPU accesses
 * it via memory-mapped registers at P_DSP (SLOT_ID_BMAP + 0x02008000):
 *
 *   Offset 0: ICR — Interface Control Register  (R/W)
 *   Offset 1: CVR — Command Vector Register     (R/W)
 *   Offset 2: ISR — Interface Status Register    (R/O)
 *   Offset 3: IVR — Interrupt Vector Register    (R/W)
 *   Offset 4-7: Data register (TX/RX, 24-bit)
 *
 * Backend:
 *   QEMU_MODE  — software stub (no real DSP)
 *   Hardware   — could map to a real DSP or be stubbed if no DSP present
 *
 * The ROM probes the DSP during boot and waits for ISR.HF2 (bit 3).
 * A minimal stub that keeps ISR_TRDY and ISR_TXDE set (TX ready/empty)
 * and responds to ICR_INIT with ISR_HF2 is enough for boot.
 */

#ifndef NEXT_DSP_H
#define NEXT_DSP_H

#include <stdint.h>

void     next_dsp_init(void);

/* Byte-level I/O for the DSP register block (8 bytes at P_DSP) */
uint8_t  next_dsp_read(uint32_t offset);   /* offset 0-7 within DSP block */
void     next_dsp_write(uint32_t offset, uint8_t value);

/* 32-bit I/O for the data register (offset 4) */
uint32_t next_dsp_read32(uint32_t offset);
void     next_dsp_write32(uint32_t offset, uint32_t value);

#endif /* NEXT_DSP_H */
