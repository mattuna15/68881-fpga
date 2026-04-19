/*
 * usb_hid.h
 * USB HID keyboard and mouse driver for ZynqMP DWC3 in host mode.
 *
 * Drives the DWC3 controller at 0xFE200000 into xHCI host mode,
 * enumerates through USB hubs, and delivers boot-protocol reports to
 * the emulated NeXT KMS:
 *  - HID boot-protocol keyboard report (8 bytes) -> next_kms_push_hid_report()
 *  - HID boot-protocol mouse report          -> next_kms_push_mouse()
 *
 * Forked from the EmuTOS variant at validation/hello_world/src/usb_hid.[ch].
 * The MFP/ACIA/IKBD sinks used by EmuTOS are removed; the xHCI and hub
 * enumeration code paths are unchanged.
 */

#ifndef USB_HID_H
#define USB_HID_H

#include <stdint.h>

/* Mouse state (updated by usb_hid_poll) */
typedef struct {
    uint8_t     buttons;    /* bit 0=left, bit 1=right, bit 2=middle */
    int16_t     dx;         /* accumulated X delta since last clear */
    int16_t     dy;         /* accumulated Y delta since last clear */
    uint16_t    abs_x;      /* absolute X position (0..1279) */
    uint16_t    abs_y;      /* absolute Y position (0..719) */
} usb_mouse_state_t;

/*
 * Initialise DWC3 in host mode, enumerate USB devices.
 * Finds keyboard and/or mouse (through up to 3 hub levels).
 * Returns 0 if at least a keyboard was found, -1 on failure.
 * Safe to call with no devices plugged in (3s timeout).
 */
int usb_hid_init(void);

/*
 * Poll for HID reports. Non-blocking.
 * Keyboard events -> next_kms_push_hid_report(raw 8-byte boot report).
 * Mouse events    -> next_kms_push_mouse(dx, dy, buttons).
 * Call from the main emulation loop.
 */
void usb_hid_poll(void);

/*
 * Get current mouse state (buttons, deltas, absolute position).
 * Returns pointer to internal state - valid until next usb_hid_poll().
 */
const usb_mouse_state_t *usb_mouse_state(void);

/*
 * Clear accumulated mouse deltas (call after reading them).
 */
void usb_mouse_clear_deltas(void);

#endif /* USB_HID_H */
