/*
 * next_rtc.c
 * MC68HC68T1 / MCS1850 RTC emulation via SCR2 bit-bang.
 *
 * Protocol (from mk-108.1 next/clock.c):
 *   1. Assert RTCE (chip enable)
 *   2. Clock out 8-bit address MSB-first on RTDATA, pulsing RTCLK
 *   3. Read:  clock in 8 data bits — sample RTDATA after RTCLK fall
 *      Write: clock out 8 data bits on RTDATA, pulsing RTCLK
 *   4. Deassert RTCE
 *
 * Address bit 7 (RTC_WRITE = 0x80) selects write mode.
 * Address bits 5:0 select the register (0x00-0x3F).
 *
 * Register map (MCS1850 "new clock chip"):
 *   0x00-0x1F  NVRAM (32 bytes)
 *   0x20-0x23  RTC_CNTR0-3 (32-bit seconds counter, big-endian)
 *   0x30       RTC_STATUS  (bit 7 = RTC_NEW_CLOCK)
 *   0x31       RTC_CONTROL (bit 7 = RTC_START)
 *
 * Backend selection:
 *   QEMU_MODE  — software counter (no hardware RTC)
 *   Otherwise  — ZynqMP PS RTC at 0xFFA60000
 */

#include "next_rtc.h"
#include "next_hw.h"
#include "xil_printf.h"
#include <string.h>

#ifndef QEMU_MODE
#include "xrtcpsu_hw.h"
#endif

/* ------------------------------------------------------------------ */
/* RTC register file                                                   */
/* ------------------------------------------------------------------ */
#define RTC_REG_COUNT   64
static uint8_t rtc_regs[RTC_REG_COUNT];

/* Register offsets (from mk-108.1 next/clock.h) */
#define RTC_RAM         0x00
#define RTC_CNTR0       0x20
#define RTC_CNTR1       0x21
#define RTC_CNTR2       0x22
#define RTC_CNTR3       0x23
#define RTC_STATUS      0x30
#define RTC_CONTROL     0x31

#define RTC_NEW_CLOCK   0x80
#define RTC_FTU         0x10
#define RTC_START       0x80
#define RTC_WRITE       0x80

/* ------------------------------------------------------------------ */
/* Software seconds counter (QEMU backend)                             */
/* ------------------------------------------------------------------ */
#ifdef QEMU_MODE
/* Default epoch: 2024-01-01 00:00:00 UTC as NeXT epoch seconds.
 * NeXT epoch is 1900-01-01, so 2024-01-01 = 124 years of seconds.
 * Approximate: 124 * 365.25 * 86400 = 3,913,401,600 */
#define NEXT_EPOCH_2024  3913401600u

static uint32_t soft_rtc_seconds;
static uint32_t soft_rtc_cycle_accum;
#define CYCLES_PER_SECOND  25000000u   /* 25 MHz emulated CPU */
#endif

/* ------------------------------------------------------------------ */
/* Serial protocol state machine                                       */
/* ------------------------------------------------------------------ */
typedef enum {
    RTC_IDLE,           /* RTCE deasserted */
    RTC_ADDR_PHASE,     /* clocking in 8 address bits */
    RTC_DATA_PHASE      /* clocking in/out 8 data bits */
} rtc_phase_t;

static rtc_phase_t rtc_phase;
static int      rtc_bit_count;  /* bits clocked so far in current phase */
static uint8_t  rtc_shift_in;   /* shift register for incoming bits */
static uint8_t  rtc_shift_out;  /* shift register for outgoing bits */
static uint8_t  rtc_address;    /* latched address after addr phase */
static int      rtc_is_write;   /* 1 if address had RTC_WRITE set */
static int      rtc_data_bit;   /* current RTDATA output value (0 or 1) */
static int      rtc_prev_clk;   /* previous RTCLK state */

/* ------------------------------------------------------------------ */
/* Backend: read the seconds counter                                   */
/* ------------------------------------------------------------------ */
/* Default epoch: 2024-01-01 00:00:00 UTC in NeXT epoch seconds */
#define NEXT_EPOCH_DEFAULT  3913401600u

static uint32_t rtc_backend_read_seconds(void)
{
#ifdef QEMU_MODE
    return soft_rtc_seconds;
#else
    /* Use fixed epoch instead of ZynqMP PS RTC.  The ZynqMP RTC may
     * return 0 or an unexpected value, causing the ROM's timing
     * calibration to take a different (failing) code path. */
    return NEXT_EPOCH_DEFAULT;
#endif
}

