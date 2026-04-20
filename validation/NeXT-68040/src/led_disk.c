/*
 * led_disk.c
 * Drives the AXU3EG user LED via the AXI GPIO instance at 0x80020000
 * (pl_led, 1-bit output, already configured as output in the bitstream).
 *
 * Behaviour: sticky "on" for a short hold window after each disk access
 * so short bursts stay visible.  Concurrent accesses just keep the LED on.
 */

#include "led_disk.h"
#include "xil_io.h"

#define PL_LED_BASE      0x80020000u
#define PL_LED_DATA_OFF  0x00u       /* GPIO_DATA register */
#define PL_LED_TRI_OFF   0x04u       /* GPIO_TRI  register (0 = output) */

/* Activity counter in instruction ticks.  On every emu_instr_hook tick
 * led_disk_tick() decrements; while >0 the LED is lit.  One activity
 * ping reloads to LED_HOLD_TICKS.  Tune for a comfortable visual hold:
 * at ~10 MIPS emulated a 500k-tick hold is ~50 ms - long enough that
 * short bursts stay visible, short enough that sustained activity just
 * looks bright instead of glued on. */
#define LED_HOLD_TICKS   500000u

static volatile uint32_t led_hold = 0;
static int led_state = -1;    /* -1 = unknown, force a write on first tick */

static inline void led_write(int on)
{
    Xil_Out32(PL_LED_BASE + PL_LED_DATA_OFF, on ? 1u : 0u);
    led_state = on ? 1 : 0;
}

void led_disk_init(void)
{
    /* Ensure the pin is driven as output (bit 0 of TRI = 0). */
    Xil_Out32(PL_LED_BASE + PL_LED_TRI_OFF, 0u);
    led_write(0);
    led_hold = 0;
}

void led_disk_note_activity(void)
{
    led_hold = LED_HOLD_TICKS;
    if (led_state != 1)
        led_write(1);
}

void led_disk_tick(void)
{
    if (led_hold == 0) {
        if (led_state != 0) led_write(0);
        return;
    }
    led_hold--;
    if (led_hold == 0 && led_state != 0)
        led_write(0);
}
