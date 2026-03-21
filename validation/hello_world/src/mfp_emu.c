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
#include "acia_emu.h"
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

/*
 * ZynqMP RTC set time.
 *
 * The PS RTC has a free-running seconds counter. CUR_TIME reads the live
 * counter. SET_TIME_WR sets the counter value, but it latches on the next
 * second tick — so CUR_TIME may briefly return the old value.
 *
 * The Xilinx standalone driver (XRtcPsu_SetTime) writes to SET_TIME_WR
 * and the hardware reloads the counter at the next tick boundary.
 * We also store the last-written value so reads immediately after a write
 * can return the intended time rather than a stale hardware readback.
 */
static uint32_t rtc_set_value;      /* last value written via SET_RTC */
static int rtc_set_pending;         /* 1 = write pending hardware latch */

static void rtc_write_seconds(uint32_t secs)
{
    uint32_t calib = Xil_In32(XRTC_BASEADDR + XRTC_CALIB_RD_OFFSET);
    if ((calib & XRTC_CALIB_RD_MAX_TCK_MASK) == 0) {
        Xil_Out32(XRTC_BASEADDR + XRTC_CALIB_WR_OFFSET, 0x00007FFF);
    }
    Xil_Out32(XRTC_BASEADDR + XRTC_SET_TIME_WR_OFFSET, secs);
    rtc_set_value = secs;
    rtc_set_pending = 1;
}

static uint32_t rtc_read_seconds(void)
{
    uint32_t hw = Xil_In32(XRTC_BASEADDR + XRTC_CUR_TIME_OFFSET);
    if (rtc_set_pending) {
        /* Hardware may not have latched yet — if readback is still the
         * old value, return what we wrote + elapsed since write. */
        int32_t diff = (int32_t)(hw - rtc_set_value);
        if (diff < -1 || diff > 2) {
            /* Hardware hasn't latched the new value yet — use our value */
            return rtc_set_value;
        }
        rtc_set_pending = 0;  /* hardware caught up */
    }
    return hw;
}

/* RTC write accumulator (big-endian byte writes build a 32-bit value) */
static uint32_t rtc_write_accum;
static int rtc_write_count;

/* Latched RTC snapshot — prevents torn reads across byte accesses.
 * Musashi builds longwords from 4 byte reads; re-sampling the hardware
 * RTC on each byte could mix values across a second rollover.
 * rtc_latch_valid is cleared on write to force re-read. */
static uint32_t rtc_latch;
static int rtc_latch_valid;
static uint32_t datetime_date_latch;
static uint32_t datetime_time_latch;
static int datetime_latch_valid;

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

    /* RTC write accumulator and read latch state */
    rtc_write_accum = 0;
    rtc_write_count = 0;
    rtc_latch_valid = 0;
    datetime_latch_valid = 0;
    rtc_set_pending = 0;
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
        /* Latch on first byte read (or after invalidation by write) */
        int byte_idx = (int)(offset - MFP_OFF_RTC);
        if (byte_idx == 0 || !rtc_latch_valid) {
            rtc_latch = rtc_read_seconds();
            rtc_latch_valid = 1;
        }
        int shift = (3 - byte_idx) * 8;
        /* Invalidate after last byte so next MOVE.L gets fresh value */
        if (byte_idx == 3)
            rtc_latch_valid = 0;
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
        int byte_idx = (int)(offset - MFP_OFF_DATETIME);
        if (byte_idx == 0 || !datetime_latch_valid) {
            epoch_to_bcd(rtc_read_seconds(), &datetime_date_latch, &datetime_time_latch);
            datetime_latch_valid = 1;
        }
        /* Invalidate after last byte */
        if (byte_idx == 7)
            datetime_latch_valid = 0;
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
            /* Invalidate read latches so next read gets the new value */
            rtc_latch_valid = 0;
            datetime_latch_valid = 0;
        }
        break;
    }

    default:
        mfp_regs[offset] = value;
        break;
    }
}

/* ================================================================== */
/* Atari ST MFP at $FFFA00 — interrupt controller for ACIA/Timer C    */
/* ================================================================== */

/* Atari MFP register offsets (odd-byte addressed like real MC68901) */
#define AMFP_GPIP   0x01
#define AMFP_AER    0x03
#define AMFP_DDR    0x05
#define AMFP_IERA   0x07
#define AMFP_IERB   0x09
#define AMFP_IPRA   0x0B
#define AMFP_IPRB   0x0D
#define AMFP_ISRA   0x0F
#define AMFP_ISRB   0x11
#define AMFP_IMRA   0x13
#define AMFP_IMRB   0x15
#define AMFP_VR     0x17
#define AMFP_TACR   0x19
#define AMFP_TBCR   0x1B
#define AMFP_TCDCR  0x1D
#define AMFP_TADR   0x1F
#define AMFP_TBDR   0x21
#define AMFP_TCDR   0x23
#define AMFP_TDDR   0x25
#define AMFP_SCR    0x27
#define AMFP_UCR    0x29
#define AMFP_RSR    0x2B
#define AMFP_TSR    0x2D
#define AMFP_UDR    0x2F

static uint8_t amfp_regs[ATARI_MFP_SIZE];

void atari_mfp_init(void)
{
    int i;
    for (i = 0; i < ATARI_MFP_SIZE; i++)
        amfp_regs[i] = 0;

    /* Default vector register: $40 (vectors at $100+) — EmuTOS writes $48 */
    amfp_regs[AMFP_VR] = 0x40;

    /* GPIP bit 4 = 1 (ACIA interrupt inactive = high) */
    amfp_regs[AMFP_GPIP] = 0x10;

    xil_printf("[AMFP] Atari MFP initialised at $FFFA00\r\n");
}

