/*
 * next_kms.h
 * NeXT KMS (Keyboard/Mouse/Sound) monitor chip emulation.
 *
 * The ROM monitor polls P_MON ($0200E000) for keyboard input:
 *   $0200E000: mon_csr  — bit 22 (KM_DAV) = keyboard data available
 *   $0200E008: mon_km_data — keyboard event (union kybd_event)
 *
 * Keyboard event format (from nextdev/kmreg.h):
 *   bits 31-16: 0 (device address = 0 for keyboard)
 *   bit 15:     valid = 1
 *   bits 14-8:  modifier flags
 *   bit 8:      up_down (0=KM_DOWN, 1=KM_UP)
 *   bits 7-1:   key_code (7-bit NeXT scan code)
 *   bit 0:      LSB of key_code
 *
 * Key codes are NeXT-specific (from nextdev/keycodes.h ascii[] table).
 */

#ifndef NEXT_KMS_H
#define NEXT_KMS_H

#include <stdint.h>

/* Initialise KMS subsystem */
void next_kms_init(void);

/* Push an ASCII character as a keyboard event.
 * Converts ASCII to NeXT key_code via reverse lookup of the ascii[] table,
 * builds a kybd_event, and queues it for the ROM to read. */
void next_kms_push_ascii(uint8_t ch);

/* Push a raw 8-byte HID boot-protocol keyboard report.
 *   report[0] = modifier bitmap
 *   report[1] = 0 (reserved)
 *   report[2..7] = up to 6 HID Usage IDs of currently-pressed keys
 * The function diffs against the previous report, translates HID Usage IDs
 * into NeXT 7-bit key_codes via the internal hid_to_next[] table, and
 * queues key-down / key-up events (with NeXT modifier bits) into the same
 * 16-slot queue used by next_kms_push_ascii().  Used by the USB HID driver
 * to deliver full-fidelity keyboard input (arrows, modifiers, command/alt)
 * that the ASCII path cannot represent. */
void next_kms_push_hid_report(const uint8_t report[8]);

/* Push a mouse motion / button event.
 *   dx, dy  = signed 8-bit displacement (HID format; saturated to NeXT's
 *             7-bit signed range inside this function)
 *   buttons = HID boot-protocol button bitmap:
 *               bit 0 = left, bit 1 = right, bit 2 = middle
 * Builds a mouse-format KMS event (see NeXTMach nextdev/kmreg.h struct
 * mouse) and queues it alongside keyboard events. */
void next_kms_push_mouse(int8_t dx, int8_t dy, uint8_t buttons);

/* Read KMS registers (called from next_devs I/O handlers).
 * offset: 0=mon_csr, 4=mon_data, 8=mon_km_data, 12=mon_sound_data */
uint32_t next_kms_read(int offset);

/* Write KMS registers (accept ROM commands silently) */
void next_kms_write(int offset, uint32_t value);

/* Force a "no response" reply into the km_data register.  Called when
 * the CPU is spinning on a KMS poll without having sent a command
 * (e.g. post-reset self-test that real hardware auto-posts). */
void next_kms_force_response(void);

#endif /* NEXT_KMS_H */
