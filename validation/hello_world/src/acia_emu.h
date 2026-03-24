/*
 * acia_emu.h
 * MC6850 ACIA + IKBD emulation for Atari ST compatibility.
 *
 * Two ACIAs at $FFFC00 (keyboard) and $FFFC04 (MIDI stub).
 * The keyboard ACIA connects to an IKBD command parser that
 * handles scancode/mouse packet I/O through a 64-byte RX FIFO.
 */

#ifndef ACIA_EMU_H
#define ACIA_EMU_H

#include <stdint.h>

/* ACIA address range: $FFFC00-$FFFC07 */
#define ACIA_BASE   0xFFFC00
#define ACIA_SIZE   0x08

/* Initialise ACIA state (FIFOs, control registers, IKBD state) */
void acia_init(void);

/* Read a byte from an ACIA register.
 * addr = absolute address ($FFFC00-$FFFC07) */
uint8_t acia_read(uint32_t addr);

/* Write a byte to an ACIA register.
 * addr = absolute address ($FFFC00-$FFFC07) */
void acia_write(uint32_t addr, uint8_t val);

/* Check if keyboard ACIA has a pending IRQ (RDRF && RX IRQ enabled) */
int acia_has_irq(void);

/* Push an IKBD byte into the keyboard ACIA RX FIFO.
 * Returns 0 on success, -1 if buffer full. */
int acia_rx_push(uint8_t byte);

/* Check if IKBD mouse reporting is enabled */
int ikbd_mouse_enabled(void);

/* Check if ACIA/IKBD mode is active (has been initialised) */
int acia_mode_active(void);

#endif /* ACIA_EMU_H */
