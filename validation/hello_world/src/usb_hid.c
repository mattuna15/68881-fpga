/*
 * usb_hid.c
 * Minimal USB HID keyboard driver for ZynqMP DWC3 xHCI host.
 *
 * This is a bare-metal, polling-only driver.  It puts the DWC3
 * into host mode, sets up minimal xHCI data structures, enumerates
 * through one level of USB hub if present, finds an HID keyboard,
 * and polls the interrupt endpoint for boot-protocol key reports.
 *
 * Limitations:
 *  - One hub level (typical for keyboards with built-in hub)
 *  - Single HID keyboard (boot protocol)
 *  - Polling only (no interrupts)
 *  - USB 2.0 speeds only (HS/FS/LS)
 */

#include "usb_hid.h"
#include "mfp_emu.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include <string.h>

/* ------------------------------------------------------------------ */
/* DWC3 / xHCI register addresses                                     */
/* ------------------------------------------------------------------ */

#define DWC3_BASE           0xFE200000U

/* DWC3 global registers (offsets from DWC3_BASE) */
#define DWC3_GCTL           0xC110U
#define DWC3_GSNPSID        0xC120U
#define DWC3_GUSB2PHYCFG0   0xC200U
#define DWC3_GUSB3PIPECTL0  0xC2C0U

/* DWC3 GCTL bit fields */
#define GCTL_CORESOFTRESET  (1U << 11)
#define GCTL_PRTCAP_SHIFT   12
#define GCTL_PRTCAP_MASK    (3U << GCTL_PRTCAP_SHIFT)
#define GCTL_PRTCAP_HOST    (1U << GCTL_PRTCAP_SHIFT)

/* DWC3 USB2 PHY config */
#define GUSB2PHYCFG_PHYSOFTRST  (1U << 31)
#define GUSB2PHYCFG_SUSPHY      (1U << 6)

/* DWC3 USB3 PIPE control */
#define GUSB3PIPECTL_PHYSOFTRST (1U << 31)
#define GUSB3PIPECTL_SUSPHY     (1U << 17)

/* ------------------------------------------------------------------ */
/* xHCI registers (at DWC3_BASE when in host mode)                    */
/* ------------------------------------------------------------------ */

/* Capability registers */
#define XHCI_CAPLENGTH      0x00U
#define XHCI_HCSPARAMS1     0x04U
#define XHCI_HCSPARAMS2     0x08U
#define XHCI_HCCPARAMS1     0x10U
#define XHCI_DBOFF          0x14U
#define XHCI_RTSOFF         0x18U

/* Operational registers (at base + cap_length) */
#define XHCI_OP_USBCMD     0x00U
#define XHCI_OP_USBSTS     0x04U
#define XHCI_OP_CRCR_LO    0x18U
#define XHCI_OP_DCBAAP_LO  0x30U
#define XHCI_OP_CONFIG     0x38U

/* Port register set (at op_base + 0x400 + port_index * 0x10) */
#define XHCI_OP_PORTS      0x400U
#define XHCI_PORTSC        0x00U

/* USBCMD bits */
#define USBCMD_RUN          (1U << 0)
#define USBCMD_HCRST        (1U << 1)
#define USBCMD_INTE         (1U << 2)

/* USBSTS bits */
#define USBSTS_HCH          (1U << 0)
#define USBSTS_CNR          (1U << 11)
#define USBSTS_EINT         (1U << 3)

/* PORTSC bits */
#define PORTSC_CCS          (1U << 0)
#define PORTSC_PED          (1U << 1)
#define PORTSC_PR           (1U << 4)
#define PORTSC_PP           (1U << 9)
#define PORTSC_SPEED_MASK   (0xFU << 10)
#define PORTSC_SPEED_SHIFT  10
#define PORTSC_CSC          (1U << 17)
#define PORTSC_PRC          (1U << 21)
#define PORTSC_WRC          (1U << 19)
/* All RW1C bits in PORTSC */
#define PORTSC_RW1C_MASK    (PORTSC_CSC | (1U<<18) | PORTSC_WRC | (1U<<20) | \
                             PORTSC_PRC | (1U<<22) | (1U<<23))

/* Port speed values (from PORTSC bits 13:10) */
#define PORT_SPEED_FS       1U
#define PORT_SPEED_LS       2U
#define PORT_SPEED_HS       3U
#define PORT_SPEED_SS       4U

/* Runtime register set (at base + rts_off) */
#define XHCI_RT_IMAN(n)    (0x20U + (n) * 0x20U)
#define XHCI_RT_ERSTSZ(n)  (0x28U + (n) * 0x20U)
#define XHCI_RT_ERSTBA_LO(n) (0x30U + (n) * 0x20U)
#define XHCI_RT_ERDP_LO(n) (0x38U + (n) * 0x20U)

/* ------------------------------------------------------------------ */
/* xHCI TRB definitions                                               */
/* ------------------------------------------------------------------ */

#define TRB_TYPE_SHIFT      10
#define TRB_TYPE(t)         ((t) << TRB_TYPE_SHIFT)

#define TRB_NORMAL          1
#define TRB_SETUP           2
#define TRB_DATA            3
#define TRB_STATUS          4
#define TRB_LINK            6
#define TRB_ENABLE_SLOT     9
#define TRB_ADDRESS_DEV     11
#define TRB_CONFIG_EP       12
#define TRB_EVAL_CTX        13
#define TRB_CMD_COMPLETE    33
#define TRB_TRANSFER_EVT    32
#define TRB_PORT_STATUS     34

/* TRB control bits */
#define TRB_CYCLE           (1U << 0)
#define TRB_TC              (1U << 1)
#define TRB_ISP             (1U << 2)
#define TRB_IOC             (1U << 5)
#define TRB_IDT             (1U << 6)
#define TRB_BSR             (1U << 9)
#define TRB_DIR_IN          (1U << 16)
#define TRB_TRT_IN          (3U << 16)
#define TRB_TRT_OUT         (2U << 16)
#define TRB_TRT_NODATA      (0U << 16)

/* TRB completion codes */
#define TRB_COMP_SUCCESS    1
#define TRB_COMP_SHORT_PKT  13

/* ------------------------------------------------------------------ */
/* USB descriptor types and requests                                  */
/* ------------------------------------------------------------------ */

#define USB_DT_DEVICE       1
#define USB_DT_CONFIG       2
#define USB_DT_INTERFACE    4
#define USB_DT_ENDPOINT     5
#define USB_DT_HUB          0x29
#define USB_DT_SS_HUB       0x2A

#define USB_REQ_GET_DESC    6
#define USB_REQ_SET_CONFIG  9
#define USB_REQ_SET_IFACE   11
#define USB_REQ_SET_PROTO   0x0B
#define USB_REQ_GET_STATUS  0
#define USB_REQ_SET_FEATURE 3
#define USB_REQ_CLEAR_FEATURE 1

#define USB_CLASS_HUB       9
#define USB_CLASS_HID       3
#define USB_SUBCLASS_BOOT   1
#define USB_PROTOCOL_KBD    1

#define USB_DIR_IN          0x80
#define USB_DIR_OUT         0x00
#define USB_TYPE_STANDARD   0x00
#define USB_TYPE_CLASS      0x20
#define USB_RECIP_DEVICE    0x00
#define USB_RECIP_IFACE     0x01
#define USB_RECIP_OTHER     0x03

/* Hub class-specific feature selectors */
#define HUB_FEAT_PORT_POWER     8
#define HUB_FEAT_PORT_RESET     4
#define HUB_FEAT_C_PORT_CONNECTION 16
#define HUB_FEAT_C_PORT_RESET   20

