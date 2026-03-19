#include <stdio.h>
#include "../lib/merlin2_gfx.h"
#include "../lib/merlin2_rtc.h"

static const char *weekday_names[] = {
    "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
};

int main(void)
{
    rtc_datetime_t dt;
    uint32_t secs, ticks, last_ticks;

    printf("RTC test - press any key to exit\n\n");

    /* Show current RTC value */
    secs = rtc_get_time();
    printf("Unix timestamp: %lu\n", (unsigned long)secs);

    if (secs == 0) {
        printf("RTC not set - setting to 2026-03-19 12:00:00\n");
        /* 2026-03-19 12:00:00 UTC = 1774051200 */
        rtc_set_time(1774051200UL);
        secs = rtc_get_time();
        printf("Unix timestamp: %lu\n", (unsigned long)secs);
    }

    /* Show broken-out datetime */
    rtc_get_datetime(&dt);
    printf("Date: %04u-%02u-%02u (%s)\n",
           dt.year, dt.month, dt.day,
           dt.weekday < 7 ? weekday_names[dt.weekday] : "???");
    printf("Time: %02u:%02u:%02u\n\n", dt.hour, dt.min, dt.sec);

    /* Show tick counter incrementing */
    printf("Timer C ticks (press any key to stop):\n");
    last_ticks = rtc_get_ticks();
    while (!gfx_char_ready()) {
        ticks = rtc_get_ticks();
        if (ticks != last_ticks) {
            printf("\r  ticks: %lu  ", (unsigned long)ticks);
            last_ticks = ticks;
        }
    }

    printf("\nDone.\n");
    return 0;
}
