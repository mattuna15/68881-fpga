#ifndef MERLIN2_RTC_H
#define MERLIN2_RTC_H

#include <stdint.h>

typedef struct {
    uint16_t year;
    uint8_t month, day, hour, min, sec, weekday;
} rtc_datetime_t;

/* TRAP #15 D0=22: get Unix timestamp (seconds since 1970-01-01) */
uint32_t rtc_get_time(void);

/* TRAP #15 D0=23: get BCD datetime, unpacked into struct */
void rtc_get_datetime(rtc_datetime_t *dt);

/* TRAP #15 D0=24: set Unix timestamp */
void rtc_set_time(uint32_t unix_secs);

/* TRAP #15 D0=25: get Timer C tick counter (~38 Hz) */
uint32_t rtc_get_ticks(void);

#endif /* MERLIN2_RTC_H */
