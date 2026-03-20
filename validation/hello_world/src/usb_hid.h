/*
 * usb_hid.h
 * Minimal USB HID keyboard driver for ZynqMP DWC3 in host mode.
 *
 * Drives the DWC3 controller at 0xFE200000 into xHCI host mode,
 * enumerates a single USB keyboard, and feeds ASCII keypresses
 * into the MFP RX buffer via mfp_rx_push().
 */

#ifndef USB_HID_H
#define USB_HID_H

#include <stdint.h>

/*
 * Initialise the DWC3 controller in host mode and attempt to
 * enumerate a USB HID keyboard.
 *
 * Returns 0 on success (keyboard found and configured),
 *        -1 on error (no device, not a keyboard, HW failure).
 *
 * Safe to call even if no device is plugged in — will timeout
 * gracefully and return -1.
 */
int usb_hid_init(void);

/*
 * Poll for new HID keyboard reports.  If a key event is pending,
 * translates it to ASCII and pushes into mfp_rx_push().
 *
 * Should be called from the main emulation loop after poll_uart_rx().
 * Non-blocking — returns immediately if no new data.
 */
void usb_hid_poll(void);

#endif /* USB_HID_H */
