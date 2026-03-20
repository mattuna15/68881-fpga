/*
 * acia_emu.c
 * MC6850 ACIA + IKBD emulation for Atari ST compatibility.
 *
 * Keyboard ACIA at $FFFC00/$FFFC02:
 *   Status (read $FFFC00): bit 0 RDRF, bit 1 TDRE (always 1), bit 7 IRQ
 *   Control (write $FFFC00): bit 7 RX IRQ enable, bits 1:0=0x03 master reset
 *   Data (read $FFFC02): dequeue from RX FIFO
 *   Data (write $FFFC02): IKBD command byte
 *
 * MIDI ACIA at $FFFC04/$FFFC06: stub (TDRE=1, RDRF=0).
 *
 * IKBD command parser handles a subset of commands:
 *   $80+$01 -> push $F1 (version)
 *   $08     -> relative mouse mode
 *   $09+4p  -> absolute mouse mode + max X/Y
 *   $0B+2p  -> mouse threshold (consume, ignore)
 *   $07+1p  -> button action mode (consume, ignore)
 *   $12     -> disable mouse reporting
 *   Others  -> consume expected parameter bytes
 */

#include "acia_emu.h"
#include "xil_printf.h"

/* ------------------------------------------------------------------ */
/* RX FIFO (64-byte circular buffer)                                   */
/* ------------------------------------------------------------------ */

#define ACIA_RX_BUF_SIZE 64

static uint8_t rx_buf[ACIA_RX_BUF_SIZE];
static unsigned int rx_head;   /* write index */
static unsigned int rx_tail;   /* read index */

static int rx_empty(void)
{
    return rx_head == rx_tail;
}

static uint8_t rx_pop(void)
{
    if (rx_head == rx_tail)
        return 0;
    uint8_t ch = rx_buf[rx_tail];
    rx_tail = (rx_tail + 1) % ACIA_RX_BUF_SIZE;
    return ch;
}

/* ------------------------------------------------------------------ */
/* ACIA control state                                                  */
/* ------------------------------------------------------------------ */

static uint8_t acia_ctrl;      /* last value written to control register */
static int acia_rx_irq_en;     /* bit 7 of control: RX interrupt enable */
static int acia_active;        /* set after acia_init() */

/* ------------------------------------------------------------------ */
/* IKBD command parser state                                           */
/* ------------------------------------------------------------------ */

static uint8_t ikbd_cmd;               /* current command byte */
static int ikbd_params_remaining;      /* bytes still expected */
static uint8_t ikbd_params[8];         /* accumulated parameter bytes */
static int ikbd_param_idx;

/* Mouse mode flags */
static int ikbd_mouse_rel;     /* relative mouse mode (default) */
static int ikbd_mouse_abs;     /* absolute mouse mode */
static int ikbd_mouse_dis;     /* mouse reporting disabled */

/* ------------------------------------------------------------------ */
/* IKBD command handling                                                */
/* ------------------------------------------------------------------ */

/* Expected parameter count for IKBD commands.
 * Returns -1 for unknown/unsupported commands (consume 0 params). */
static int ikbd_cmd_param_count(uint8_t cmd)
{
    switch (cmd) {
    case 0x07: return 1;    /* Set mouse button action */
    case 0x08: return 0;    /* Set relative mouse mode */
    case 0x09: return 4;    /* Set absolute mouse mode */
    case 0x0A: return 2;    /* Set mouse keycode mode */
    case 0x0B: return 2;    /* Set mouse threshold */
    case 0x0C: return 2;    /* Set mouse scale */
    case 0x0D: return 0;    /* Interrogate mouse position */
    case 0x0E: return 5;    /* Load mouse position */
    case 0x0F: return 0;    /* Set Y=0 at bottom */
    case 0x10: return 0;    /* Set Y=0 at top */
    case 0x11: return 0;    /* Resume (enable mouse) */
    case 0x12: return 0;    /* Disable mouse */
    case 0x13: return 0;    /* Pause output */
    case 0x14: return 0;    /* Set joystick event reporting */
    case 0x15: return 0;    /* Disable joysticks */
    case 0x16: return 1;    /* Joystick interrogation */
    case 0x17: return 0;    /* Joystick monitoring */
    case 0x18: return 0;    /* Fire button monitoring */
    case 0x19: return 6;    /* Set joystick keycode mode */
    case 0x1A: return 0;    /* Disable joystick -> keycode */
    case 0x1B: return 14;   /* Time-of-day clock set */
    case 0x1C: return 0;    /* Interrogate time-of-day */
    case 0x20: return 0;    /* Memory load */
    case 0x21: return 0;    /* Memory read */
    case 0x22: return 0;    /* Controller execute */
    case 0x80: return 1;    /* Reset */
    case 0x87: return 0;    /* Status inquiries (multiple) */
    default:   return 0;    /* Unknown — no params */
    }
}

