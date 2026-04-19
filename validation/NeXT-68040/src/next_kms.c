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

/* ------------------------------------------------------------------ */
/* HID USB boot-protocol -> NeXT key_code translation                  */
/* ------------------------------------------------------------------ */
/*
 * Built from NeXTMach/mk-108.1/nextdev/keycodes.h (authoritative NeXT
 * ASCII[] table) by walking HID Usage IDs (Keyboard/Keypad page 0x07)
 * and mapping each to the NeXT 7-bit key_code that produces the same
 * character.  Arrows and other non-ASCII NeXT keys (kc 9 = left, 15 =
 * down, 16 = right, 22 = up) are set by hand.
 *
 * A value of 0xFF means "unmapped" and the event is dropped.
 */
#define NKC_NONE    0xFF
#define HID_TABLE_SIZE 0xE8

static const uint8_t hid_to_next[HID_TABLE_SIZE] = {
    /* 0x00-0x03: reserved / rollover error */
    [0x00 ... 0x03] = NKC_NONE,

    /* Letters (HID 0x04-0x1D) */
    [0x04] = 57,  /* a */
    [0x05] = 53,  /* b */
    [0x06] = 51,  /* c */
    [0x07] = 59,  /* d */
    [0x08] = 68,  /* e */
    [0x09] = 60,  /* f */
    [0x0A] = 61,  /* g */
    [0x0B] = 64,  /* h */
    [0x0C] = 6,   /* i */
    [0x0D] = 63,  /* j */
    [0x0E] = 62,  /* k */
    [0x0F] = 45,  /* l */
    [0x10] = 54,  /* m */
    [0x11] = 55,  /* n */
    [0x12] = 7,   /* o */
    [0x13] = 8,   /* p */
    [0x14] = 66,  /* q */
    [0x15] = 69,  /* r */
    [0x16] = 58,  /* s */
    [0x17] = 72,  /* t */
    [0x18] = 70,  /* u */
    [0x19] = 52,  /* v */
    [0x1A] = 67,  /* w */
    [0x1B] = 50,  /* x */
    [0x1C] = 71,  /* y */
    [0x1D] = 49,  /* z */

    /* Number row '1'-'0' (HID 0x1E-0x27) */
    [0x1E] = 74,  /* 1 / ! */
    [0x1F] = 75,  /* 2 / @ */
    [0x20] = 76,  /* 3 / # */
    [0x21] = 77,  /* 4 / $ */
    [0x22] = 80,  /* 5 / % */
    [0x23] = 79,  /* 6 / ^ */
    [0x24] = 78,  /* 7 / & */
    [0x25] = 30,  /* 8 / * */
    [0x26] = 31,  /* 9 / ( */
    [0x27] = 32,  /* 0 / ) */

    /* Editing keys */
    [0x28] = 42,  /* Enter/Return (main keyboard) */
    [0x29] = 73,  /* Escape */
    [0x2A] = 27,  /* Backspace/Delete (NeXT DEL/BS on kc 27) */
    [0x2B] = 65,  /* Tab */
    [0x2C] = 56,  /* Space */

    /* Punctuation */
    [0x2D] = 29,  /* - / _ */
    [0x2E] = 28,  /* = / + */
    [0x2F] = 5,   /* [ / { */
    [0x30] = 4,   /* ] / } */
    [0x31] = 3,   /* \ / | */
    [0x32] = 3,   /* non-US # / ~ (treat as backslash) */
    [0x33] = 44,  /* ; / : */
    [0x34] = 43,  /* ' / " */
    [0x35] = 38,  /* ` / ~ */
    [0x36] = 46,  /* , / < */
    [0x37] = 47,  /* . / > */
    [0x38] = 48,  /* / / ? */
    [0x39] = NKC_NONE,  /* Caps Lock (handled host-side for LEDs) */

    /* F1-F12: no direct NeXT analogue on the basic keyset */
    [0x3A ... 0x45] = NKC_NONE,

    [0x46] = NKC_NONE,  /* PrintScreen */
    [0x47] = NKC_NONE,  /* ScrollLock */
    [0x48] = NKC_NONE,  /* Pause */
    [0x49] = NKC_NONE,  /* Insert (no NeXT equivalent) */
    [0x4A] = NKC_NONE,  /* Home */
    [0x4B] = NKC_NONE,  /* PageUp */
    [0x4C] = 27,        /* Delete (forward) -> same as Backspace on NeXT */
    [0x4D] = NKC_NONE,  /* End */
    [0x4E] = NKC_NONE,  /* PageDown */

    /* Arrow keys — NeXT uses non-ASCII special codes */
    [0x4F] = 16,  /* Right arrow */
    [0x50] = 9,   /* Left arrow */
    [0x51] = 15,  /* Down arrow */
    [0x52] = 22,  /* Up arrow */

    [0x53] = NKC_NONE,  /* NumLock */

    /* Keypad */
    [0x54] = 40,  /* keypad / */
    [0x55] = 37,  /* keypad * */
    [0x56] = 36,  /* keypad - */
    [0x57] = 21,  /* keypad + */
    [0x58] = 13,  /* keypad Enter */
    [0x59] = 17,  /* keypad 1 */
    [0x5A] = 23,  /* keypad 2 */
    [0x5B] = 20,  /* keypad 3 */
    [0x5C] = 18,  /* keypad 4 */
    [0x5D] = 24,  /* keypad 5 */
    [0x5E] = 19,  /* keypad 6 */
    [0x5F] = 33,  /* keypad 7 */
    [0x60] = 34,  /* keypad 8 */
    [0x61] = 35,  /* keypad 9 */
    [0x62] = 11,  /* keypad 0 */
    [0x63] = 12,  /* keypad . */

    /* Above 0x63 (application, F-keys beyond F12, media keys) left as NKC_NONE
     * by the designated-init default. */
};