/* Hub port status bits */
#define HUB_PORT_CONNECTION (1U << 0)
#define HUB_PORT_ENABLE     (1U << 1)
#define HUB_PORT_RESET_BIT  (1U << 4)
#define HUB_PORT_POWER_BIT  (1U << 8)
#define HUB_PORT_LS_MASK    (3U << 9)
#define HUB_PORT_LS_SHIFT   9
/* Hub port status change bits (upper 16 bits of GET_STATUS) */
#define HUB_C_PORT_CONNECTION (1U << 0)
#define HUB_C_PORT_RESET     (1U << 4)

/* HID boot protocol */
#define HID_PROTO_BOOT      0

/* ------------------------------------------------------------------ */
/* Data structure types                                               */
/* ------------------------------------------------------------------ */

typedef struct __attribute__((aligned(16))) {
    uint32_t field[4];
} xhci_trb_t;

typedef struct __attribute__((aligned(64))) {
    uint32_t drop_flags;
    uint32_t add_flags;
    uint32_t rsvd[6];
} xhci_input_ctrl_ctx_t;

typedef struct __attribute__((aligned(64))) {
    uint32_t addr_lo;
    uint32_t addr_hi;
    uint32_t size;
    uint32_t rsvd;
} xhci_erst_entry_t;

/* ------------------------------------------------------------------ */
/* Static DMA buffers                                                 */
/* ------------------------------------------------------------------ */

#define CMD_RING_SIZE   64
#define EVT_RING_SIZE   64
#define EP0_RING_SIZE   64
#define XFER_RING_SIZE  16
#define MAX_SLOTS       4       /* hub + up to 3 downstream */

static xhci_trb_t cmd_ring[CMD_RING_SIZE]   __attribute__((aligned(64)));
static xhci_trb_t evt_ring[EVT_RING_SIZE]   __attribute__((aligned(64)));
static xhci_trb_t xfer_ring[XFER_RING_SIZE] __attribute__((aligned(64)));

/* Per-slot EP0 transfer rings and output contexts */
static xhci_trb_t ep0_rings[MAX_SLOTS][EP0_RING_SIZE] __attribute__((aligned(64)));
static uint8_t dev_out_ctxs[MAX_SLOTS][2048] __attribute__((aligned(64)));

/* DCBAA: entry 0 = scratchpad, entries 1..MAX_SLOTS = device contexts */
static uint64_t dcbaa[MAX_SLOTS + 1] __attribute__((aligned(64)));

/* Input context (shared, used one command at a time) */
static uint8_t input_ctx[2112] __attribute__((aligned(64)));

/* Scratchpad */
static uint8_t scratchpad_buf[4096] __attribute__((aligned(4096)));
static uint64_t scratchpad_array[1] __attribute__((aligned(64)));

static xhci_erst_entry_t erst[1] __attribute__((aligned(64)));
static uint8_t data_buf[512] __attribute__((aligned(64)));
static uint8_t hid_report[64] __attribute__((aligned(64)));

/* ------------------------------------------------------------------ */
/* Per-slot state                                                     */
/* ------------------------------------------------------------------ */

typedef struct {
    uint32_t    ep0_enq;
    uint32_t    ep0_cycle;
    uint32_t    speed;
} slot_state_t;

/* ------------------------------------------------------------------ */
/* Driver state                                                       */
/* ------------------------------------------------------------------ */

static struct {
    uintptr_t   cap_base;
    uintptr_t   op_base;
    uintptr_t   rt_base;
    uintptr_t   db_base;
    uint32_t    ctx_size;       /* 32 or 64 (from HCCPARAMS1 CSZ) */

    uint32_t    cmd_enq;
    uint32_t    cmd_cycle;
    uint32_t    evt_deq;
    uint32_t    evt_cycle;
    uint32_t    xfer_enq;
    uint32_t    xfer_cycle;

    slot_state_t slots[MAX_SLOTS + 1]; /* indexed by slot_id (1-based) */

    /* Root hub port where we found a device */
    uint32_t    root_port;
    uint32_t    root_speed;

    /* Keyboard state */
    uint32_t    kbd_slot;       /* xHCI slot for the keyboard */
    uint8_t     ep_in_dci;
    uint16_t    ep_in_maxpkt;
    uint8_t     ep_in_interval;

    uint8_t     prev_keys[6];
    uint8_t     prev_modifiers;

    /* Lock key state */
    uint8_t     caps_lock;
    uint8_t     num_lock;
    uint8_t     leds;           /* current LED state sent to keyboard */
    uint8_t     leds_dirty;     /* need to send SET_REPORT for LEDs */

    int         initialized;
} usb;

/* ------------------------------------------------------------------ */
/* Low-level register access                                          */
/* ------------------------------------------------------------------ */

static inline void reg_write32(uintptr_t addr, uint32_t val)
{
    *(volatile uint32_t *)addr = val;
}

static inline uint32_t reg_read32(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}

static inline void reg_write64(uintptr_t addr, uint64_t val)
{
    *(volatile uint32_t *)addr = (uint32_t)val;
    *(volatile uint32_t *)(addr + 4) = (uint32_t)(val >> 32);
}

static inline uint8_t reg_read8(uintptr_t addr)
{
    return *(volatile uint8_t *)addr;
}

static void delay_ms(uint32_t ms)
{
    volatile uint32_t count = ms * 120000U;
    while (count--) ;
}

static void flush_cache(void *addr, uint32_t len)
{
    Xil_DCacheFlushRange((UINTPTR)addr, len);
}

static void invalidate_cache(void *addr, uint32_t len)
{
    Xil_DCacheInvalidateRange((UINTPTR)addr, len);
}

/* ------------------------------------------------------------------ */
/* DWC3 host mode initialization                                      */
/* ------------------------------------------------------------------ */

static int dwc3_host_init(void)
{
    uint32_t reg;

    xil_printf("[USB] DWC3 host mode init @ 0x%08X\r\n", DWC3_BASE);

    reg = reg_read32(DWC3_BASE + DWC3_GSNPSID);
    (void)reg; /* SNPSID read to verify DWC3 accessible */

    /* Soft reset */
    reg = reg_read32(DWC3_BASE + DWC3_GCTL);
    reg |= GCTL_CORESOFTRESET;
    reg_write32(DWC3_BASE + DWC3_GCTL, reg);

    reg = reg_read32(DWC3_BASE + DWC3_GUSB2PHYCFG0);
    reg |= GUSB2PHYCFG_PHYSOFTRST;
    reg_write32(DWC3_BASE + DWC3_GUSB2PHYCFG0, reg);

    reg = reg_read32(DWC3_BASE + DWC3_GUSB3PIPECTL0);
    reg |= GUSB3PIPECTL_PHYSOFTRST;
    reg_write32(DWC3_BASE + DWC3_GUSB3PIPECTL0, reg);

    delay_ms(100);

    /* Deassert PHY resets */
    reg = reg_read32(DWC3_BASE + DWC3_GUSB2PHYCFG0);
    reg &= ~GUSB2PHYCFG_PHYSOFTRST;
    reg_write32(DWC3_BASE + DWC3_GUSB2PHYCFG0, reg);

    reg = reg_read32(DWC3_BASE + DWC3_GUSB3PIPECTL0);
    reg &= ~GUSB3PIPECTL_PHYSOFTRST;
    reg_write32(DWC3_BASE + DWC3_GUSB3PIPECTL0, reg);

    delay_ms(50);

    /* Deassert core reset */
    reg = reg_read32(DWC3_BASE + DWC3_GCTL);
    reg &= ~GCTL_CORESOFTRESET;
    reg_write32(DWC3_BASE + DWC3_GCTL, reg);

    delay_ms(50);

    /* Set PRTCAP to HOST */
    reg = reg_read32(DWC3_BASE + DWC3_GCTL);
    reg &= ~GCTL_PRTCAP_MASK;
    reg |= GCTL_PRTCAP_HOST;
    reg_write32(DWC3_BASE + DWC3_GCTL, reg);

    /* Disable PHY suspend */
    reg = reg_read32(DWC3_BASE + DWC3_GUSB2PHYCFG0);
    reg &= ~GUSB2PHYCFG_SUSPHY;
    reg_write32(DWC3_BASE + DWC3_GUSB2PHYCFG0, reg);

    reg = reg_read32(DWC3_BASE + DWC3_GUSB3PIPECTL0);
    reg &= ~GUSB3PIPECTL_SUSPHY;
    reg_write32(DWC3_BASE + DWC3_GUSB3PIPECTL0, reg);

    delay_ms(50);
    xil_printf("[USB] DWC3 set to HOST mode\r\n");
    return 0;
}

