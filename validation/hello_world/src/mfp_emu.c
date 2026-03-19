/*
 * mfp_emu.c
 * MC68901 MFP emulation — USART, Timer C, and RTC.
 *
 * The BIOS ROM polls MFPTSR bit 7 (TX buffer empty) then writes
 * a character to MFPUDR.  We always report TX ready and redirect
 * written characters to text_fb_putc().
 *
 * For RX, characters pushed via mfp_rx_push() (from ARM UART)
 * are buffered in a circular queue.  MFPRSR bit 7 indicates data
 * available; reading MFPUDR dequeues a byte.
 *
 * RTC reads/writes go to the ZynqMP PS built-in RTC (0xFFA60000).
 * Timer C uses cycle counting to generate IPL 6 interrupts.
 */

#include "mfp_emu.h"
#include "text_fb.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xiltimer.h"
#include "xrtcpsu_hw.h"

/* Shadow registers — most are don't-care, just store writes */
static uint8_t mfp_regs[MFP_SIZE];

/* Millisecond tick counter baseline */
static XTime mfp_time_base;

/* UART RX circular buffer */
#define RX_BUF_SIZE 256
static uint8_t rx_buf[RX_BUF_SIZE];
static volatile unsigned int rx_head;   /* write index */
static volatile unsigned int rx_tail;   /* read index */

/* ------------------------------------------------------------------ */
/* Timer C state                                                      */
/* ------------------------------------------------------------------ */

/* MC68901 Timer C prescaler lookup (TCDCR bits 6-4) */
static const uint32_t tc_prescaler_table[8] = {
    0, 4, 10, 16, 50, 64, 100, 200
};

#define MFP_XTAL_HZ    2457600u    /* MC68901 crystal frequency */
#define CPU_CLOCK_HZ    33000000u  /* M68K emulated clock */

static uint32_t tc_prescaler;       /* current prescaler value (0=stopped) */
static uint8_t  tc_reload;          /* TCDR reload value */
static uint32_t tc_period_cycles;   /* CPU cycles per Timer C tick */
static int32_t  tc_accumulator;     /* cycle countdown accumulator */

static void tc_recompute(void)
{
    if (tc_prescaler == 0 || tc_reload == 0) {
        tc_period_cycles = 0;  /* stopped */
        return;
    }
    tc_period_cycles = (uint32_t)((uint64_t)CPU_CLOCK_HZ * tc_prescaler * tc_reload / MFP_XTAL_HZ);
    tc_accumulator = (int32_t)tc_period_cycles;
}

/* ------------------------------------------------------------------ */
/* RTC helpers — access ZynqMP PS RTC at 0xFFA60000                   */
/* ------------------------------------------------------------------ */

static uint32_t rtc_read_seconds(void)
{
    return Xil_In32(XRTC_BASEADDR + XRTC_CUR_TIME_OFFSET);
}

static void rtc_write_seconds(uint32_t secs)
{
    Xil_Out32(XRTC_BASEADDR + XRTC_SET_TIME_WR_OFFSET, secs);
}

/* RTC write accumulator (big-endian byte writes build a 32-bit value) */
static uint32_t rtc_write_accum;
static int rtc_write_count;

/* Latched RTC snapshot — prevents torn reads across byte accesses.
 * Musashi builds longwords from 4 byte reads; re-sampling the hardware
 * RTC on each byte could mix values across a second rollover. */
static uint32_t rtc_latch;
static uint32_t rtc_latch_offset;  /* offset of first byte read (for latch invalidation) */
static uint32_t datetime_date_latch;
static uint32_t datetime_time_latch;
static uint32_t datetime_latch_offset;

/* Convert Unix epoch seconds to BCD date and time.
 * date_bcd = 0xYYYYMMDD, time_bcd = 0xHHMMSSwd (wd = weekday, 0=Sun) */
