#include <stdio.h>
#include <string.h>
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
    return days * 86400u + (uint32_t)hour * 3600u + (uint32_t)min * 60u + (uint32_t)sec;
}

/* Read a line using BIOS TRAP #15 D0=2 (readline with echo + editing).
 * Returns pointer to null-terminated string in a static buffer. */
static char line_buf[82];

static char *bios_readline(void)
{
    register long d0 __asm__("d0") = 2;
    register long a1 __asm__("a1") = (long)line_buf;
    __asm__ volatile("trap #15" : "+d"(d0), "+r"(a1) : : "d1", "a0", "memory", "cc");
    return line_buf;
}

/* Read a single char using BIOS TRAP #15 D0=5 */
static int bios_getchar(void)
{
    register long d0 __asm__("d0") = 5;
    register long d1 __asm__("d1");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1) : : "a0", "a1", "memory", "cc");
    return (int)(d1 & 0xFF);
}

/* Parse "YYYY-MM-DD" from string, returns number of chars consumed */
static int parse_date(const char *s, int *year, int *month, int *day)
{
    int n = 0;
    *year = *month = *day = 0;
    /* YYYY */
    while (s[n] >= '0' && s[n] <= '9') { *year = *year * 10 + (s[n] - '0'); n++; }
    if (s[n] == '-') n++;
    /* MM */
    while (s[n] >= '0' && s[n] <= '9') { *month = *month * 10 + (s[n] - '0'); n++; }
    if (s[n] == '-') n++;
    /* DD */
    while (s[n] >= '0' && s[n] <= '9') { *day = *day * 10 + (s[n] - '0'); n++; }
    return n;
}

/* Parse "HH:MM:SS" from string */
static int parse_time(const char *s, int *hour, int *min, int *sec)
{
    int n = 0;
    *hour = *min = *sec = 0;
    while (s[n] >= '0' && s[n] <= '9') { *hour = *hour * 10 + (s[n] - '0'); n++; }
    if (s[n] == ':') n++;
    while (s[n] >= '0' && s[n] <= '9') { *min = *min * 10 + (s[n] - '0'); n++; }
    if (s[n] == ':') n++;
    while (s[n] >= '0' && s[n] <= '9') { *sec = *sec * 10 + (s[n] - '0'); n++; }
    return n;
}

int main(void)
{
    /* Disable stdout buffering so prompts appear immediately,
     * and ensure clean state on re-run without reload */
    setvbuf(stdout, NULL, _IONBF, 0);

    /* Drain any pending keypress from previous run */
    while (gfx_char_ready())
        bios_getchar();

    printf("RTC test\n\n");

    printf("Current RTC: ");
    print_datetime();
    printf("Unix timestamp: %lu\n\n", (unsigned long)rtc_get_time());

    printf("Set date/time? (y/n): ");
    int ch = bios_getchar();
    printf("\n");

    if (ch == 'y' || ch == 'Y') {
        int year, month, day, hour, min, sec;
        char *line;

        printf("Date (YYYY-MM-DD): ");
        line = bios_readline();
        parse_date(line, &year, &month, &day);
        printf("\n");

        printf("Time (HH:MM:SS): ");
        line = bios_readline();
        parse_time(line, &hour, &min, &sec);
        printf("\n");

        printf("Parsed: %04d-%02d-%02d %02d:%02d:%02d\n",
               year, month, day, hour, min, sec);

        uint32_t epoch = datetime_to_epoch(year, month, day, hour, min, sec);
        printf("Unix epoch: %lu\n", (unsigned long)epoch);
        printf("Setting RTC...\n");
        rtc_set_time(epoch);

        printf("RTC now: ");
        print_datetime();
        printf("\n");
    }

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