/* ------------------------------------------------------------------ */
/* Ring helpers                                                       */
/* ------------------------------------------------------------------ */

static void init_ring_with_link(xhci_trb_t *ring, int size)
{
    memset(ring, 0, size * sizeof(xhci_trb_t));
    ring[size - 1].field[0] = (uint32_t)(uintptr_t)ring;
    ring[size - 1].field[1] = 0;
    ring[size - 1].field[2] = 0;
    ring[size - 1].field[3] = TRB_TYPE(TRB_LINK) | TRB_TC | TRB_CYCLE;
}

static void ring_enqueue(xhci_trb_t *ring, int ring_size,
                         uint32_t *enq, uint32_t *cycle,
                         uint32_t f0, uint32_t f1, uint32_t f2, uint32_t f3)
{
    uint32_t idx = *enq;

    if (*cycle)
        f3 |= TRB_CYCLE;
    else
        f3 &= ~TRB_CYCLE;

    ring[idx].field[0] = f0;
    ring[idx].field[1] = f1;
    ring[idx].field[2] = f2;
    ring[idx].field[3] = f3;
    flush_cache(&ring[idx], sizeof(xhci_trb_t));

    (*enq)++;
    if (*enq >= (uint32_t)(ring_size - 1)) {
        uint32_t link_f3 = TRB_TYPE(TRB_LINK) | TRB_TC;
        if (*cycle)
            link_f3 |= TRB_CYCLE;
        else
            link_f3 &= ~TRB_CYCLE;
        ring[ring_size - 1].field[3] = link_f3;
        flush_cache(&ring[ring_size - 1], sizeof(xhci_trb_t));
        *enq = 0;
        *cycle ^= 1;
    }
}

static void cmd_ring_enqueue(uint32_t f0, uint32_t f1, uint32_t f2, uint32_t f3)
{
    ring_enqueue(cmd_ring, CMD_RING_SIZE,
                 &usb.cmd_enq, &usb.cmd_cycle, f0, f1, f2, f3);
}

static void ep0_enqueue(uint32_t slot_id, uint32_t f0, uint32_t f1, uint32_t f2, uint32_t f3)
{
    slot_state_t *s = &usb.slots[slot_id];
    ring_enqueue(ep0_rings[slot_id - 1], EP0_RING_SIZE,
                 &s->ep0_enq, &s->ep0_cycle, f0, f1, f2, f3);
}

static void ring_doorbell(uint32_t slot, uint32_t target)
{
    reg_write32(usb.db_base + slot * 4, target);
}

/* ------------------------------------------------------------------ */
/* Event ring                                                         */
/* ------------------------------------------------------------------ */

static int wait_event(xhci_trb_t *out, int timeout_ms)
{
    int elapsed = 0;
    while (elapsed < timeout_ms) {
        invalidate_cache(&evt_ring[usb.evt_deq], sizeof(xhci_trb_t));
        uint32_t f3 = evt_ring[usb.evt_deq].field[3];
        if ((f3 & TRB_CYCLE) == (usb.evt_cycle ? 1U : 0U)) {
            if (out) {
                out->field[0] = evt_ring[usb.evt_deq].field[0];
                out->field[1] = evt_ring[usb.evt_deq].field[1];
                out->field[2] = evt_ring[usb.evt_deq].field[2];
                out->field[3] = f3;
            }
            usb.evt_deq++;
            if (usb.evt_deq >= EVT_RING_SIZE) {
                usb.evt_deq = 0;
                usb.evt_cycle ^= 1;
            }
            reg_write64(usb.rt_base + XHCI_RT_ERDP_LO(0),
                        (uintptr_t)&evt_ring[usb.evt_deq] | (1U << 3));
            reg_write32(usb.op_base + XHCI_OP_USBSTS, USBSTS_EINT);
            return 0;
        }
        delay_ms(1);
        elapsed++;
    }
    return -1;
}

static void drain_events(int ms)
{
    xhci_trb_t evt;
    while (wait_event(&evt, ms) == 0)
        ;
}

/* Wait for command completion, skipping port status change events */
static int wait_cmd_complete(uint32_t *slot_id_out)
{
    xhci_trb_t evt;
    for (;;) {
        if (wait_event(&evt, 2000) < 0) {
            xil_printf("[USB] ERROR: command timeout\r\n");
            return -1;
        }
        uint32_t trb_type = (evt.field[3] >> TRB_TYPE_SHIFT) & 0x3FU;
        if (trb_type == TRB_PORT_STATUS)
            continue;
        if (trb_type != TRB_CMD_COMPLETE) {
            xil_printf("[USB] unexpected event type %u\r\n", trb_type);
            return -1;
        }
        uint32_t comp = (evt.field[2] >> 24) & 0xFFU;
        if (slot_id_out)
            *slot_id_out = (evt.field[3] >> 24) & 0xFFU;
        if (comp != TRB_COMP_SUCCESS) {
            xil_printf("[USB] Command completion code: %u\r\n", comp);
            return -(int)comp;
        }
        return 0;
    }
}

/* Wait for transfer completion, skipping port status change events */
static int wait_transfer(void)
{
    xhci_trb_t evt;
    for (;;) {
        if (wait_event(&evt, 5000) < 0) {
            xil_printf("[USB] ERROR: transfer timeout\r\n");
            return -1;
        }
        uint32_t trb_type = (evt.field[3] >> TRB_TYPE_SHIFT) & 0x3FU;
        if (trb_type == TRB_PORT_STATUS)
            continue;
        if (trb_type != TRB_TRANSFER_EVT) {
            xil_printf("[USB] unexpected event type %u (expected xfer)\r\n", trb_type);
            return -1;
        }
        uint32_t comp = (evt.field[2] >> 24) & 0xFFU;
        if (comp != TRB_COMP_SUCCESS && comp != TRB_COMP_SHORT_PKT) {
            xil_printf("[USB] Transfer completion code: %u\r\n", comp);
            return -(int)comp;
        }
        return 0;
    }
}

/* ------------------------------------------------------------------ */
/* xHCI initialization                                                */
/* ------------------------------------------------------------------ */

