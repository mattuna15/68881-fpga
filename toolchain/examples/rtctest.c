#include <stdio.h>
#include "../lib/merlin2_gfx.h"
#include "../lib/merlin2_rtc.h"

static const char *weekday_names[] = {
    "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
};

static void print_datetime(void)
{
    rtc_datetime_t dt;
    rtc_get_datetime(&dt);
    printf("%04u-%02u-%02u %02u:%02u:%02u (%s)\n",
           dt.year, dt.month, dt.day,
           dt.hour, dt.min, dt.sec,
           dt.weekday < 7 ? weekday_names[dt.weekday] : "???");
}

/* Days in each month (non-leap) */
static const uint16_t mdays[] = {31,28,31,30,31,30,31,31,30,31,30,31};

static int is_leap(int y)
{
    return (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0));
}

/* Convert date/time to Unix timestamp */
static uint32_t datetime_to_epoch(int year, int month, int day,
                                   int hour, int min, int sec)
{
    uint32_t days = 0;
    int y;
    for (y = 1970; y < year; y++)
        days += is_leap(y) ? 366 : 365;
    int m;
    for (m = 1; m < month; m++) {
        days += mdays[m - 1];
        if (m == 2 && is_leap(year))
            days++;
    }
    days += (uint32_t)(day - 1);
    return days * 86400 + (uint32_t)hour * 3600 + (uint32_t)min * 60 + (uint32_t)sec;
}

/* Read a decimal number from serial input, terminated by the delimiter char.
 * Returns the number, stores the terminating char in *term. */
static int read_num(char term)
{
    int val = 0;
    int ch;
    while (1) {
        ch = getchar();
        if (ch == term || ch == '\r' || ch == '\n')
            break;
        if (ch >= '0' && ch <= '9') {
            val = val * 10 + (ch - '0');
            putchar(ch);
        }
    }
    return val;
}

int main(void)
{
    printf("RTC test\n\n");

    /* Show current RTC */
    printf("Current RTC: ");
    print_datetime();
    printf("Unix timestamp: %lu\n\n", (unsigned long)rtc_get_time());

    /* Prompt to set time */
    printf("Set date/time? (y/n): ");
    int ch = getchar();
    putchar(ch);
    printf("\n");

    if (ch == 'y' || ch == 'Y') {
        int year, month, day, hour, min, sec;

        printf("Enter date/time as: YYYY-MM-DD HH:MM:SS\n");
        printf("Date (YYYY-MM-DD): ");
        year  = read_num('-'); putchar('-');
        month = read_num('-'); putchar('-');
        day   = read_num('\r'); printf("\n");

        printf("Time (HH:MM:SS): ");
        hour = read_num(':'); putchar(':');
        min  = read_num(':'); putchar(':');
        sec  = read_num('\r'); printf("\n");

        uint32_t epoch = datetime_to_epoch(year, month, day, hour, min, sec);
        printf("Setting RTC to %lu...\n", (unsigned long)epoch);
        rtc_set_time(epoch);

        printf("RTC set: ");
        print_datetime();
        printf("\n");
    }

    /* Show tick counter */
    printf("Timer C ticks (press any key to stop):\n");
    uint32_t last = rtc_get_ticks();
    while (!gfx_char_ready()) {
        uint32_t now = rtc_get_ticks();
        if (now != last) {
            printf("\r  ticks: %lu  ", (unsigned long)now);
            last = now;
        }
    }

    printf("\nDone.\n");
    return 0;
}