/* HID modifier byte bit assignments (HID boot keyboard report[0]) */
#define HID_MOD_LCTRL   (1U << 0)
#define HID_MOD_LSHIFT  (1U << 1)
#define HID_MOD_LALT    (1U << 2)
#define HID_MOD_LGUI    (1U << 3)
#define HID_MOD_RCTRL   (1U << 4)
#define HID_MOD_RSHIFT  (1U << 5)
#define HID_MOD_RALT    (1U << 6)
#define HID_MOD_RGUI    (1U << 7)

/*
 * Build a NeXT keyboard event with full modifier fidelity from an HID
 * modifier byte.  Matches the kmreg.h bit layout (MSB-first bitfields):
 *   bit 15 = valid (1)
 *   bit 14 = alt_right    (HID RAlt)
 *   bit 13 = alt_left     (HID LAlt)
 *   bit 12 = command_right (HID RGui)
 *   bit 11 = command_left  (HID LGui)
 *   bit 10 = shift_right
 *   bit 9  = shift_left
 *   bit 8  = control      (HID L/R Ctrl OR'd)
 *   bit 7  = up_down (0=DOWN, 1=UP)
 *   bits 6-0 = key_code
 */
static uint32_t build_kybd_event_hid(uint8_t key_code,
                                     uint8_t hid_mods,
                                     int key_up)
{
    uint32_t ev = 0;
    ev |= (1U << 15);                                       /* valid */
    if (hid_mods & HID_MOD_RALT)    ev |= (1U << 14);       /* alt_right */
    if (hid_mods & HID_MOD_LALT)    ev |= (1U << 13);       /* alt_left */
    if (hid_mods & HID_MOD_RGUI)    ev |= (1U << 12);       /* command_right */
    if (hid_mods & HID_MOD_LGUI)    ev |= (1U << 11);       /* command_left */
    if (hid_mods & HID_MOD_RSHIFT)  ev |= (1U << 10);       /* shift_right */
    if (hid_mods & HID_MOD_LSHIFT)  ev |= (1U <<  9);       /* shift_left */
    if (hid_mods & (HID_MOD_LCTRL | HID_MOD_RCTRL))
                                     ev |= (1U <<  8);      /* control */
    if (key_up)                      ev |= (1U <<  7);      /* up_down */
    ev |= (key_code & 0x7F);                                /* key_code */
    return ev;
}

