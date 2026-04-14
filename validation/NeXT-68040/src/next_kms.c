/*
 * next_kms.c
 * NeXT KMS (Keyboard/Mouse/Sound) monitor chip emulation.
 *
 * Provides keyboard input to the ROM monitor by converting ASCII
 * characters (from ARM UART or USB HID) into NeXT keyboard events
 * readable at P_MON ($0200E000).
 *
 * The NeXT keyboard scan code table is from mk-108.1 nextdev/keycodes.h.
 * We build a reverse mapping (ASCII → key_code + shift) at init time.
 */

#include "next_kms.h"
#include "xil_printf.h"

/* ------------------------------------------------------------------ */
/* NeXT keyboard scan code table (from nextdev/keycodes.h)            */
/* Format: ascii[key_code * 2] = unshifted, ascii[key_code * 2 + 1] = shifted */
/* ------------------------------------------------------------------ */

#define INV 0  /* invalid / special key */

static const unsigned char next_ascii[164] = {
    /* key_code 0-7 */
    INV, INV, INV, INV, INV, INV, '\\', '|',
    ']', '}', '[', '{', 'i', 'I', 'o', 'O',
    /* key_code 8-15 */
    'p', 'P', INV, INV, INV, INV, '0', '0',
    '.', '.', '\r', '\r', INV, INV, INV, INV,
    /* key_code 16-23 */
    INV, INV, '1', '1', '4', '4', '6', '6',
    '3', '3', '+', '+', INV, INV, '2', '2',
    /* key_code 24-31 */
    '5', '5', INV, INV, INV, INV, 0x7F, 0x08,
    '=', '+', '-', '_', '8', '*', '9', '(',
    /* key_code 32-39 */
    '0', ')', '7', '7', '8', '8', '9', '9',
    '-', '-', '*', '*', '`', '~', '=', '|',
    /* key_code 40-47 */
    '/', '\\', INV, INV, '\r', '\r', '\'', '"',
    ';', ':', 'l', 'L', ',', '<', '.', '>',
    /* key_code 48-55 */
    '/', '?', 'z', 'Z', 'x', 'X', 'c', 'C',
    'v', 'V', 'b', 'B', 'm', 'M', 'n', 'N',
    /* key_code 56-63 */
    ' ', ' ', 'a', 'A', 's', 'S', 'd', 'D',
    'f', 'F', 'g', 'G', 'k', 'K', 'j', 'J',
    /* key_code 64-71 */
    'h', 'H', '\t', '\t', 'q', 'Q', 'w', 'W',
    'e', 'E', 'r', 'R', 'u', 'U', 'y', 'Y',
    /* key_code 72-79 */
    't', 'T', 0x1B, '~', '1', '!', '2', '@',
    '3', '#', '4', '$', '7', '&', '6', '^',
    /* key_code 80-81 */
    '5', '%',
};

#define NEXT_ASCII_COUNT (sizeof(next_ascii) / sizeof(next_ascii[0]))
#define NEXT_KEY_COUNT   (NEXT_ASCII_COUNT / 2)

/* Reverse mapping: ASCII char → { key_code, shift } */
typedef struct {
    uint8_t key_code;
    uint8_t shift;     /* 1 if shift is needed */
} ascii_to_next_t;

static ascii_to_next_t reverse_map[128];
static int reverse_map_built = 0;

static void build_reverse_map(void)
{
    /* Clear: 0 = unmapped */
    for (int i = 0; i < 128; i++) {
        reverse_map[i].key_code = 0xFF; /* invalid */
        reverse_map[i].shift = 0;
    }

    /* Build from the forward table — prefer unshifted entries */
    for (int kc = 0; kc < (int)NEXT_KEY_COUNT; kc++) {
        unsigned char unshifted = next_ascii[kc * 2];
        unsigned char shifted = next_ascii[kc * 2 + 1];

        if (unshifted > 0 && unshifted < 128 && reverse_map[unshifted].key_code == 0xFF) {
            reverse_map[unshifted].key_code = (uint8_t)kc;
            reverse_map[unshifted].shift = 0;
        }
        if (shifted > 0 && shifted < 128 && reverse_map[shifted].key_code == 0xFF) {
            reverse_map[shifted].key_code = (uint8_t)kc;
            reverse_map[shifted].shift = 1;
        }
    }

    /* Map newline to carriage return key */
    if (reverse_map['\n'].key_code == 0xFF)
        reverse_map['\n'] = reverse_map['\r'];

    reverse_map_built = 1;
}

/* ------------------------------------------------------------------ */
/* KMS command transmit state                                          */
/* ------------------------------------------------------------------ */