static void epoch_to_bcd(uint32_t epoch, uint32_t *date_bcd, uint32_t *time_bcd)
{
    static const uint16_t mdays[12] = {31,28,31,30,31,30,31,31,30,31,30,31};

    uint32_t secs = epoch % 86400;
    uint32_t days = epoch / 86400;

    uint8_t hour = (uint8_t)(secs / 3600);
    secs %= 3600;
    uint8_t min  = (uint8_t)(secs / 60);
    uint8_t sec  = (uint8_t)(secs % 60);

    /* Weekday: 1970-01-01 was Thursday (4) */
    uint8_t wday = (uint8_t)((days + 4) % 7);  /* 0=Sun */

    /* Year/month/day from day count */
    uint16_t year = 1970;
    while (1) {
        int leap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
        uint16_t ydays = leap ? 366 : 365;
        if (days < ydays)
            break;
        days -= ydays;
        year++;
    }

    int leap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
    uint8_t month = 0;
    while (month < 11) {
        uint16_t md = mdays[month];
        if (month == 1 && leap)
            md = 29;
        if (days < md)
            break;
        days -= md;
        month++;
    }
    month++;  /* 1-based */
    uint8_t day = (uint8_t)(days + 1);

    /* Pack into BCD */
    #define BCD2(v) (uint8_t)((((v) / 10) << 4) | ((v) % 10))

    uint8_t y3 = (uint8_t)(year / 1000);
    uint8_t y2 = (uint8_t)((year / 100) % 10);
    uint8_t y1 = (uint8_t)((year / 10) % 10);
    uint8_t y0 = (uint8_t)(year % 10);

    *date_bcd = ((uint32_t)y3 << 28) | ((uint32_t)y2 << 24) |
                ((uint32_t)y1 << 20) | ((uint32_t)y0 << 16) |
                ((uint32_t)BCD2(month) << 8) | BCD2(day);

    *time_bcd = ((uint32_t)BCD2(hour) << 24) |
                ((uint32_t)BCD2(min) << 16) |
                ((uint32_t)BCD2(sec) << 8) |
                wday;

    #undef BCD2
}

/* ------------------------------------------------------------------ */
/* Public API                                                         */
/* ------------------------------------------------------------------ */

void mfp_init(void)
{
    int i;
    for (i = 0; i < MFP_SIZE; i++)
        mfp_regs[i] = 0;

    rx_head = 0;
    rx_tail = 0;

    /* TSR: bit 7 (buffer empty) always starts set */
    mfp_regs[MFP_OFF_TSR] = 0x80;

    /* Latch ARM timer baseline for ms tick counter */
    XTime_GetTime(&mfp_time_base);

    /* Timer C starts stopped until BIOS configures TCDCR/TCDR */
    tc_prescaler = 0;
    tc_reload = 0;
    tc_period_cycles = 0;
    tc_accumulator = 0;

    /* RTC write accumulator */
    rtc_write_accum = 0;
    rtc_write_count = 0;
}

int mfp_timer_tick(uint32_t cycles_elapsed)
{
    if (tc_period_cycles == 0)
        return 0;  /* timer stopped */
    tc_accumulator -= (int32_t)cycles_elapsed;
    if (tc_accumulator <= 0) {
        /* Re-align accumulator to handle multiple expirations in one batch.
         * Without this, small period values cause accumulator to stay negative
         * and fire every iteration instead of at the programmed rate. */
        while (tc_accumulator <= 0)
            tc_accumulator += (int32_t)tc_period_cycles;
        return 1;  /* fire interrupt (once per batch, regardless of how many expired) */
    }
    return 0;
}

int mfp_rx_has_data(void)
{
    return rx_head != rx_tail;
}

int mfp_rx_push(uint8_t ch)
{
    unsigned int next = (rx_head + 1) % RX_BUF_SIZE;
    if (next == rx_tail)
        return -1;  /* full */
    rx_buf[rx_head] = ch;
    rx_head = next;
    return 0;
}

static uint8_t rx_pop(void)
{
    if (rx_head == rx_tail)
        return 0;
    uint8_t ch = rx_buf[rx_tail];
    rx_tail = (rx_tail + 1) % RX_BUF_SIZE;
    return ch;
}