/* ------------------------------------------------------------------ */
/* Snapshot the seconds counter into RTC_CNTR0-3                       */
/* ------------------------------------------------------------------ */
static void rtc_snapshot_counter(void)
{
    uint32_t secs = rtc_backend_read_seconds();
    rtc_regs[RTC_CNTR0] = (secs >> 24) & 0xFF;
    rtc_regs[RTC_CNTR1] = (secs >> 16) & 0xFF;
    rtc_regs[RTC_CNTR2] = (secs >>  8) & 0xFF;
    rtc_regs[RTC_CNTR3] = (secs >>  0) & 0xFF;
}

/* ------------------------------------------------------------------ */
/* Read a register value                                               */
/* ------------------------------------------------------------------ */
static uint8_t rtc_reg_read(uint8_t addr)
{
    addr &= 0x3F;

    /* Snapshot counter on any read of CNTR0 (MSB) */
    if (addr == RTC_CNTR0)
        rtc_snapshot_counter();

    if (addr < RTC_REG_COUNT)
        return rtc_regs[addr];

    return 0;
}

/* ------------------------------------------------------------------ */
/* Write a register value                                              */
/* ------------------------------------------------------------------ */
static void rtc_reg_write(uint8_t addr, uint8_t val)
{
    addr &= 0x3F;

    /* Counter writes: update backend */
    if (addr >= RTC_CNTR0 && addr <= RTC_CNTR3) {
        rtc_regs[addr] = val;
        if (addr == RTC_CNTR3) {
            /* All 4 bytes written — push to backend */
            uint32_t secs = ((uint32_t)rtc_regs[RTC_CNTR0] << 24) |
                            ((uint32_t)rtc_regs[RTC_CNTR1] << 16) |
                            ((uint32_t)rtc_regs[RTC_CNTR2] <<  8) |
                            ((uint32_t)rtc_regs[RTC_CNTR3] <<  0);
#ifdef QEMU_MODE
            soft_rtc_seconds = secs;
#else
            uint32_t calib = Xil_In32(XRTC_BASEADDR + XRTC_CALIB_RD_OFFSET);
            if ((calib & XRTC_CALIB_RD_MAX_TCK_MASK) == 0)
                Xil_Out32(XRTC_BASEADDR + XRTC_CALIB_WR_OFFSET, 0x00007FFF);
            Xil_Out32(XRTC_BASEADDR + XRTC_SET_TIME_WR_OFFSET, secs);
#endif
        }
        return;
    }

    if (addr == RTC_CONTROL) {
        rtc_regs[addr] = val;
        return;
    }

    /* NVRAM and other registers */
    if (addr < RTC_REG_COUNT)
        rtc_regs[addr] = val;
}

/* ------------------------------------------------------------------ */
/* Initialisation                                                      */
/* ------------------------------------------------------------------ */

