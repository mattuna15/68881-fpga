/*
 * mfp_emu.h
 * MC68901 MFP (Multi-Function Peripheral) emulation.
 *
 * Minimal emulation of the MFP USART + GPIO — just enough to support
 * the BIOS ROM's character I/O via outChar/inChar polling loops.
 * Writes to MFPUDR are redirected to the text framebuffer.
 * Reads from MFPUDR dequeue from a UART RX circular buffer.
 */

#ifndef MFP_EMU_H
#define MFP_EMU_H

#include <stdint.h>

/* MC68901 MFP base address and register span (as expected by bios.s) */
#define MFP_BASE        0xFD0000
#define MFP_SIZE        0x34        /* registers 0x01..0x2F + tick counter 0x30..0x33 */
#define MFP_END         (MFP_BASE + MFP_SIZE)

/* ROM region */
#define ROM_BASE        0xFE0000
#define ROM_SIZE        0x020000    /* 128 KB */
#define ROM_END         (ROM_BASE + ROM_SIZE)

/* MFP register offsets (odd-addressed, as per MC68901 convention) */
#define MFP_OFF_GPDR    0x01    /* GPIO Data Register */
#define MFP_OFF_AER     0x03    /* Active Edge Register */
#define MFP_OFF_DDR     0x05    /* Data Direction Register */
#define MFP_OFF_IERA    0x07    /* Interrupt Enable Register A */
#define MFP_OFF_IERB    0x09    /* Interrupt Enable Register B */
#define MFP_OFF_IPRA    0x0B    /* Interrupt Pending Register A */
#define MFP_OFF_IPRB    0x0D    /* Interrupt Pending Register B */
#define MFP_OFF_ISRA    0x0F    /* Interrupt In-Service Register A */
#define MFP_OFF_ISRB    0x11    /* Interrupt In-Service Register B */
#define MFP_OFF_IMRA    0x13    /* Interrupt Mask Register A */
#define MFP_OFF_IMRB    0x15    /* Interrupt Mask Register B */
#define MFP_OFF_VR      0x17    /* Vector Register */
#define MFP_OFF_TACR    0x19    /* Timer A Control Register */
#define MFP_OFF_TBCR    0x1B    /* Timer B Control Register */
#define MFP_OFF_TCDCR   0x1D    /* Timer C/D Control Register */
#define MFP_OFF_TADR    0x1F    /* Timer A Data Register */
#define MFP_OFF_TBDR    0x21    /* Timer B Data Register */
#define MFP_OFF_TCDR    0x23    /* Timer C Data Register */
#define MFP_OFF_TDDR    0x25    /* Timer D Data Register */
#define MFP_OFF_SCR     0x27    /* Sync Character Register */
#define MFP_OFF_UCR     0x29    /* USART Control Register */
#define MFP_OFF_RSR     0x2B    /* Receiver Status Register */
#define MFP_OFF_TSR     0x2D    /* Transmitter Status Register */
#define MFP_OFF_UDR     0x2F    /* USART Data Register */

/* Extension: 32-bit millisecond tick counter (read-only, big-endian) */
#define MFP_OFF_TICK    0x30    /* 4 bytes: ms since mfp_init() */

/* Initialize MFP emulation state */
void mfp_init(void);

/* Read a byte from an MFP register.
 * offset = address - MFP_BASE (0x00..0x2F) */
uint8_t mfp_read(uint32_t offset);

/* Write a byte to an MFP register.
 * offset = address - MFP_BASE (0x00..0x2F) */
void mfp_write(uint32_t offset, uint8_t value);

/* Push a character into the MFP UART RX buffer (from ARM UART).
 * Returns 0 on success, -1 if buffer full. */
int mfp_rx_push(uint8_t ch);

/* Check if RX buffer has data */
int mfp_rx_has_data(void);

#endif /* MFP_EMU_H */