static void hid_push_key(uint8_t hid_key, uint8_t modifiers, int key_up)
{
    if (hid_key >= HID_TABLE_SIZE) return;
    uint8_t kc = hid_to_next[hid_key];
    if (kc == NKC_NONE) {
        static int miss_log = 0;
        if (miss_log < 8) {
            xil_printf("[KMS-HID] unmapped HID key 0x%02X (dropped)\r\n", hid_key);
            miss_log++;
        }
        return;
    }
    uint32_t ev = build_kybd_event_hid(kc, modifiers, key_up);
    {
        static int push_log = 0;
        if (push_log < 16) {
            xil_printf("[KMS-HID] HID 0x%02X -> kc=%u mods=0x%02X %s ev=0x%08X\r\n",
                       hid_key, kc, modifiers, key_up ? "UP" : "DN", ev);
            push_log++;
        }
    }
    kms_queue_push(ev);
}

void next_kms_push_hid_report(const uint8_t rpt[8])
{
    static uint8_t prev[8] = {0};

    uint8_t modifiers = rpt[0];

    /* Detect newly-pressed keys: anything in rpt[2..7] not present in
     * prev[2..7] is a key-down. */
    for (int i = 2; i < 8; i++) {
        uint8_t key = rpt[i];
        if (key < 4) continue;  /* no key or rollover error */
        int was_pressed = 0;
        for (int j = 2; j < 8; j++) {
            if (prev[j] == key) { was_pressed = 1; break; }
        }
        if (!was_pressed)
            hid_push_key(key, modifiers, 0 /* KM_DOWN */);
    }

    /* Detect released keys: anything in prev[2..7] not present in rpt
     * is a key-up.  Use the PREVIOUS modifier byte for the up event so
     * release-while-modifier-still-held reports the right state. */
    for (int j = 2; j < 8; j++) {
        uint8_t key = prev[j];
        if (key < 4) continue;
        int still_pressed = 0;
        for (int i = 2; i < 8; i++) {
            if (rpt[i] == key) { still_pressed = 1; break; }
        }
        if (!still_pressed)
            hid_push_key(key, prev[0], 1 /* KM_UP */);
    }

    memcpy(prev, rpt, 8);
}

/* ------------------------------------------------------------------ */
/* Mouse event push                                                    */
/* ------------------------------------------------------------------ */
/*
 * NeXT mouse_event word layout (struct mouse in kmreg.h):
 *   bits 31-16: 0 (device address - mouse uses an odd address on the
 *               real hardware but the kernel only checks validity/format,
 *               not the address field)
 *   bits 15-9:  delta_y (7-bit signed)
 *   bit 8:      button_right
 *   bits 7-1:   delta_x (7-bit signed)
 *   bit 0:      button_left
 *
 * NeXT does not have a "valid" bit for mouse events in the struct; the
 * km driver distinguishes mouse from keyboard by the address/format
 * discipline.  To stay compatible with the existing queue (which feeds
 * both event types into the same km_data register), we set bit 15 = 1
 * in the mouse word too so the ROM's common kybd_event.valid check
 * recognises the event as valid traffic.  The kernel's mouse.c unpacks
 * the event via mouse_event.data which treats the whole 32-bit word as
 * a signed integer and extracts deltas from bits 15-9 / 7-1, so setting
 * bit 15 flips the sign bit of delta_y -- therefore we do NOT set bit 15
 * and rely on the common "poll consumed -> event delivered" handshake.
 */
static int8_t saturate7(int v)
{
    if (v >  63) return  63;
    if (v < -64) return -64;
    return (int8_t)v;
}

void next_kms_push_mouse(int8_t dx, int8_t dy, uint8_t buttons)
{
    int8_t sx = saturate7((int)dx);
    int8_t sy = saturate7((int)dy);

    uint32_t ev = 0;
    ev |= ((uint32_t)(sy & 0x7F)) << 9;                 /* delta_y */
    if (buttons & 0x02) ev |= (1U << 8);                /* button_right */
    ev |= ((uint32_t)(sx & 0x7F)) << 1;                 /* delta_x */
    if (buttons & 0x01) ev |= (1U << 0);                /* button_left */
    kms_queue_push(ev);
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