/*
 * The NeXT monitor chip has CTX (command transmit) and DTX (data transmit)
 * status bits.  mon_send_nodma() in the kernel spins:
 *     while (mon->mon_csr.ctx) ;
 * waiting for CTX to go LOW, then writes cmd+data.
 *
 * CTX HIGH = command shift register is busy (still shifting out).
 * CTX LOW  = command shift register is idle (ready for new command).
 *
 * Since we don't have real serial shift hardware, we just:
 *   - Return CTX=0 (idle) on reads so mon_send_nodma doesn't spin.
 *   - Accept writes silently (command is "instantly transmitted").
 *
 * DTX works the same way for data; return 0 = idle.
 * CTX_PEND/DTX_PEND likewise return 0 = nothing pending.
 */

/* ------------------------------------------------------------------ */
/* mon_csr byte-1 (K/M status) bit layout — matches Previous's kms.c   */
/* ------------------------------------------------------------------ */
#define KBD_INT         0x80
#define KBD_RECEIVED    0x40
#define KBD_OVERRUN     0x20
#define NMI_RECEIVED    0x10
#define KMS_INT         0x08
#define KMS_RECEIVED    0x04
#define KMS_OVERRUN     0x02

/* Live copy of byte 1 of mon_csr. Set when a KMS command response is
 * "received", cleared when the kernel reads the km_data register. */
static uint8_t kms_stat_km = 0;

/* Latched km_data response — "no response error | user poll |
 * device invalid" pattern, mirrors Previous's kms_response() default
 * value exactly so the ROM POST code sees the device as absent.
 *
 *   bit 30 = NO_RESPONSE_ERR (0x40000000)
 *   bit 29 = USER_POLL       (0x20000000)
 *   bit 28 = DEVICE_INVALID  (0x10000000)
 */
#define KM_DATA_NO_RESPONSE  0x70000000u
static uint32_t kms_km_data_reg = 0;

/* Record the last command byte written to the KMS command register
 * (byte 3 of mon_csr, $0200E003) so writes to the data register can
 * dispatch. */
static uint8_t kms_cmd_byte = 0;

/* Synthesize a "no response" reply: update km_data + assert the two
 * K/M status bits the ROM polls on. */
static void kms_synth_response(void)
{
    kms_km_data_reg = KM_DATA_NO_RESPONSE;
    kms_stat_km |= (KBD_RECEIVED | KBD_INT);
}

/* Called from the KMS poll detector in next_devs.c when the same PC
 * has read mon_csr enough times that it is clearly waiting on a
 * response we never produced (e.g. post-reset self-test).  Auto-fire
 * a no-response reply to unblock it. */
void next_kms_force_response(void)
{
    kms_synth_response();
}

/* ------------------------------------------------------------------ */
/* Keyboard event queue                                                */
/* ------------------------------------------------------------------ */

#define KMS_QUEUE_SIZE  16
static uint32_t kms_queue[KMS_QUEUE_SIZE];
static int kms_head, kms_tail;

static int kms_queue_empty(void)
{
    return kms_head == kms_tail;
}

static void kms_queue_push(uint32_t event)
{
    int next = (kms_head + 1) % KMS_QUEUE_SIZE;
    if (next == kms_tail) {
        static int drop_count = 0;
        if (drop_count < 5)
            xil_printf("[KMS] WARNING: event queue full, key dropped\r\n");
        drop_count++;
        return;
    }
    kms_queue[kms_head] = event;
    kms_head = next;
}

static uint32_t kms_queue_pop(void)
{
    if (kms_queue_empty())
        return 0;
    uint32_t event = kms_queue[kms_tail];
    kms_tail = (kms_tail + 1) % KMS_QUEUE_SIZE;
    return event;
}

/* ------------------------------------------------------------------ */
/* Build a NeXT keyboard event word                                    */
/* ------------------------------------------------------------------ */

static uint32_t build_kybd_event(uint8_t key_code, int shift, int key_up)
{
    /* union kybd_event layout (big-endian 32-bit):
     * bits 31-16: 0 (device address)
     * bit 15:     valid = 1
     * bit 14:     alt_right = 0
     * bit 13:     alt_left = 0
     * bit 12:     command_right = 0
     * bit 11:     command_left = 0
     * bit 10:     shift_right
     * bit 9:      shift_left
     * bit 8:      control = 0
     * bit 7:      up_down (0=down, 1=up)  -- NOTE: bit 7 not bit 8
     * bits 6-0:   key_code (7 bits)
     */
    /* Actually re-reading the struct:
     * u_int : 16, valid:1, alt_right:1, alt_left:1, command_right:1,
     *         command_left:1, shift_right:1, shift_left:1, control:1,
     *         up_down:1, key_code:7;
     * This is 16+1+1+1+1+1+1+1+1+1+7 = 32 bits */
    uint32_t ev = 0;
    ev |= (1U << 15);              /* valid */
    if (shift)
        ev |= (1U << 10);          /* shift_right */
    if (key_up)
        ev |= (1U << 7);           /* up_down = KM_UP */
    ev |= (key_code & 0x7F);       /* key_code in bits 6-0 */
    return ev;
}