uint8_t mfp_read(uint32_t offset)
{
    if (offset >= MFP_SIZE) {
        xil_printf("[MFP] BUG: read offset 0x%02X out of range\r\n", offset);
        return 0;
    }

    switch (offset) {
    case MFP_OFF_TSR:
        return 0x80;

    case MFP_OFF_RSR:
        return mfp_rx_has_data() ? 0x80 : 0x00;

    case MFP_OFF_UDR:
        return rx_pop();

    case MFP_OFF_TICK:
    case MFP_OFF_TICK + 1:
    case MFP_OFF_TICK + 2:
    case MFP_OFF_TICK + 3: {
        XTime now;
        XTime_GetTime(&now);
        uint32_t ms = (uint32_t)((now - mfp_time_base) / (COUNTS_PER_SECOND / 1000));
        int shift = (3 - (offset - MFP_OFF_TICK)) * 8;
        return (ms >> shift) & 0xFF;
    }

    case MFP_OFF_RTC:
    case MFP_OFF_RTC + 1:
    case MFP_OFF_RTC + 2:
    case MFP_OFF_RTC + 3: {
        /* Latch on first byte read to prevent torn values across
         * the 4 byte reads that Musashi uses for a MOVE.L */
        int byte_idx = (int)(offset - MFP_OFF_RTC);
        if (byte_idx == 0)
            rtc_latch = rtc_read_seconds();
        int shift = (3 - byte_idx) * 8;
        return (rtc_latch >> shift) & 0xFF;
    }

    case MFP_OFF_DATETIME:
    case MFP_OFF_DATETIME + 1:
    case MFP_OFF_DATETIME + 2:
    case MFP_OFF_DATETIME + 3:
    case MFP_OFF_DATETIME + 4:
    case MFP_OFF_DATETIME + 5:
    case MFP_OFF_DATETIME + 6:
    case MFP_OFF_DATETIME + 7: {
        /* Latch on first byte read to prevent torn date/time */
        int byte_idx = (int)(offset - MFP_OFF_DATETIME);
        if (byte_idx == 0)
            epoch_to_bcd(rtc_read_seconds(), &datetime_date_latch, &datetime_time_latch);
        if (byte_idx < 4) {
            int shift = (3 - byte_idx) * 8;
            return (datetime_date_latch >> shift) & 0xFF;
        } else {
            int shift = (7 - byte_idx) * 8;
            return (datetime_time_latch >> shift) & 0xFF;
        }
    }

    default:
        return mfp_regs[offset];
    }
}

void mfp_write(uint32_t offset, uint8_t value)
{
    if (offset >= MFP_SIZE) {
        xil_printf("[MFP] BUG: write offset 0x%02X out of range\r\n", offset);
        return;
    }

    switch (offset) {
    case MFP_OFF_UDR:
        text_fb_putc((char)value);
        outbyte(value);
        break;

    case MFP_OFF_TCDCR:
        mfp_regs[offset] = value;
        /* Extract Timer C prescaler from bits 6-4 */
        tc_prescaler = tc_prescaler_table[(value >> 4) & 7];
        tc_recompute();
        break;

    case MFP_OFF_TCDR:
        mfp_regs[offset] = value;
        tc_reload = value;
        tc_recompute();
        break;

    case MFP_OFF_RTC:
    case MFP_OFF_RTC + 1:
    case MFP_OFF_RTC + 2:
    case MFP_OFF_RTC + 3: {
        /* Accumulate big-endian byte writes into a 32-bit value */
        int byte_idx = (int)(offset - MFP_OFF_RTC);
        int shift = (3 - byte_idx) * 8;
        rtc_write_accum = (rtc_write_accum & ~(0xFFu << shift)) | ((uint32_t)value << shift);
        rtc_write_count++;
        /* Commit on 4th byte write (or on any longword-aligned write to offset 0x34) */
        if (rtc_write_count >= 4 || byte_idx == 3) {
            rtc_write_seconds(rtc_write_accum);
            rtc_write_count = 0;
        }
        break;
    }

    default:
        mfp_regs[offset] = value;
        break;
    }
}