static int xhci_init(void)
{
    uint32_t reg, cap_len, rts_off, db_off;
    uint32_t hcsparams1, hcsparams2, hccparams1;
    uint32_t max_scratchpad;
    int timeout;

    usb.cap_base = DWC3_BASE;
    cap_len = reg_read8(usb.cap_base + XHCI_CAPLENGTH);
    hcsparams1 = reg_read32(usb.cap_base + XHCI_HCSPARAMS1);
    hcsparams2 = reg_read32(usb.cap_base + XHCI_HCSPARAMS2);
    hccparams1 = reg_read32(usb.cap_base + XHCI_HCCPARAMS1);
    rts_off = reg_read32(usb.cap_base + XHCI_RTSOFF) & ~0x1FU;
    db_off = reg_read32(usb.cap_base + XHCI_DBOFF) & ~0x3U;

    usb.op_base = usb.cap_base + cap_len;
    usb.rt_base = usb.cap_base + rts_off;
    usb.db_base = usb.cap_base + db_off;
    usb.ctx_size = (hccparams1 & (1U << 2)) ? 64 : 32;

    max_scratchpad = ((hcsparams2 >> 27) & 0x1FU) | (((hcsparams2 >> 21) & 0x1FU) << 5);

    (void)hcsparams1; /* used for CSZ extraction above */

    /* Wait for CNR to clear */
    timeout = 500;
    while ((reg_read32(usb.op_base + XHCI_OP_USBSTS) & USBSTS_CNR) && timeout-- > 0)
        delay_ms(1);
    if (timeout <= 0) return -1;

    /* Halt if running */
    reg = reg_read32(usb.op_base + XHCI_OP_USBCMD);
    if (reg & USBCMD_RUN) {
        reg &= ~USBCMD_RUN;
        reg_write32(usb.op_base + XHCI_OP_USBCMD, reg);
        timeout = 100;
        while (!(reg_read32(usb.op_base + XHCI_OP_USBSTS) & USBSTS_HCH) && timeout-- > 0)
            delay_ms(1);
    }

    /* Reset */
    reg_write32(usb.op_base + XHCI_OP_USBCMD,
                reg_read32(usb.op_base + XHCI_OP_USBCMD) | USBCMD_HCRST);
    timeout = 500;
    while ((reg_read32(usb.op_base + XHCI_OP_USBCMD) & USBCMD_HCRST) && timeout-- > 0)
        delay_ms(1);
    timeout = 500;
    while ((reg_read32(usb.op_base + XHCI_OP_USBSTS) & USBSTS_CNR) && timeout-- > 0)
        delay_ms(1);

    xil_printf("[USB] xHCI reset complete\r\n");

    /* Max device slots */
    reg_write32(usb.op_base + XHCI_OP_CONFIG, MAX_SLOTS);

    /* Zero everything */
    memset(dcbaa, 0, sizeof(dcbaa));
    memset(dev_out_ctxs, 0, sizeof(dev_out_ctxs));
    memset(input_ctx, 0, sizeof(input_ctx));
    memset(cmd_ring, 0, sizeof(cmd_ring));
    memset(evt_ring, 0, sizeof(evt_ring));
    memset(xfer_ring, 0, sizeof(xfer_ring));
    memset(ep0_rings, 0, sizeof(ep0_rings));
    memset(erst, 0, sizeof(erst));

    /* Scratchpad */
    if (max_scratchpad > 0) {
        memset(scratchpad_buf, 0, sizeof(scratchpad_buf));
        scratchpad_array[0] = (uintptr_t)scratchpad_buf;
        flush_cache(scratchpad_array, sizeof(scratchpad_array));
        flush_cache(scratchpad_buf, sizeof(scratchpad_buf));
        dcbaa[0] = (uintptr_t)scratchpad_array;
    }
    flush_cache(dcbaa, sizeof(dcbaa));
    reg_write64(usb.op_base + XHCI_OP_DCBAAP_LO, (uintptr_t)dcbaa);

    /* Command ring */
    usb.cmd_enq = 0;
    usb.cmd_cycle = 1;
    init_ring_with_link(cmd_ring, CMD_RING_SIZE);
    flush_cache(cmd_ring, sizeof(cmd_ring));
    reg_write64(usb.op_base + XHCI_OP_CRCR_LO, (uintptr_t)cmd_ring | 1U);

    /* Event ring */
    usb.evt_deq = 0;
    usb.evt_cycle = 1;
    erst[0].addr_lo = (uint32_t)(uintptr_t)evt_ring;
    erst[0].addr_hi = 0;
    erst[0].size = EVT_RING_SIZE;
    erst[0].rsvd = 0;
    flush_cache(erst, sizeof(erst));
    flush_cache(evt_ring, sizeof(evt_ring));

    reg_write32(usb.rt_base + XHCI_RT_ERSTSZ(0), 1);
    reg_write64(usb.rt_base + XHCI_RT_ERDP_LO(0), (uintptr_t)evt_ring);
    reg_write64(usb.rt_base + XHCI_RT_ERSTBA_LO(0), (uintptr_t)erst);
    reg_write32(usb.rt_base + XHCI_RT_IMAN(0), 0x2);

    /* EP0 rings for all possible slots */
    for (int i = 0; i < MAX_SLOTS; i++) {
        init_ring_with_link(ep0_rings[i], EP0_RING_SIZE);
        flush_cache(ep0_rings[i], sizeof(ep0_rings[i]));
        usb.slots[i + 1].ep0_enq = 0;
        usb.slots[i + 1].ep0_cycle = 1;
    }

    /* Interrupt endpoint transfer ring */
    usb.xfer_enq = 0;
    usb.xfer_cycle = 1;
    init_ring_with_link(xfer_ring, XFER_RING_SIZE);
    flush_cache(xfer_ring, sizeof(xfer_ring));

    /* Start controller */
    reg = reg_read32(usb.op_base + XHCI_OP_USBCMD);
    reg |= USBCMD_RUN | USBCMD_INTE;
    reg_write32(usb.op_base + XHCI_OP_USBCMD, reg);
    delay_ms(10);

    if (reg_read32(usb.op_base + XHCI_OP_USBSTS) & USBSTS_HCH) {
        xil_printf("[USB] ERROR: xHCI failed to start\r\n");
        return -1;
    }

    xil_printf("[USB] xHCI host controller running\r\n");
    return 0;
}

/* ------------------------------------------------------------------ */
/* USB control transfer (for a given slot)                            */
/* ------------------------------------------------------------------ */

static int usb_control_transfer(uint32_t slot_id,
                                uint8_t bmRequestType, uint8_t bRequest,
                                uint16_t wValue, uint16_t wIndex,
                                uint16_t wLength, void *data)
{
    uint32_t setup_lo = bmRequestType | (bRequest << 8) | (wValue << 16);
    uint32_t setup_hi = wIndex | (wLength << 16);
    int has_data = (wLength > 0);
    int dir_in = (bmRequestType & USB_DIR_IN) != 0;

    /* Setup TRB */
    uint32_t setup_flags = TRB_TYPE(TRB_SETUP) | TRB_IDT;
    if (has_data)
        setup_flags |= dir_in ? TRB_TRT_IN : TRB_TRT_OUT;

    ep0_enqueue(slot_id, setup_lo, setup_hi, 8, setup_flags);

    /* Data TRB */
    if (has_data && data) {
        if (!dir_in) {
            memcpy(data_buf, data, wLength);
            flush_cache(data_buf, wLength);
        } else {
            memset(data_buf, 0, wLength);
            flush_cache(data_buf, wLength);
        }
        uint32_t data_flags = TRB_TYPE(TRB_DATA);
        if (dir_in) data_flags |= TRB_DIR_IN;
        ep0_enqueue(slot_id, (uint32_t)(uintptr_t)data_buf, 0, wLength, data_flags);
    }

    /* Status TRB */
    uint32_t status_flags = TRB_TYPE(TRB_STATUS) | TRB_IOC;
    if (!has_data || !dir_in)
        status_flags |= TRB_DIR_IN;
    ep0_enqueue(slot_id, 0, 0, 0, status_flags);

    /* Ring doorbell for EP0 (DCI=1) */
    ring_doorbell(slot_id, 1);

    int ret = wait_transfer();
    if (ret < 0) return ret;

    if (has_data && dir_in && data) {
        invalidate_cache(data_buf, wLength);
        memcpy(data, data_buf, wLength);
    }
    return 0;
}

/* ------------------------------------------------------------------ */
/* Slot enable + address device                                       */
/* ------------------------------------------------------------------ */

static uint32_t ep0_max_packet(uint32_t speed)
{
    switch (speed) {
    case PORT_SPEED_SS: return 512;
    case PORT_SPEED_HS: return 64;
    case PORT_SPEED_FS: return 64;
    case PORT_SPEED_LS: return 8;
    default:            return 64;
    }
}