/* ------------------------------------------------------------------ */
/* Public API                                                          */
/* ------------------------------------------------------------------ */

void next_kms_init(void)
{
    kms_head = kms_tail = 0;
    build_reverse_map();
    xil_printf("[KMS] Keyboard emulation initialised (%d keycodes mapped)\r\n",
               NEXT_KEY_COUNT);
}

void next_kms_push_ascii(uint8_t ch)
{
    if (!reverse_map_built)
        build_reverse_map();

    if (ch >= 128) return;

    ascii_to_next_t *m = &reverse_map[ch];
    if (m->key_code == 0xFF) {
        /* Unmapped character — try control codes */
        if (ch >= 1 && ch <= 26) {
            /* Ctrl+letter: find the letter key_code */
            m = &reverse_map['a' + ch - 1];
            if (m->key_code != 0xFF) {
                /* Build event with control modifier */
                uint32_t ev = build_kybd_event(m->key_code, 0, 0);
                ev |= (1U << 8); /* control bit */
                kms_queue_push(ev);
                return;
            }
        }
        return;
    }

    /* Key-down then key-up — ROM expects both for each keystroke */
    kms_queue_push(build_kybd_event(m->key_code, m->shift, 0));
    kms_queue_push(build_kybd_event(m->key_code, m->shift, 1));
}

uint32_t next_kms_read(int offset)
{
    static int kms_read_log = 0;
    if (kms_read_log < 10) {
        xil_printf("[KMS] read offset=$%X stat_km=$%02X queue_empty=%d\r\n",
                   offset, kms_stat_km, kms_queue_empty());
        kms_read_log++;
    }

    switch (offset) {
    case 0x00: /* mon_csr (full 32-bit) */
    {
        /* Byte 0 = sound DMA status (empty)
         * Byte 1 = K/M status (kms_stat_km — includes synthesized responses
         *          and real keyboard queue state)
         * Byte 2 = TX state — report idle + KMS_ENABLE set so driver knows
         *          the chip is out of reset
         * Byte 3 = last command byte */
        uint8_t stat_km = kms_stat_km;
        if (!kms_queue_empty())
            stat_km |= KBD_RECEIVED | KBD_INT;  /* real keyboard data */
        return ((uint32_t)0       << 24) |  /* snd_dma idle */
               ((uint32_t)stat_km << 16) |
               ((uint32_t)0x02    <<  8) |  /* KMS_ENABLE: chip ready */
               ((uint32_t)kms_cmd_byte);
    }

    case 0x08: /* mon_km_data (32-bit) — reading clears KBD_RECEIVED/KBD_INT */
    {
        uint32_t val;
        if (!kms_queue_empty()) {
            val = kms_queue_pop();
        } else {
            val = kms_km_data_reg;
        }
        kms_stat_km &= ~(KBD_RECEIVED | KBD_INT);
        return val;
    }

    case 0x04: /* mon_data */
    case 0x0C: /* mon_sound_data */
    default:
        return 0;
    }
}

void next_kms_write(int offset, uint32_t value)
{
    static int kms_write_log = 0;
    if (kms_write_log < 20) {
        xil_printf("[KMS] write offset=$%X val=$%08X\r\n", offset, value);
        kms_write_log++;
    }

    switch (offset) {
    case 0x00:
        /* mon_csr write: clear acknowledged bits from byte 1.
         * Matches Previous's KMS_Ctrl_KM_Write behaviour. */
    {
        uint8_t ack = (value >> 16) & 0xFF;
        if (ack & KBD_OVERRUN)
            kms_stat_km &= ~(KBD_RECEIVED | KBD_OVERRUN | KBD_INT);
        if (ack & NMI_RECEIVED)
            kms_stat_km &= ~NMI_RECEIVED;
        if (ack & KMS_OVERRUN)
            kms_stat_km &= ~(KMS_RECEIVED | KMS_OVERRUN | KMS_INT);
        /* Byte 3 = command to be latched for next data write */
        kms_cmd_byte = value & 0xFF;
        break;
    }

    case 0x04:
        /* mon_data write: issues the KMS command.  We don't actually
         * execute the command but we DO synthesize a "no response"
         * reply so the ROM/kernel's poll loop makes progress. */
        kms_synth_response();
        break;

    default:
        break;
    }
}