static void ikbd_cmd_complete(void)
{
    switch (ikbd_cmd) {
    case 0x80:
        /* Reset: param should be 0x01 */
        if (ikbd_param_idx >= 1 && ikbd_params[0] == 0x01) {
            /* Push IKBD version response: $F0 then $F1 */
            acia_rx_push(0xF0);
            acia_rx_push(0xF1);
        }
        /* Re-enable relative mouse mode on reset */
        ikbd_mouse_rel = 1;
        ikbd_mouse_abs = 0;
        ikbd_mouse_dis = 0;
        break;

    case 0x08:
        /* Set relative mouse position reporting */
        ikbd_mouse_rel = 1;
        ikbd_mouse_abs = 0;
        ikbd_mouse_dis = 0;
        break;

    case 0x09:
        /* Set absolute mouse position reporting (params: maxX_hi, maxX_lo, maxY_hi, maxY_lo) */
        ikbd_mouse_abs = 1;
        ikbd_mouse_rel = 0;
        ikbd_mouse_dis = 0;
        break;

    case 0x11:
        /* Resume — re-enable mouse */
        ikbd_mouse_dis = 0;
        break;

    case 0x12:
        /* Disable mouse position reporting */
        ikbd_mouse_dis = 1;
        break;

    default:
        /* Other commands: consumed and ignored */
        break;
    }
}

static void ikbd_cmd_receive(uint8_t byte)
{
    if (ikbd_params_remaining > 0) {
        /* Accumulating parameters for current command */
        if (ikbd_param_idx < (int)sizeof(ikbd_params))
            ikbd_params[ikbd_param_idx] = byte;
        ikbd_param_idx++;
        ikbd_params_remaining--;
        if (ikbd_params_remaining == 0)
            ikbd_cmd_complete();
        return;
    }

    /* New command byte */
    ikbd_cmd = byte;
    ikbd_param_idx = 0;
    ikbd_params_remaining = ikbd_cmd_param_count(byte);
    if (ikbd_params_remaining == 0)
        ikbd_cmd_complete();
}

/* ------------------------------------------------------------------ */
/* Public API                                                          */
/* ------------------------------------------------------------------ */

void acia_init(void)
{
    rx_head = 0;
    rx_tail = 0;
    acia_ctrl = 0;
    acia_rx_irq_en = 0;
    acia_active = 1;

    /* IKBD defaults: relative mouse mode, reporting enabled */
    ikbd_cmd = 0;
    ikbd_params_remaining = 0;
    ikbd_param_idx = 0;
    ikbd_mouse_rel = 1;
    ikbd_mouse_abs = 0;
    ikbd_mouse_dis = 0;

    xil_printf("[ACIA] Initialised (keyboard + MIDI stub)\r\n");
}

int acia_rx_push(uint8_t byte)
{
    unsigned int next = (rx_head + 1) % ACIA_RX_BUF_SIZE;
    if (next == rx_tail)
        return -1;  /* full */
    rx_buf[rx_head] = byte;
    rx_head = next;
    return 0;
}

int acia_has_irq(void)
{
    return acia_active && acia_rx_irq_en && !rx_empty();
}

int ikbd_mouse_enabled(void)
{
    return !ikbd_mouse_dis;
}

int acia_mode_active(void)
{
    return acia_active;
}

uint8_t acia_read(uint32_t addr)
{
    uint32_t reg = addr - ACIA_BASE;

    switch (reg) {
    case 0x00: {
        /* Keyboard ACIA status register */
        uint8_t status = 0x02;  /* TDRE always 1 */
        if (!rx_empty())
            status |= 0x01;    /* RDRF */
        if (acia_rx_irq_en && !rx_empty())
            status |= 0x80;    /* IRQ */
        return status;
    }

    case 0x02:
        /* Keyboard ACIA data register — dequeue from RX FIFO */
        return rx_pop();

    case 0x04:
        /* MIDI ACIA status: TDRE=1, RDRF=0 */
        return 0x02;

    case 0x06:
        /* MIDI ACIA data: nothing */
        return 0x00;

    default:
        return 0;
    }
}

void acia_write(uint32_t addr, uint8_t val)
{
    uint32_t reg = addr - ACIA_BASE;

    switch (reg) {
    case 0x00:
        /* Keyboard ACIA control register */
        acia_ctrl = val;
        if ((val & 0x03) == 0x03) {
            /* Master reset: clear FIFO, reset state */
            rx_head = 0;
            rx_tail = 0;
            acia_rx_irq_en = 0;
        } else {
            acia_rx_irq_en = (val & 0x80) ? 1 : 0;
        }
        break;

    case 0x02:
        /* Keyboard ACIA data register write — IKBD command byte */
        ikbd_cmd_receive(val);
        break;

    case 0x04:
        /* MIDI ACIA control: ignore */
        break;

    case 0x06:
        /* MIDI ACIA data: ignore */
        break;

    default:
        break;
    }
}