static int enable_slot(uint32_t *slot_id_out)
{
    cmd_ring_enqueue(0, 0, 0, TRB_TYPE(TRB_ENABLE_SLOT));
    ring_doorbell(0, 0);
    int ret = wait_cmd_complete(slot_id_out);
    if (ret < 0)
        xil_printf("[USB] Enable Slot failed (%d)\r\n", ret);
    else
        xil_printf("[USB] Slot %u enabled\r\n", *slot_id_out);
    return ret;
}

/*
 * address_device — issue Address Device command for a slot.
 *
 * parent_slot = 0 for root-hub-connected devices.
 * parent_port = the hub port number for downstream devices.
 * route_string = USB 3.0 route string (0 for root hub direct).
 */
static int address_device(uint32_t slot_id, uint32_t speed,
                          uint32_t root_port,
                          uint32_t parent_slot, uint32_t parent_port,
                          uint32_t route_string)
{
    uint32_t csz = usb.ctx_size;
    uint32_t maxp = ep0_max_packet(speed);

    memset(input_ctx, 0, sizeof(input_ctx));

    /* Input control context */
    xhci_input_ctrl_ctx_t *ctrl = (xhci_input_ctrl_ctx_t *)input_ctx;
    ctrl->add_flags = (1U << 0) | (1U << 1); /* add Slot + EP0 */

    /* Slot context */
    uint32_t *slot = (uint32_t *)(input_ctx + csz);
    slot[0] = (speed << 20) | (1U << 27) | (route_string & 0xFFFFFU);
    /* Dword 1: [31:24] = Number of Ports (0, not a hub yet),
     *          [23:16] = Root Hub Port Number,
     *          [15:0]  = Max Exit Latency (0) */
    slot[1] = (root_port << 16);

    /* If behind a hub, set TT fields in slot context dword 2:
     *   [7:0]   = TT Hub Slot ID (nearest HS hub ancestor)
     *   [15:8]  = TT Port Number (port on that HS hub)
     *   [31:16] = Interrupter Target (0) */
    if (parent_slot != 0) {
        slot[2] = (parent_slot & 0xFF) | ((parent_port & 0xFF) << 8);
    }

    /* EP0 context */
    uint32_t *ep0 = (uint32_t *)(input_ctx + csz * 2);
    ep0[1] = (4U << 3) | (maxp << 16) | (3U << 1); /* CErr=3, EPType=Control, MaxPkt */
    ep0[2] = (uint32_t)(uintptr_t)ep0_rings[slot_id - 1] | 1U; /* TR deq ptr + DCS */
    ep0[3] = 0;
    ep0[4] = 8; /* Average TRB length */

    flush_cache(input_ctx, sizeof(input_ctx));

    /* Set up output context in DCBAA */
    memset(dev_out_ctxs[slot_id - 1], 0, sizeof(dev_out_ctxs[0]));
    flush_cache(dev_out_ctxs[slot_id - 1], sizeof(dev_out_ctxs[0]));
    dcbaa[slot_id] = (uintptr_t)dev_out_ctxs[slot_id - 1];
    flush_cache(dcbaa, sizeof(dcbaa));

    usb.slots[slot_id].speed = speed;

    xil_printf("[USB] Address Device slot=%u speed=%u\r\n", slot_id, speed);

    cmd_ring_enqueue((uint32_t)(uintptr_t)input_ctx, 0, 0,
                     TRB_TYPE(TRB_ADDRESS_DEV) | (slot_id << 24));
    ring_doorbell(0, 0);

    int ret = wait_cmd_complete(NULL);
    if (ret < 0) {
        xil_printf("[USB] Address Device failed (%d)\r\n", ret);
        return ret;
    }
    xil_printf("[USB] Device addressed (slot %u)\r\n", slot_id);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Root hub port wait and reset                                       */
/* ------------------------------------------------------------------ */

static int wait_for_device(void)
{
    uint32_t portsc;
    int timeout, port;

    xil_printf("[USB] Waiting for device connection...\r\n");

    timeout = 3000;
    while (timeout > 0) {
        for (port = 1; port <= 2; port++) {
            portsc = reg_read32(usb.op_base + XHCI_OP_PORTS + (port - 1) * 0x10);
            if (portsc & PORTSC_CCS) {
                usb.root_port = port;
                goto connected;
            }
        }
        delay_ms(10);
        timeout -= 10;
    }
    xil_printf("[USB] No device detected\r\n");
    return -1;

connected:
    xil_printf("[USB] Device on port %d\r\n", usb.root_port);
    drain_events(50);

    /* Port reset */
    portsc = reg_read32(usb.op_base + XHCI_OP_PORTS + (usb.root_port - 1) * 0x10);
    portsc &= ~(PORTSC_RW1C_MASK | PORTSC_PED);
    portsc |= PORTSC_PR;
    reg_write32(usb.op_base + XHCI_OP_PORTS + (usb.root_port - 1) * 0x10, portsc);

    delay_ms(60);

    timeout = 500;
    while (timeout > 0) {
        portsc = reg_read32(usb.op_base + XHCI_OP_PORTS + (usb.root_port - 1) * 0x10);
        if (portsc & PORTSC_PRC) break;
        delay_ms(1);
        timeout--;
    }
    if (timeout <= 0) {
        xil_printf("[USB] Port reset timeout\r\n");
        return -1;
    }

    /* Clear PRC */
    portsc = reg_read32(usb.op_base + XHCI_OP_PORTS + (usb.root_port - 1) * 0x10);
    portsc &= ~(PORTSC_RW1C_MASK | PORTSC_PED);
    portsc |= PORTSC_PRC;
    reg_write32(usb.op_base + XHCI_OP_PORTS + (usb.root_port - 1) * 0x10, portsc);

    delay_ms(10);

    portsc = reg_read32(usb.op_base + XHCI_OP_PORTS + (usb.root_port - 1) * 0x10);
    usb.root_speed = (portsc & PORTSC_SPEED_MASK) >> PORTSC_SPEED_SHIFT;

    static const char *speed_names[] = {"?", "FS", "LS", "HS", "SS"};
    const char *sp = (usb.root_speed <= 4) ? speed_names[usb.root_speed] : "??";
    xil_printf("[USB] Port %u: speed=%s\r\n", usb.root_port, sp);

    if (!(portsc & PORTSC_PED)) {
        timeout = 500;
        while (timeout > 0) {
            portsc = reg_read32(usb.op_base + XHCI_OP_PORTS + (usb.root_port - 1) * 0x10);
            if (portsc & PORTSC_PED) break;
            delay_ms(1);
            timeout--;
        }
        if (!(portsc & PORTSC_PED)) {
            xil_printf("[USB] Port never enabled\r\n");
            return -1;
        }
        usb.root_speed = (portsc & PORTSC_SPEED_MASK) >> PORTSC_SPEED_SHIFT;
    }

    drain_events(100);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Hub support                                                        */
/* ------------------------------------------------------------------ */

static int hub_get_port_status(uint32_t slot_id, uint32_t port, uint32_t *status_out)
{
    uint8_t buf[4];
    int ret = usb_control_transfer(slot_id,
        USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_OTHER,
        USB_REQ_GET_STATUS, 0, port, 4, buf);
    if (ret < 0) return ret;
    *status_out = buf[0] | (buf[1] << 8) | (buf[2] << 16) | (buf[3] << 24);
    return 0;
}

static int hub_set_feature(uint32_t slot_id, uint32_t port, uint16_t feature)
{
    return usb_control_transfer(slot_id,
        USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_OTHER,
        USB_REQ_SET_FEATURE, feature, port, 0, NULL);
}

static int hub_clear_feature(uint32_t slot_id, uint32_t port, uint16_t feature)
{
    return usb_control_transfer(slot_id,
        USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_OTHER,
        USB_REQ_CLEAR_FEATURE, feature, port, 0, NULL);
}

static int hub_init(uint32_t slot_id, uint8_t *config_desc,
                    uint32_t *num_ports_out)
{
    int ret;
    uint8_t hub_desc[16];

    /* SET_CONFIGURATION */
    uint8_t config_val = config_desc[5];
    ret = usb_control_transfer(slot_id,
        USB_DIR_OUT | USB_TYPE_STANDARD | USB_RECIP_DEVICE,
        USB_REQ_SET_CONFIG, config_val, 0, 0, NULL);
    if (ret < 0) return ret;

    /* Get hub descriptor */
    memset(hub_desc, 0, sizeof(hub_desc));
    ret = usb_control_transfer(slot_id,
        USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_DEVICE,
        USB_REQ_GET_DESC, (USB_DT_HUB << 8) | 0, 0, sizeof(hub_desc), hub_desc);
    if (ret < 0) {
        ret = usb_control_transfer(slot_id,
            USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_DEVICE,
            USB_REQ_GET_DESC, (USB_DT_SS_HUB << 8) | 0, 0, sizeof(hub_desc), hub_desc);
        if (ret < 0) {
            xil_printf("[USB] Failed to get hub descriptor\r\n");
            return ret;
        }
    }

    uint32_t nports = hub_desc[2];
    uint32_t ttt = (hub_desc[3] >> 5) & 0x3;  /* TT Think Time from hub chars */
    *num_ports_out = nports;
    xil_printf("[USB] Hub: %u ports\r\n", nports);

    /* Evaluate Context: tell xHCI this slot is a hub.
     * Without Hub=1 and NumPorts in the slot context, xHCI cannot
     * route transactions to downstream devices. */
    {
        uint32_t csz = usb.ctx_size;
        memset(input_ctx, 0, sizeof(input_ctx));

        xhci_input_ctrl_ctx_t *ctrl = (xhci_input_ctrl_ctx_t *)input_ctx;
        ctrl->add_flags = (1U << 0);  /* evaluate slot context only */

        uint32_t *slot = (uint32_t *)(input_ctx + csz);
        /* Copy current slot context from output */
        invalidate_cache(dev_out_ctxs[slot_id - 1], sizeof(dev_out_ctxs[0]));
        memcpy(slot, dev_out_ctxs[slot_id - 1], csz);

        /* Set Hub=1 (bit 26), NumPorts, TTT */
        slot[0] |= (1U << 26);     /* Hub = 1 */
        slot[1] &= 0xFFFF0000U;    /* clear lower 16 bits (Number of Ports, etc.) */
        slot[1] |= nports & 0xFFU; /* Number of Downstream Facing Ports (bits 7:0 of dword 1... */

        /* xHCI Slot Context dword 1:
         *   [31:16] = Max Exit Latency
         *   [15:8]  = Root Hub Port Number
         *   [7:0]   = Number of Ports (only if Hub=1)
         * Wait — Root Hub Port is bits [23:16], num ports is [31:24]?
         * Let me use the correct layout per xHCI spec Table 6-4:
         *   Dword 0: [31:27] Context Entries, [26] Hub, [25] MTT, [24] rsvd,
         *            [23:20] Speed, [19:0] Route String
         *   Dword 1: [31:24] Number of Ports, [23:16] Root Hub Port Number,
         *            [15:0] Max Exit Latency
         */
        slot[1] &= 0x00FFFFFFU;    /* preserve Root Hub Port + Max Exit Latency */
        slot[1] |= (nports << 24); /* Number of Ports in bits [31:24] */

        /* Dword 2: [31:16] = Interrupter Target, [15:8] = TTT, [7:0] = TT Hub Slot ID
         * For Evaluate Context of a hub, set TTT field */
        slot[2] &= ~(0x3U << 8);
        slot[2] |= (ttt << 8);

        flush_cache(input_ctx, sizeof(input_ctx));

            cmd_ring_enqueue((uint32_t)(uintptr_t)input_ctx, 0, 0,
                         TRB_TYPE(TRB_EVAL_CTX) | (slot_id << 24));
        ring_doorbell(0, 0);

        ret = wait_cmd_complete(NULL);
        if (ret < 0) {
            xil_printf("[USB] Evaluate Context (hub) failed (%d)\r\n", ret);
            return ret;
        }
        xil_printf("[USB] Hub slot %u context updated\r\n", slot_id);
    }

    for (uint32_t p = 1; p <= nports; p++)
        hub_set_feature(slot_id, p, HUB_FEAT_PORT_POWER);

    uint32_t power_on_delay = hub_desc[5] * 2;
    if (power_on_delay < 100) power_on_delay = 100;
    delay_ms(power_on_delay);

    return 0;
}

/* ------------------------------------------------------------------ */
/* Configure interrupt endpoint (for keyboard slot)                   */
/* ------------------------------------------------------------------ */

static int configure_endpoint(uint32_t slot_id)
{
    uint32_t csz = usb.ctx_size;
    memset(input_ctx, 0, sizeof(input_ctx));

    xhci_input_ctrl_ctx_t *ctrl = (xhci_input_ctrl_ctx_t *)input_ctx;
    ctrl->add_flags = (1U << 0) | (1U << usb.ep_in_dci);

    /* Copy current slot context from output context */
    uint32_t *slot = (uint32_t *)(input_ctx + csz);
    invalidate_cache(dev_out_ctxs[slot_id - 1], sizeof(dev_out_ctxs[0]));
    memcpy(slot, dev_out_ctxs[slot_id - 1], csz);
    slot[0] &= ~(0x1FU << 27);
    slot[0] |= (usb.ep_in_dci << 27);

    /* Endpoint context */
    uint32_t *ep = (uint32_t *)(input_ctx + csz + usb.ep_in_dci * csz);

    uint32_t interval = 0;
    uint32_t speed = usb.slots[slot_id].speed;
    if (speed >= PORT_SPEED_HS) {
        interval = usb.ep_in_interval;
        if (interval > 0) interval--;
        if (interval > 15) interval = 15;
    } else {
        uint32_t ms = usb.ep_in_interval;
        if (ms == 0) ms = 1;
        uint32_t frames = ms * 8;
        interval = 0;
        while ((1U << interval) < frames && interval < 15) interval++;
    }

    ep[0] = (interval << 16);
    ep[1] = (3U << 1) | (7U << 3) | (usb.ep_in_maxpkt << 16); /* CErr=3, EPType=InterruptIN */
    ep[2] = (uint32_t)(uintptr_t)xfer_ring | 1U;
    ep[3] = 0;
    ep[4] = usb.ep_in_maxpkt | (usb.ep_in_maxpkt << 16);

    flush_cache(input_ctx, sizeof(input_ctx));

    cmd_ring_enqueue((uint32_t)(uintptr_t)input_ctx, 0, 0,
                     TRB_TYPE(TRB_CONFIG_EP) | (slot_id << 24));
    ring_doorbell(0, 0);

    int ret = wait_cmd_complete(NULL);
    if (ret < 0) {
        xil_printf("[USB] Configure Endpoint failed (%d)\r\n", ret);
        return ret;
    }
    xil_printf("[USB] Interrupt endpoint configured (DCI=%u)\r\n", usb.ep_in_dci);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Descriptor parsing                                                 */
/* ------------------------------------------------------------------ */

static int find_hid_keyboard(uint8_t *config_desc, uint16_t total_len)
{
    uint8_t *p = config_desc;
    uint8_t *end = config_desc + total_len;
    int found_hid_kbd = 0;

    while (p < end && p[0] >= 2) {
        uint8_t bLength = p[0];
        uint8_t bDescType = p[1];

        if (bDescType == USB_DT_INTERFACE && bLength >= 9) {
            if (p[5] == USB_CLASS_HID &&
                p[6] == USB_SUBCLASS_BOOT &&
                p[7] == USB_PROTOCOL_KBD) {
                xil_printf("[USB] Found HID keyboard (iface %u)\r\n", p[2]);
                found_hid_kbd = 1;
            } else {
                found_hid_kbd = 0;
            }
        }

        if (bDescType == USB_DT_ENDPOINT && bLength >= 7 && found_hid_kbd) {
            uint8_t ep_addr = p[2];
            uint8_t ep_attr = p[3];
            if ((ep_attr & 0x03) == 0x03 && (ep_addr & 0x80)) {
                usb.ep_in_maxpkt = p[4] | (p[5] << 8);
                usb.ep_in_interval = p[6];
                usb.ep_in_dci = ((ep_addr & 0x0F) * 2) + 1;
                xil_printf("[USB] Interrupt IN EP 0x%02X maxpkt=%u interval=%u DCI=%u\r\n",
                           ep_addr, usb.ep_in_maxpkt, usb.ep_in_interval, usb.ep_in_dci);
                return 0;
            }
        }
        p += bLength;
    }
    return -1;
}

/* ------------------------------------------------------------------ */
/* HID keycode to ASCII translation                                   */
/* ------------------------------------------------------------------ */

static const char hid_to_ascii[128] = {
    0, 0, 0, 0,
    'a','b','c','d','e','f','g','h','i','j','k','l','m',
    'n','o','p','q','r','s','t','u','v','w','x','y','z',
    '1','2','3','4','5','6','7','8','9','0',
    '\r', 0x1B, 0x08, '\t', ' ',
    '-', '=', '[', ']', '\\', '#', ';', '\'', '`', ',', '.', '/',
    0, /* Caps Lock */
    0,0,0,0,0,0,0,0,0,0,0,0, /* F1-F12 */
    0,0,0,0,0,0, 0x7F, 0,0,0,0,0,0,0,
    '/', '*', '-', '+', '\r', '1','2','3','4','5','6','7','8','9','0','.',
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
};

static const char hid_to_ascii_shift[128] = {
    0, 0, 0, 0,
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
    '!','@','#','$','%','^','&','*','(',')',
    '\r', 0x1B, 0x08, '\t', ' ',
    '_', '+', '{', '}', '|', '~', ':', '"', '~', '<', '>', '?',
    0,
    0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0, 0x7F, 0,0,0,0,0,0,0,
    '/', '*', '-', '+', '\r', '1','2','3','4','5','6','7','8','9','0','.',
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
};

#define MOD_LCTRL   (1U << 0)
#define MOD_LSHIFT  (1U << 1)
#define MOD_RCTRL   (1U << 4)
#define MOD_RSHIFT  (1U << 5)

/* HID keycodes for lock keys */
#define KEY_CAPS_LOCK   0x39
#define KEY_NUM_LOCK    0x53
#define KEY_SCROLL_LOCK 0x47

/* HID LED report bits (Output report byte 0) */
#define LED_NUM_LOCK    (1U << 0)
#define LED_CAPS_LOCK   (1U << 1)
#define LED_SCROLL_LOCK (1U << 2)

/* HID SET_REPORT request */
#define USB_REQ_SET_REPORT  0x09
#define HID_REPORT_OUTPUT   2

static void process_hid_report(const uint8_t *report)
{
    uint8_t modifiers = report[0];
    int shift = (modifiers & (MOD_LSHIFT | MOD_RSHIFT)) != 0;
    int ctrl = (modifiers & (MOD_LCTRL | MOD_RCTRL)) != 0;

    for (int i = 2; i < 8; i++) {
        uint8_t key = report[i];
        if (key < 4) continue; /* no key or error */

        int was_pressed = 0;
        for (int j = 0; j < 6; j++) {
            if (usb.prev_keys[j] == key) { was_pressed = 1; break; }
        }
        if (was_pressed) continue;

        /* Handle lock key toggles */
        if (key == KEY_CAPS_LOCK) {
            usb.caps_lock ^= 1;
            usb.leds_dirty = 1;
            continue;
        }
        if (key == KEY_NUM_LOCK) {
            usb.num_lock ^= 1;
            usb.leds_dirty = 1;
            continue;
        }

        /* Determine effective shift: XOR physical shift with caps lock for letters */
        int eff_shift = shift;
        if (usb.caps_lock && key >= 0x04 && key <= 0x1D)
            eff_shift = !eff_shift;

        char ch = 0;
        if (key < 128)
            ch = eff_shift ? hid_to_ascii_shift[key] : hid_to_ascii[key];
        if (ctrl && key >= 0x04 && key <= 0x1D)
            ch = (char)(key - 0x04 + 1);
        if (ch != 0)
            mfp_rx_push((uint8_t)ch);
    }

    usb.prev_modifiers = modifiers;
    memcpy(usb.prev_keys, &report[2], 6);
}

static void queue_interrupt_transfer(void)
{
    memset(hid_report, 0, 64);
    flush_cache(hid_report, 64);

    ring_enqueue(xfer_ring, XFER_RING_SIZE,
                 &usb.xfer_enq, &usb.xfer_cycle,
                 (uint32_t)(uintptr_t)hid_report, 0, 8,
                 TRB_TYPE(TRB_NORMAL) | TRB_IOC | TRB_ISP);

    ring_doorbell(usb.kbd_slot, usb.ep_in_dci);
}

/* LED output report buffer (must be DMA-able, cache-line aligned) */
static uint8_t led_buf[64] __attribute__((aligned(64)));

static void update_leds(void)
{
    uint8_t new_leds = 0;
    if (usb.num_lock)  new_leds |= LED_NUM_LOCK;
    if (usb.caps_lock) new_leds |= LED_CAPS_LOCK;

    if (new_leds == usb.leds)
        return;

    usb.leds = new_leds;

    /* Send SET_REPORT (Output, Report ID 0) with the LED byte.
     * This is a class request to the HID interface. */
    led_buf[0] = new_leds;
    memset(&led_buf[1], 0, 63);
    flush_cache(led_buf, 64);

    /* Non-blocking best-effort: queue the control transfer on EP0.
     * We use the same ep0_enqueue + doorbell + wait pattern but
     * through the shared usb_control_transfer helper. */
    usb_control_transfer(usb.kbd_slot,
        USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_IFACE,
        USB_REQ_SET_REPORT,
        (HID_REPORT_OUTPUT << 8) | 0,  /* wValue: report type | report ID */
        0,                               /* wIndex: interface 0 */
        1, led_buf);
}

/* ------------------------------------------------------------------ */
/* Enumerate a single device. If it's a hub, set up the hub and       */
/* enumerate downstream. If it's an HID keyboard, configure it.       */
/* Returns 0 if a keyboard was found and configured.                  */
/* ------------------------------------------------------------------ */

static int get_config_and_parse(uint32_t slot_id, uint8_t *config_desc, uint16_t buf_size,
                                uint16_t *total_len_out, uint8_t *dev_class_out)
{
    uint8_t dev_desc[18];
    int ret;

    memset(dev_desc, 0, sizeof(dev_desc));
    ret = usb_control_transfer(slot_id,
        USB_DIR_IN | USB_TYPE_STANDARD | USB_RECIP_DEVICE,
        USB_REQ_GET_DESC, (USB_DT_DEVICE << 8), 0, 18, dev_desc);
    if (ret < 0) {
        xil_printf("[USB] GET_DESCRIPTOR (device) failed (%d)\r\n", ret);
        return ret;
    }

    xil_printf("[USB] Device: VID=%04X PID=%04X class=%u/%u/%u\r\n",
               dev_desc[8] | (dev_desc[9] << 8),
               dev_desc[10] | (dev_desc[11] << 8),
               dev_desc[4], dev_desc[5], dev_desc[6]);

    *dev_class_out = dev_desc[4];

    /* Get config descriptor header */
    memset(config_desc, 0, buf_size);
    ret = usb_control_transfer(slot_id,
        USB_DIR_IN | USB_TYPE_STANDARD | USB_RECIP_DEVICE,
        USB_REQ_GET_DESC, (USB_DT_CONFIG << 8), 0, 9, config_desc);
    if (ret < 0) return ret;

    *total_len_out = config_desc[2] | (config_desc[3] << 8);
    if (*total_len_out > buf_size) *total_len_out = buf_size;

    /* Get full config */
    ret = usb_control_transfer(slot_id,
        USB_DIR_IN | USB_TYPE_STANDARD | USB_RECIP_DEVICE,
        USB_REQ_GET_DESC, (USB_DT_CONFIG << 8), 0, *total_len_out, config_desc);
    return ret;
}

static int setup_keyboard(uint32_t slot_id, uint8_t *config_desc, uint16_t total_len)
{
    int ret;

    ret = find_hid_keyboard(config_desc, total_len);
    if (ret < 0) return ret;

    /* SET_CONFIGURATION */
    uint8_t config_val = config_desc[5];
    ret = usb_control_transfer(slot_id,
        USB_DIR_OUT | USB_TYPE_STANDARD | USB_RECIP_DEVICE,
        USB_REQ_SET_CONFIG, config_val, 0, 0, NULL);
    if (ret < 0) return ret;

    /* SET_PROTOCOL boot */
    usb_control_transfer(slot_id,
        USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_IFACE,
        USB_REQ_SET_PROTO, HID_PROTO_BOOT, 0, 0, NULL);
    /* non-fatal if fails */

    usb.kbd_slot = slot_id;

    ret = configure_endpoint(slot_id);
    if (ret < 0) return ret;

    queue_interrupt_transfer();
    xil_printf("[USB] HID keyboard ready (slot %u)\r\n", slot_id);
    return 0;
}

/*
 * Recursively enumerate a device.  If it's a hub, configure it and
 * enumerate all downstream ports.  If it's an HID keyboard, set it up.
 *
 * parent_slot  = 0 for root-hub-connected device
 * parent_port  = hub port number (0 for root)
 * route_string = xHCI route string built from hub topology
 * depth        = recursion depth (0 = root)
 */
#define MAX_HUB_DEPTH 3

static int enumerate_one(uint32_t slot_id, uint32_t speed,
                         uint32_t parent_slot, uint32_t parent_port,
                         uint32_t route_string, int depth)
{
    int ret;
    uint8_t config_desc[256];
    uint16_t total_len;
    uint8_t dev_class;

    ret = address_device(slot_id, speed, usb.root_port,
                         parent_slot, parent_port, route_string);
    if (ret < 0) return ret;
    delay_ms(10);

    ret = get_config_and_parse(slot_id, config_desc, sizeof(config_desc),
                               &total_len, &dev_class);
    if (ret < 0) return ret;

    /* Not a hub — try to set up as keyboard */
    if (dev_class != USB_CLASS_HUB) {
        return setup_keyboard(slot_id, config_desc, total_len);
    }

    /* It's a hub */
    if (depth >= MAX_HUB_DEPTH) {
        xil_printf("[USB] Hub depth limit reached\r\n");
        return -1;
    }

    xil_printf("[USB] Hub at slot %u (depth %d), enumerating downstream...\r\n",
               slot_id, depth);

    uint32_t num_ports = 0;
    ret = hub_init(slot_id, config_desc, &num_ports);
    if (ret < 0) return ret;

    /* Scan all hub ports for connected devices */
    for (uint32_t p = 1; p <= num_ports; p++) {
        uint32_t status = 0;
        if (hub_get_port_status(slot_id, p, &status) < 0)
            continue;
        if (!(status & HUB_PORT_CONNECTION))
            continue;

        /* Clear connection change */
        hub_clear_feature(slot_id, p, HUB_FEAT_C_PORT_CONNECTION);

        /* Reset the port */
        hub_set_feature(slot_id, p, HUB_FEAT_PORT_RESET);
        delay_ms(60);

        int timeout = 500;
        while (timeout > 0) {
            hub_get_port_status(slot_id, p, &status);
            if ((status >> 16) & HUB_C_PORT_RESET)
                break;
            delay_ms(1);
            timeout--;
        }
        hub_clear_feature(slot_id, p, HUB_FEAT_C_PORT_RESET);

        hub_get_port_status(slot_id, p, &status);
        if (!(status & HUB_PORT_ENABLE))
            continue;

        /* Extract speed from hub port status bits 10:9 */
        uint32_t ls = (status >> 9) & 3;
        uint32_t child_speed;
        if (ls == 0) child_speed = PORT_SPEED_FS;
        else if (ls == 1) child_speed = PORT_SPEED_LS;
        else child_speed = PORT_SPEED_HS;

        xil_printf("[USB] Hub port %u: device at speed %u\r\n", p, child_speed);

        /* Build route string: shift existing route left by 4, add port number.
         * xHCI route string: each nibble = port number at that hub depth. */
        uint32_t child_route = (route_string << 4) | (p & 0xF);

        uint32_t child_slot = 0;
        ret = enable_slot(&child_slot);
        if (ret < 0) continue;

        ret = enumerate_one(child_slot, child_speed,
                            slot_id, p, child_route, depth + 1);
        if (ret == 0)
            return 0;  /* found a keyboard */

        /* Not a keyboard on this port, try next */
    }

    xil_printf("[USB] No HID keyboard found downstream of hub slot %u\r\n", slot_id);
    return -1;
}

static int enumerate_device(void)
{
    uint32_t slot_id = 0;
    int ret = enable_slot(&slot_id);
    if (ret < 0) return ret;

    return enumerate_one(slot_id, usb.root_speed, 0, 0, 0, 0);
}

/* ------------------------------------------------------------------ */
/* Public API                                                         */
/* ------------------------------------------------------------------ */

int usb_hid_init(void)
{
    memset(&usb, 0, sizeof(usb));

    int ret = dwc3_host_init();
    if (ret < 0) return ret;

    ret = xhci_init();
    if (ret < 0) return ret;

    ret = wait_for_device();
    if (ret < 0) return ret;

    ret = enumerate_device();
    if (ret < 0) return ret;

    usb.initialized = 1;
    xil_printf("[USB] USB HID keyboard initialized\r\n");
    return 0;
}

void usb_hid_poll(void)
{
    if (!usb.initialized)
        return;

    invalidate_cache(&evt_ring[usb.evt_deq], sizeof(xhci_trb_t));
    uint32_t f3 = evt_ring[usb.evt_deq].field[3];

    if ((f3 & TRB_CYCLE) != (usb.evt_cycle ? 1U : 0U))
        return;

    xhci_trb_t evt;
    evt.field[0] = evt_ring[usb.evt_deq].field[0];
    evt.field[1] = evt_ring[usb.evt_deq].field[1];
    evt.field[2] = evt_ring[usb.evt_deq].field[2];
    evt.field[3] = f3;

    usb.evt_deq++;
    if (usb.evt_deq >= EVT_RING_SIZE) {
        usb.evt_deq = 0;
        usb.evt_cycle ^= 1;
    }

    reg_write64(usb.rt_base + XHCI_RT_ERDP_LO(0),
                (uintptr_t)&evt_ring[usb.evt_deq] | (1U << 3));
    reg_write32(usb.op_base + XHCI_OP_USBSTS, USBSTS_EINT);

    uint32_t trb_type = (evt.field[3] >> TRB_TYPE_SHIFT) & 0x3FU;
    uint32_t comp_code = (evt.field[2] >> 24) & 0xFFU;

    if (trb_type == TRB_TRANSFER_EVT) {
        if (comp_code == TRB_COMP_SUCCESS || comp_code == TRB_COMP_SHORT_PKT) {
            invalidate_cache(hid_report, 64);
            process_hid_report(hid_report);
        }
        queue_interrupt_transfer();

        /* Update keyboard LEDs if caps/num lock changed */
        if (usb.leds_dirty) {
            usb.leds_dirty = 0;
            update_leds();
        }
    }
}
