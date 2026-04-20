/*
 * led_disk.h
 * Disk-activity indicator on the AXU3EG user LED (PL pin AE12 routed
 * through the bitstream's AXI GPIO instance `pl_led` at 0x80020000).
 *
 * Usage:
 *   - call led_disk_init() once at startup.
 *   - call led_disk_note_activity() from every SCSI/eMMC read/write path.
 *   - call led_disk_tick() regularly (e.g. from emu_instr_hook every N
 *     instructions, or from the main loop) so the LED turns back off
 *     after the hold window elapses.
 */

#ifndef LED_DISK_H
#define LED_DISK_H

void led_disk_init(void);
void led_disk_note_activity(void);
void led_disk_tick(void);

#endif /* LED_DISK_H */
