/*
 * next_scsi_dma.h
 * DMA data registers and transfer engine for SCSI channel.
 * Adapted from Previous emulator (previous/src/dma.c).
 */

#ifndef NEXT_SCSI_DMA_H
#define NEXT_SCSI_DMA_H

#include <stdint.h>
#include "next_debug.h"

void next_scsi_dma_init(void);

/* DMA data register access (0x02004010-0x0200401F) */
uint32_t next_scsi_dma_reg_read(uint32_t addr);
void     next_scsi_dma_reg_write(uint32_t addr, uint32_t value);

/* Execute DMA transfer between SCSI buffer and 68K memory.
 * direction: 0 = mem→SCSI (write), non-zero = SCSI→mem (read)
 * esp_counter: transfer byte count (decremented in place)
 * Returns total bytes transferred. */
int next_scsi_dma_transfer(int direction, uint32_t *esp_counter);

/* DMA CSR management for SCSI channel */
void     next_scsi_dma_csr_write(uint32_t value);
uint32_t next_scsi_dma_csr_read(void);

/* Start a deferred DMA transfer (called from ESP TI+DMA command).
 * The transfer completes after a few instruction ticks via next_scsi_dma_tick. */
void next_scsi_dma_start_deferred(int direction, uint32_t esp_counter);

/* Deferred DMA completion — called from instruction hook.
 * Returns 1 if a deferred transfer completed this tick, 0 otherwise. */
int next_scsi_dma_tick(void);

#if NEXT_DEBUG_DMA
/* Diagnostics: internal state snapshots for IRQ-set instrumentation. */
uint32_t next_scsi_dma_get_csr(void);
int      next_scsi_dma_get_pending(void);
int      next_scsi_dma_get_countdown(void);

/* Dump the recent CSR-write ring buffer. */
void     next_scsi_dma_dump_write_ring(void);
#endif

#endif /* NEXT_SCSI_DMA_H */