void next_rtc_init(void)
{
    memset(rtc_regs, 0, sizeof(rtc_regs));

    /* MCS1850 "new clock chip" identification */
    rtc_regs[RTC_STATUS]  = RTC_NEW_CLOCK;
    rtc_regs[RTC_CONTROL] = RTC_START;

    /* Populate NVRAM with valid defaults and checksum.
     * The ROM reads 32 bytes at RTC_RAM (0x00-0x1F) and verifies a
     * ones-complement checksum at bytes 30-31 (ni_cksum).
     * struct nvram_info layout (32 bytes, big-endian):
     *   [0-3]   bitfield: ni_reset=9, brightness=20, vol=0, etc.
     *   [4-9]   ni_ep (ethernet / hw password)
     *   [10-11] ni_simm (SIMM config)
     *   [12-13] ni_adobe
     *   [14-16] ni_pot (test flags)
     *   [17]    clock/console flags (bit 7 = ni_new_clock_chip)
     *   [18-29] ni_bootcmd (12 chars, null-padded)
     *   [30-31] ni_cksum (ones-complement checksum)
     */
    {
        /* Use the Previous emulator's proven NVRAM defaults
         * (from previous/src/rtcnvram.c nvram_default[]).
         * These are known to work for both Turbo and non-Turbo ROMs. */
        static const uint8_t nvram_default[32] = {
            0x94, 0x0f, 0x40, 0x00,             /* byte 0-3:   volume/brightness/reset=9 */
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* byte 4-9:   hw password/ethernet */
            0xFD, 0xB6,                          /* byte 10-11: SIMM config (4x4MB page-mode) */
            0x00, 0x00,                          /* byte 12-13: adobe */
            0x00, 0x00, 0x00,                    /* byte 14-16: POT=0x00 (all tests disabled) */
            0x00,                                /* byte 17:    clock chip flags */
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* byte 18-29: boot command */
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00                           /* byte 30-31: checksum (recomputed below) */
        };
        memcpy(rtc_regs, nvram_default, 32);

        /* Set ni_new_clock_chip for MCS1850 (Turbo RTC) */
        rtc_regs[17] |= 0x80;

        /* Set ni_alt_cons for serial console on both QEMU and hardware.
         * Without this, the ROM takes a video console init path that
         * includes a timing calibration failing on hardware (error 4).
         * Display output still works: the ROM renders to the bitmap
         * console regardless of ni_alt_cons (POST output goes to VRAM).
         * ni_alt_cons only affects the input source (serial vs keyboard). */
        rtc_regs[0] |= 0x08;  /* bit 27 = ni_alt_cons */

        /* Recompute ones-complement checksum */
        rtc_regs[30] = 0;
        rtc_regs[31] = 0;
        uint32_t sum = 0;
        for (int i = 0; i < 32; i += 2) {
            uint16_t w = ((uint16_t)rtc_regs[i] << 8) | rtc_regs[i + 1];
            sum += w;
        }
        while (sum > 0xFFFF)
            sum = (sum & 0xFFFF) + (sum >> 16);
        uint16_t cksum = ~((uint16_t)sum);
        rtc_regs[30] = (cksum >> 8) & 0xFF;
        rtc_regs[31] = cksum & 0xFF;
    }

    rtc_phase    = RTC_IDLE;
    rtc_bit_count = 0;
    rtc_data_bit = 0;
    rtc_prev_clk = 0;

#ifdef QEMU_MODE
    soft_rtc_seconds = NEXT_EPOCH_2024;
    soft_rtc_cycle_accum = 0;
#else
    /* Ensure the ZynqMP RTC is calibrated */
    uint32_t calib = Xil_In32(XRTC_BASEADDR + XRTC_CALIB_RD_OFFSET);
    if ((calib & XRTC_CALIB_RD_MAX_TCK_MASK) == 0)
        Xil_Out32(XRTC_BASEADDR + XRTC_CALIB_WR_OFFSET, 0x00007FFF);
#endif

    /* Take initial counter snapshot */
    rtc_snapshot_counter();

    xil_printf("[RTC] MC68HC68T1 emulation initialised"
#ifdef QEMU_MODE
               " (software backend)\r\n"
#else
               " (ZynqMP PS RTC backend)\r\n"
#endif
              );
}

/* ------------------------------------------------------------------ */
/* SCR2 write — track RTCE/RTCLK/RTDATA transitions                   */
/* ------------------------------------------------------------------ */

