/*
 * next_esp.h
 * NCR53C90 (ESP) SCSI controller emulation.
 * Adapted from Previous emulator (previous/src/esp.c).
 */

#ifndef NEXT_ESP_H
#define NEXT_ESP_H

#include <stdint.h>

void next_esp_init(void);

/* Byte-wide register access at P_SCSI (0x02014000 - 0x0201400F) */
uint8_t next_esp_read(uint32_t offset);    /* offset 0x00-0x0F */
void    next_esp_write(uint32_t offset, uint8_t value);

/* ESP DMA control/status at 0x02014020-0x02014021 */
uint8_t next_esp_dma_ctrl_read(void);
void    next_esp_dma_ctrl_write(uint8_t value);
uint8_t next_esp_dma_status_read(void);
void    next_esp_dma_status_write(uint8_t value);

/* Debug: dump last ESP IRQ events */
void esp_dump_irq_log(void);

#endif /* NEXT_ESP_H */
