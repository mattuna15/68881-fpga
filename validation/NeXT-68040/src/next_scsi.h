/*
 * next_scsi.h
 * SCSI disk emulation backed by disk image file on SD card.
 * Adapted from Previous emulator (previous/src/scsi.c).
 */

#ifndef NEXT_SCSI_H
#define NEXT_SCSI_H

#include <stdint.h>
#include <stdbool.h>

/* SCSI bus phases */
#define SCSI_PHASE_DO   0x00    /* Data Out (host → target) */
#define SCSI_PHASE_DI   0x01    /* Data In  (target → host) */
#define SCSI_PHASE_CD   0x02    /* Command */
#define SCSI_PHASE_ST   0x03    /* Status */
#define SCSI_PHASE_MO   0x06    /* Message Out */
#define SCSI_PHASE_MI   0x07    /* Message In */

#define SCSI_BLOCKSIZE  512

/* Initialise SCSI subsystem — mount SD card, open disk image.
 * Returns 0 on success, -1 if no disk image found. */
int  next_scsi_init(void);

/* Target selection — returns true if timeout (no disk at target). */
bool next_scsi_select(uint8_t target);

/* Receive command CDB + identify message and execute it. */
void next_scsi_receive_command(uint8_t *cdb, int cdb_len, uint8_t identify);

/* Single-byte data transfer (for PIO mode). */
uint8_t next_scsi_send_data(void);
void    next_scsi_receive_data(uint8_t val);

/* Status/message retrieval. */
uint8_t next_scsi_send_status(void);
uint8_t next_scsi_send_message(void);

/* Current bus phase and target. */
uint8_t next_scsi_get_phase(void);
void    next_scsi_set_phase(uint8_t phase);
uint8_t next_scsi_get_target(void);

/* Direct buffer access for DMA transfers. */
uint8_t *next_scsi_get_buffer_ptr(void);   /* pointer into current position */
int      next_scsi_get_buffer_remaining(void);
void     next_scsi_consume_bytes(int n);   /* advance buffer by n bytes */

/* Direct raw read from disk image (512-byte sectors). */
int      next_scsi_read_raw(uint32_t lba, uint8_t *buf, uint32_t nsect);

/* Reset SCSI read log counter (call after kernel bus reset). */
void     next_scsi_reset_read_log(void);

#endif /* NEXT_SCSI_H */