void next_rtc_scr2_write(uint32_t new_scr2, uint32_t old_scr2)
{
    int ce   = (new_scr2 & SCR2_RTCE)   ? 1 : 0;
    int clk  = (new_scr2 & SCR2_RTCLK)  ? 1 : 0;
    int data = (new_scr2 & SCR2_RTDATA) ? 1 : 0;
    int old_ce = (old_scr2 & SCR2_RTCE) ? 1 : 0;

    /* CE rising edge: start new transaction */
    if (ce && !old_ce) {
        static int rtc_trans_count = 0;
        if (rtc_trans_count < 3)
            xil_printf("[RTC] CE rise — transaction #%d\r\n", rtc_trans_count);
        rtc_trans_count++;
        rtc_phase     = RTC_ADDR_PHASE;
        rtc_bit_count = 0;
        rtc_shift_in  = 0;
        rtc_shift_out = 0;
        rtc_address   = 0;
        rtc_is_write  = 0;
        rtc_data_bit  = 0;
        rtc_prev_clk  = clk;
        return;
    }

    /* CE deasserted: end transaction */
    if (!ce) {
        if (old_ce && rtc_phase == RTC_DATA_PHASE && rtc_is_write &&
            rtc_bit_count == 8) {
            /* Complete write: commit the byte */
#ifdef NEXT_IO_DEBUG
            xil_printf("[RTC] write reg $%02X ← $%02X\r\n",
                       rtc_address & 0x3F, rtc_shift_in);
#endif
            rtc_reg_write(rtc_address, rtc_shift_in);
        }
        rtc_phase = RTC_IDLE;
        rtc_data_bit = 0;
        rtc_prev_clk = 0;
        return;
    }

    /* CE is asserted — process clock edges */
    if (rtc_phase == RTC_IDLE) {
        rtc_prev_clk = clk;
        return;
    }

    /* Detect RTCLK falling edge (1 → 0): this is when data is latched */
    int clk_fall = (rtc_prev_clk && !clk);
    rtc_prev_clk = clk;

    if (rtc_phase == RTC_ADDR_PHASE) {
        /* Address bits are clocked in on the FALLING edge of RTCLK.
         * The ROM sets RTDATA, pulses RTCLK high, then low.
         * We sample RTDATA on the falling edge. */
        if (clk_fall) {
            rtc_shift_in = (rtc_shift_in << 1) | data;
            rtc_bit_count++;
            if (rtc_bit_count == 8) {
                rtc_address  = rtc_shift_in;
                rtc_is_write = (rtc_address & RTC_WRITE) ? 1 : 0;

                /* Prepare for data phase */
                rtc_phase     = RTC_DATA_PHASE;
                rtc_bit_count = 0;
                rtc_shift_in  = 0;

                if (!rtc_is_write) {
                    /* Read: load the register value into shift-out */
                    rtc_shift_out = rtc_reg_read(rtc_address);
                    /* Pre-load first bit (MSB) */
                    rtc_data_bit = (rtc_shift_out >> 7) & 1;
                    {
                        static int rtc_read_log = 0;
                        if (rtc_read_log < 5)
                            xil_printf("[RTC] read reg $%02X → $%02X\r\n",
                                       rtc_address & 0x3F, rtc_shift_out);
                        rtc_read_log++;
                    }
                }
            }
        }
    } else if (rtc_phase == RTC_DATA_PHASE) {
        if (rtc_is_write) {
            /* Write: sample RTDATA on falling edge, same as address */
            if (clk_fall) {
                rtc_shift_in = (rtc_shift_in << 1) | data;
                rtc_bit_count++;
                if (rtc_bit_count == 8) {
                    rtc_reg_write(rtc_address, rtc_shift_in);
                    /* For block writes, advance address and reset for next byte */
                    rtc_address = (rtc_address & RTC_WRITE) |
                                  (((rtc_address & 0x3F) + 1) & 0x3F);
                    rtc_bit_count = 0;
                    rtc_shift_in = 0;
                }
            }
        } else {
            /* Read: the ROM samples RTDATA after the FALLING edge.
             * Protocol from clock.c:
             *   write RTCLK=1, delay, write RTCLK=0, delay, read RTDATA
             * So we present the data bit and advance on FALLING edge. */
            if (clk_fall) {
                /* Current bit is already in rtc_data_bit.
                 * Advance to next bit for the next clock cycle. */
                rtc_bit_count++;
                rtc_shift_out <<= 1;
                if (rtc_bit_count < 8) {
                    rtc_data_bit = (rtc_shift_out >> 7) & 1;
                } else {
                    /* Byte complete — for block reads, load next byte */
                    rtc_address = (rtc_address & RTC_WRITE) |
                                  (((rtc_address & 0x3F) + 1) & 0x3F);
                    rtc_shift_out = rtc_reg_read(rtc_address);
                    rtc_data_bit = (rtc_shift_out >> 7) & 1;
                    rtc_bit_count = 0;
                }
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* SCR2 read — inject RTDATA for read transactions                     */
/* ------------------------------------------------------------------ */

uint32_t next_rtc_scr2_read(uint32_t base_scr2)
{
    if (!(base_scr2 & SCR2_RTCE))
        return base_scr2;

    /* During a read transaction, override RTDATA with the current bit */
    if (rtc_phase == RTC_DATA_PHASE && !rtc_is_write) {
        if (rtc_data_bit)
            base_scr2 |= SCR2_RTDATA;
        else
            base_scr2 &= ~SCR2_RTDATA;
    }

    return base_scr2;
}

/* ------------------------------------------------------------------ */
/* Tick — advance software counter (QEMU only)                         */
/* ------------------------------------------------------------------ */

void next_rtc_tick(int cycles)
{
#ifdef QEMU_MODE
    soft_rtc_cycle_accum += (uint32_t)cycles;
    while (soft_rtc_cycle_accum >= CYCLES_PER_SECOND) {
        soft_rtc_cycle_accum -= CYCLES_PER_SECOND;
        soft_rtc_seconds++;
    }
#else
    (void)cycles;
#endif
}