uint8_t atari_mfp_read(uint32_t offset)
{
    if (offset >= ATARI_MFP_SIZE)
        return 0;

    switch (offset) {
    case AMFP_GPIP:
        /* Bit 4: ACIA interrupt (active low) */
        if (acia_has_irq())
            return amfp_regs[AMFP_GPIP] & ~0x10;  /* clear bit 4 = active */
        else
            return amfp_regs[AMFP_GPIP] | 0x10;   /* set bit 4 = inactive */

    case AMFP_TCDCR:
        /* Forward to existing Timer C: return stored value */
        return amfp_regs[offset];

    case AMFP_TCDR:
        return amfp_regs[offset];

    default:
        return amfp_regs[offset];
    }
}

void atari_mfp_write(uint32_t offset, uint8_t value)
{
    if (offset >= ATARI_MFP_SIZE)
        return;

    switch (offset) {
    case AMFP_IERA:
    case AMFP_IERB:
    case AMFP_IMRA:
    case AMFP_IMRB:
    case AMFP_VR:
        amfp_regs[offset] = value;
        break;

    case AMFP_IPRA:
        /* Writing clears bits (write-1-to-clear would be weird; Atari software
         * typically writes a mask to clear specific bits) */
        amfp_regs[offset] &= value;
        break;

    case AMFP_IPRB:
        amfp_regs[offset] &= value;
        break;

    case AMFP_ISRA:
        /* Software clears ISR bits by writing a mask (e.g., &= 0xBF to clear ACIA) */
        amfp_regs[offset] &= value;
        break;

    case AMFP_ISRB:
        amfp_regs[offset] &= value;
        break;

    case AMFP_TCDCR:
        amfp_regs[offset] = value;
        /* Forward Timer C prescaler bits (6:4) to the existing Timer C engine */
        mfp_write(MFP_OFF_TCDCR, value);
        break;

    case AMFP_TCDR:
        amfp_regs[offset] = value;
        /* Forward reload value to existing Timer C */
        mfp_write(MFP_OFF_TCDR, value);
        break;

    default:
        amfp_regs[offset] = value;
        break;
    }
}

void atari_mfp_set_timer_c_pending(void)
{
    /* IPRB bit 5 = Timer C */
    if (amfp_regs[AMFP_IERB] & 0x20)
        amfp_regs[AMFP_IPRB] |= 0x20;
}

void atari_mfp_update_acia_irq(void)
{
    /* ACIA interrupt is on GPIP4 → MFP channel I6 (IPRB bit 6).
     * On the Atari ST, GPIP4 directly connects to the ACIA IRQ output.
     * Channel I6 is in the B register set (IPRB/IERB/IMRB/ISRB bit 6). */
    if (acia_has_irq()) {
        amfp_regs[AMFP_GPIP] &= ~0x10;
        /* Only set IPRB pending if not already in-service */
        if (!(amfp_regs[AMFP_ISRB] & 0x40)) {
            if (amfp_regs[AMFP_IERB] & 0x40)
                amfp_regs[AMFP_IPRB] |= 0x40;
        }
    } else {
        amfp_regs[AMFP_IPRB] &= ~0x40;
        amfp_regs[AMFP_GPIP] |= 0x10;
    }
}

int atari_mfp_has_pending_irq(void)
{
    /* Check if any MFP interrupt is pending + enabled + masked and
     * not blocked by a higher-priority in-service interrupt. */
    uint8_t pend_a = amfp_regs[AMFP_IPRA] & amfp_regs[AMFP_IERA] & amfp_regs[AMFP_IMRA];
    uint8_t pend_b = amfp_regs[AMFP_IPRB] & amfp_regs[AMFP_IERB] & amfp_regs[AMFP_IMRB];
    return (pend_a || pend_b) ? 1 : 0;
}

int atari_mfp_acknowledge(void)
{
    uint8_t vr_base = amfp_regs[AMFP_VR] & 0xF0;
    /* VR bit 3: 0 = Automatic End-of-Interrupt (AEI), 1 = Software EOI (SEI).
     * In AEI mode the ISR bit is NOT set at acknowledge — the interrupt is
     * fully cleared by the IPR clear alone.  In SEI mode the ISR bit is set
     * and must be cleared by software writing to ISRA/ISRB. */
    int sei_mode = (amfp_regs[AMFP_VR] & 0x08) ? 1 : 0;

    /* Scan IPRA (bits 7..0) — these are interrupt channels 15..8 */
    for (int bit = 7; bit >= 0; bit--) {
        uint8_t mask = (uint8_t)(1 << bit);
        if ((amfp_regs[AMFP_IPRA] & mask) &&
            (amfp_regs[AMFP_IERA] & mask) &&
            (amfp_regs[AMFP_IMRA] & mask)) {
            if (sei_mode)
                amfp_regs[AMFP_ISRA] |= mask;
            amfp_regs[AMFP_IPRA] &= ~mask;
            return vr_base + 8 + bit;  /* A channels: vector base + 8..15 */
        }
    }

    /* Scan IPRB (bits 7..0) — these are interrupt channels 7..0 */
    for (int bit = 7; bit >= 0; bit--) {
        uint8_t mask = (uint8_t)(1 << bit);
        if ((amfp_regs[AMFP_IPRB] & mask) &&
            (amfp_regs[AMFP_IERB] & mask) &&
            (amfp_regs[AMFP_IMRB] & mask)) {
            if (sei_mode)
                amfp_regs[AMFP_ISRB] |= mask;
            amfp_regs[AMFP_IPRB] &= ~mask;
            return vr_base + bit;      /* B channels: vector base + 0..7 */
        }
    }

    return -1;  /* no pending interrupt */
}
