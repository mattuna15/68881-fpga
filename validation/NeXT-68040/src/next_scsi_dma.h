/*
 * next_scsi_dma.h
 * DMA data registers and transfer engine for SCSI channel.
 * Adapted from Previous emulator (previous/src/dma.c).
 */

#ifndef NEXT_SCSI_DMA_H
#define NEXT_SCSI_DMA_H

#include <stdint.h>

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

#endif /* NEXT_SCSI_DMA_H */
