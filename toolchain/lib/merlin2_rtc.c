/*
 * merlin2_rtc.c -- TRAP #15 wrappers for RTC and Timer C tick counter.
 *
 * See merlin2.h for the TRAP dispatch table.
 */

#include "merlin2_rtc.h"

#define TRAP_GET_RTC       22
#define TRAP_GET_DATETIME  23
#define TRAP_SET_RTC       24
#define TRAP_GET_TICKS     25

uint32_t rtc_get_time(void)
{
    register long d0 __asm__("d0") = TRAP_GET_RTC;
    register long d1 __asm__("d1");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1) : : "a0", "a1", "memory", "cc");
    return (uint32_t)d1;
}

void rtc_get_datetime(rtc_datetime_t *dt)
{
    register long d0 __asm__("d0") = TRAP_GET_DATETIME;
    register long d1 __asm__("d1");
    register long d2 __asm__("d2");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1), "=d"(d2) : : "a0", "a1", "memory", "cc");

    /* Unpack BCD YYYYMMDD from D1 */
    uint32_t date = (uint32_t)d1;
    dt->year  = (uint16_t)(((date >> 28) & 0xF) * 1000 + ((date >> 24) & 0xF) * 100 +
                            ((date >> 20) & 0xF) * 10   + ((date >> 16) & 0xF));
    dt->month = (uint8_t)(((date >> 12) & 0xF) * 10 + ((date >> 8) & 0xF));
    dt->day   = (uint8_t)(((date >> 4) & 0xF) * 10 + (date & 0xF));

    /* Unpack BCD HHMMSSwd from D2 */
    uint32_t time = (uint32_t)d2;
    dt->hour    = (uint8_t)(((time >> 28) & 0xF) * 10 + ((time >> 24) & 0xF));
    dt->min     = (uint8_t)(((time >> 20) & 0xF) * 10 + ((time >> 16) & 0xF));
    dt->sec     = (uint8_t)(((time >> 12) & 0xF) * 10 + ((time >> 8) & 0xF));
    dt->weekday = (uint8_t)(time & 0xF);
}

void rtc_set_time(uint32_t unix_secs)
{
    register long d0 __asm__("d0") = TRAP_SET_RTC;
    register long d1 __asm__("d1") = (long)unix_secs;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1) : : "a0", "a1", "memory", "cc");
}

uint32_t rtc_get_ticks(void)
{
    register long d0 __asm__("d0") = TRAP_GET_TICKS;
    register long d1 __asm__("d1");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1) : : "a0", "a1", "memory", "cc");
    return (uint32_t)d1;
}
