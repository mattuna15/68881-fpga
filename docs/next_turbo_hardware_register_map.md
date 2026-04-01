# NeXTstation Turbo — Hardware Register Memory Map

All addresses are **physical** 32-bit addresses on the 68040 bus. The NeXT architecture uses memory-mapped I/O exclusively — no port I/O instructions. Addresses confirmed from the Previous emulator source code (`ioMemTabTurbo.c`) which is authoritative for real hardware.

> **Note**: QEMU's `next-cube.c` uses a simplified/reorganised memory layout that differs from real hardware. This document follows the Previous emulator and NeXTMach kernel source as ground truth.

---

## Top-Level Physical Address Map

| Address Range             | Size     | Description                                       |
|---------------------------|----------|---------------------------------------------------|
| `0x00000000 – 0x0001FFFF` | 128 KB   | Boot ROM (mirrored from 0x01000000)               |
| `0x01000000 – 0x0101FFFF` | 128 KB   | Boot ROM BMAP (v74 for Turbo, primary mapping)    |
| `0x02000000 – 0x0201FFFF` | 128 KB   | System MMIO registers (I/O space)                 |
| `0x02100000 – 0x0211FFFF` | 128 KB   | Slot 0 device registers (slot ID offset +0x100000)|
| `0x02200000 – 0x0221FFFF` | 128 KB   | Slot 0 device registers (slot ID offset +0x200000)|
| `0x04000000 – 0x04FFFFFF` | 16 MB    | Main DRAM (Turbo supports up to 128 MB)           |
| `0x0B000000 – 0x0B03FFFF` | 256 KB   | Video RAM — non-Turbo mono framebuffer            |
| `0x0C000000 – 0x0C03FFFF` | 256 KB   | Video RAM — Turbo mono framebuffer                |

### Slot ID BMAP Mapping

The ROM configures a slot ID bitmap that offsets device registers. Before BMAP config, devices are at `0x021xxxxx` (+0x100000). After BMAP config, devices appear at `0x022xxxxx` (+0x200000). Both ranges map to the canonical `0x020xxxxx` addresses. The kernel accesses devices using the slot-mapped addresses; the emulator must canonicalise these back to `0x020xxxxx`.

---

## System MMIO Registers — Canonical Base `0x02000000`

### Interrupt Controller

| Address        | Width | R/W | Register                        |
|----------------|-------|-----|---------------------------------|
| `0x0200 7000`  | 32    | R   | **Interrupt Status**            |
| `0x0200 7800`  | 32    | R/W | **Interrupt Mask**              |

#### Interrupt Bit Assignments

| Bit | Mask          | IPL | Source                        |
|-----|---------------|-----|-------------------------------|
| 0   | `0x00000001`  | 1   | Software interrupt 0          |
| 1   | `0x00000002`  | 2   | Software interrupt 1          |
| 2   | `0x00000004`  | 3   | Phone (floppy drive)          |
| 3   | `0x00000008`  | 3   | Sound out underrun            |
| 4   | `0x00000010`  | 3   | Disk (optical/MO)             |
| 5   | `0x00000020`  | 3   | Sound out DMA                 |
| 6   | `0x00000040`  | 3   | Sound in DMA                  |
| 7   | `0x00000080`  | 3   | Printer DMA                   |
| 8   | `0x00000100`  | 3   | SCC DMA                       |
| 9   | `0x00000200`  | 3   | DSP DMA                       |
| 10  | `0x00000400`  | 3   | Floppy (fd)                   |
| 11  | `0x00000800`  | 3   | Ethernet transmit DMA         |
| 12  | `0x00001000`  | 3   | SCSI                          |
| 13  | `0x00002000`  | 3   | Ethernet receive DMA          |
| 18  | `0x00040000`  | 6   | SCSI DMA                      |
| 19  | `0x00080000`  | 6   | Disk/MO DMA                   |
| 20  | `0x00100000`  | 6   | DSP                           |
| 21  | `0x00200000`  | 6   | Bus (NeXTbus timeout)         |
| 22  | `0x00400000`  | 5   | Remote (network)              |
| 23  | `0x00800000`  | 5   | SCC                           |
| 29  | `0x20000000`  | 6   | Timer (hardclock)             |
| 30  | `0x40000000`  | 7   | Power fail                    |
| 31  | `0x80000000`  | 7   | NMI                           |

Timer interrupt can be routed to IPL7 via SCR2 `TIMERIPL7` bit.

### System Control Registers

| Address        | Width | R/W | Register                              |
|----------------|-------|-----|---------------------------------------|
| `0x0200 C000`  | 32    | R   | **SCR1** — System Control Register 1  |
| `0x0200 C800`  | 32    | R   | **Slot ID** (hardware configuration)  |
| `0x0200 D000`  | 32    | R/W | **SCR2** — System Control Register 2  |

#### SCR1 Bit Fields (Read-Only — Hardware Identity)

| Bits    | Field         | Description                                        |
|---------|---------------|----------------------------------------------------|
| 31–28   | Slot ID       | Board slot identification                          |
| 27–24   | Board Rev     | Board revision (`0xF` for Turbo)                   |
| 23–20   | Machine Type  | `5` = NeXTstation Turbo (Warp9), `4` = NeXTstation |
| 19–16   | Memory Speed  | DRAM timing (60ns/70ns/80ns/100ns)                 |
| 15–12   | Memory Size   | Installed DRAM configuration                       |
| 11–8    | Video Config  | Display type (mono 2-bit / colour 16-bit)          |
| 7–0     | CPU Speed     | `0x12` = 25 MHz, `0x17` = 33 MHz                   |

#### SCR2 Bit Fields (R/W — RTC Bit-Bang and System Control)

| Bit  | Mask          | Name           | Description                          |
|------|---------------|----------------|--------------------------------------|
| 0    | `0x00000001`  | `LEDG`         | Power LED green                      |
| 1    | `0x00000002`  | `LEDR`         | Power LED red                        |
| 4    | `0x00000010`  | `DSP_RESET`    | Reset the DSP                        |
| 5    | `0x00000020`  | `DSP_BG`       | DSP bus grant                        |
| 8    | `0x00000100`  | `RTDATA`       | RTC serial data line                 |
| 9    | `0x00000200`  | `RTCLK`        | RTC serial clock                     |
| 10   | `0x00000400`  | `RTCE`         | RTC chip enable                      |
| 15   | `0x00008000`  | `TIMERIPL7`    | Route timer interrupt to IPL7        |
| 19–16| `0x000F0000`  | `s_dram_*`     | DRAM bank configuration              |

---

## DMA Controller — Turbo Format

The Turbo uses a reorganised DMA layout compared to the 68030 NeXT. DMA CSR registers are at `0x02000xxx`, data registers at `0x02004xxx`, and init registers at `0x02004200+`.

### DMA CSR Registers (32-bit, write-only commands / read-only status)

| Address        | Channel          |
|----------------|------------------|
| `0x0200 0010`  | SCSI             |
| `0x0200 0040`  | Sound Out        |
| `0x0200 0050`  | Disk (MO)        |
| `0x0200 0080`  | Sound In         |
| `0x0200 0090`  | Printer          |
| `0x0200 00C0`  | SCC              |
| `0x0200 00D0`  | DSP              |
| `0x0200 0110`  | Ethernet TX      |
| `0x0200 0150`  | Ethernet RX      |
| `0x0200 0180`  | Video            |
| `0x0200 01C0`  | R2M              |
| `0x0200 01D0`  | M2R              |

#### Turbo DMA CSR Write Bits (bits 16–23)

| Bit  | Mask          | Name             | Description                    |
|------|---------------|------------------|--------------------------------|
| 16   | `0x00010000`  | `SETENABLE`      | Enable DMA channel             |
| 17   | `0x00020000`  | `SETSUPDATE`     | Enable chaining (supdate)      |
| 18   | `0x00040000`  | `DEV2M`          | Direction: device → memory     |
| 19   | `0x00080000`  | `CLRCOMPLETE`    | Clear completion status        |
| 20   | `0x00100000`  | `RESET`          | Reset DMA channel              |
| 21   | `0x00200000`  | `INITBUF`        | Initialise DMA buffer          |

#### Turbo DMA CSR Read Bits (bits 24–31)

| Bit  | Mask          | Name             | Description                    |
|------|---------------|------------------|--------------------------------|
| 24   | `0x01000000`  | `ENABLE`         | DMA enabled                    |
| 25   | `0x02000000`  | `SUPDATE`        | Chaining active                |
| 27   | `0x08000000`  | `COMPLETE`       | Transfer complete              |
| 28   | `0x10000000`  | `BUSEXC`         | Bus error during DMA           |

### DMA Data Registers (32-bit R/W)

Each channel has a block of data registers at `0x02004xxx`. The offset from `0x02004000` follows the `struct dma_dev` layout with a 0x3FEC padding gap between CSR and data registers.

**SCSI channel (canonical example):**

| Address        | Register           | Description                                |
|----------------|--------------------|--------------------------------------------|
| `0x0200 4000`  | `dd_saved_next`    | Saved next address (scratchpad, DMA_W)     |
| `0x0200 4004`  | `dd_saved_limit`   | Saved limit (scratchpad, DMA_W)            |
| `0x0200 4008`  | `dd_saved_start`   | Saved start (scratchpad, DMA_W)            |
| `0x0200 400C`  | `dd_saved_stop`    | Saved stop (scratchpad, DMA_W)             |
| `0x0200 4010`  | `dd_next`          | Current DMA address pointer                |
| `0x0200 4014`  | `dd_limit`         | DMA end address                            |
| `0x0200 4018`  | `dd_start`         | Chained buffer start                       |
| `0x0200 401C`  | `dd_stop`          | Chained buffer stop                        |
| `0x0200 4210`  | `dd_next_initbuf`  | Init register — write sets dd_next + init buffer |

**Other channels follow the same pattern at their base offsets:**

| Channel      | Saved regs base | Active regs base | Init reg       |
|--------------|-----------------|------------------|----------------|
| SCSI         | `0x02004000`    | `0x02004010`     | `0x02004210`   |
| Sound Out    | `0x02004040`    | `0x02004050`     | `0x02004240`   |
| Disk (MO)    | (implied)       | (implied)        | (implied)      |
| Sound In     | `0x02004080`    | `0x02004090`     | `0x02004280`   |
| Printer      | `0x02004090`    | `0x020040A0`     | `0x02004290`   |
| DSP          | `0x020040D0`    | `0x020040E0`     | `0x020042D0`   |
| Ethernet TX  | `0x02004110`    | `0x02004120`     | `0x02004310`   |
| Ethernet RX  | `0x02004150`    | `0x02004160`     | `0x02004350`   |

> **Important**: The kernel's `DMA_W(reg, val)` macro writes a value and retries until readback matches. All DMA data registers must be read/write (scratchpad) or the kernel hangs in an infinite retry loop.

---

## Device Registers — Canonical Addresses

All device registers below are at their canonical `0x020xxxxx` addresses. The kernel accesses them via slot-mapped addresses (`0x021xxxxx` or `0x022xxxxx`); the emulator strips the slot offset.

### SCSI Controller — NCR 53C90(A) (ESP)

| Address        | Width | R/W    | Register                         |
|----------------|-------|--------|----------------------------------|
| `0x0201 4000`  | 8     | R/W    | Transfer Count LSB               |
| `0x0201 4001`  | 8     | R/W    | Transfer Count MSB               |
| `0x0201 4002`  | 8     | R/W    | FIFO                             |
| `0x0201 4003`  | 8     | R/W    | Command                          |
| `0x0201 4004`  | 8     | R/W    | Status (R) / Select Bus ID (W)   |
| `0x0201 4005`  | 8     | R/W    | Interrupt Status (R) / Select Timeout (W) |
| `0x0201 4006`  | 8     | R/W    | Sequence Step (R) / Sync Period (W) |
| `0x0201 4007`  | 8     | R/W    | FIFO Flags (R) / Sync Offset (W) |
| `0x0201 4008`  | 8     | R/W    | Configuration 1                  |
| `0x0201 4009`  | 8     | W      | Clock Conversion Factor          |
| `0x0201 400A`  | 8     | W      | Test                             |
| `0x0201 400B`  | 8     | R/W    | Configuration 2                  |

Reading Interrupt Status (offset 5) **clears the interrupt**.

### ESP DMA Control

| Address        | Width | R/W | Register                                  |
|----------------|-------|-----|-------------------------------------------|
| `0x0201 4020`  | 8     | R/W | **ESP DMA Control** (int enable, DMA mode)|
| `0x0201 4021`  | 8     | R/W | **ESP DMA FIFO Status**                   |

#### ESP DMA Control Bit Fields

| Bit | Mask   | Name           | Description                        |
|-----|--------|----------------|------------------------------------|
| 0   | `0x01` | `CLKMASK`      | Clock mask                         |
| 1   | `0x02` | `FLUSH`        | Flush DMA FIFO                     |
| 3   | `0x08` | `DMAREAD`      | DMA direction (1 = device→memory)  |
| 4   | `0x10` | `DMAMODE`      | DMA mode enable                    |
| 5   | `0x20` | `INTENABLE`    | Interrupt enable (must be set!)    |
| 6   | `0x40` | `RESET`        | DMA reset (triggers ESP hard reset)|
| 7   | `0x80` | `20MHZ`        | 20 MHz clock select                |

Normal operation: `0xA0` (20MHz + interrupt enable). DMA read: `0xE8` (20MHz + enable + DMA mode + DMA read).

### Floppy Disk Controller — Intel 82077AA

| Address        | Width | R/W | Register                         |
|----------------|-------|-----|----------------------------------|
| `0x0201 4100`  | 8     | R   | Status Register A (SRA)          |
| `0x0201 4101`  | 8     | R   | Status Register B (SRB)          |
| `0x0201 4102`  | 8     | R/W | Digital Output Register (DOR)    |
| `0x0201 4104`  | 8     | R/W | Main Status Register (R) / Data Rate Select (W) |
| `0x0201 4105`  | 8     | R/W | Data FIFO                        |
| `0x0201 4107`  | 8     | R/W | Digital Input Register (R) / Config Control (W) |
| `0x0201 4108`  | 8     | R/W | Floppy External Control          |

The floppy controller **shares the SCSI/floppy bus** via `sfa_arbitrate()`. The kernel's fc_probe does a DOR write/readback test — if readback fails, probe returns 0 and releases the bus.

### DSP — Motorola DSP56001 Host Interface

| Address        | Width | R/W | Register                         |
|----------------|-------|-----|----------------------------------|
| `0x0200 8000`  | 8     | R/W | **ICR** — Interface Control      |
| `0x0200 8001`  | 8     | R/W | **CVR** — Command Vector         |
| `0x0200 8002`  | 8     | R   | **ISR** — Interface Status       |
| `0x0200 8003`  | 8     | R/W | **IVR** — Interrupt Vector       |
| `0x0200 8004`  | 32    | R/W | **Data** (24-bit in 32-bit word) |

#### ICR Bit Fields

| Bit | Mask   | Name      | Description                    |
|-----|--------|-----------|--------------------------------|
| 7   | `0x80` | `INIT`    | Initialise/reset DSP           |
| 6   | `0x40` | `HM1`     | Host mode bit 1                |
| 5   | `0x20` | `HM0`     | Host mode bit 0                |
| 4   | `0x10` | `HF1`     | Host flag 1                    |
| 3   | `0x08` | `HF0`     | Host flag 0                    |
| 1   | `0x02` | `TREQ`    | Transmit request enable        |
| 0   | `0x01` | `RREQ`    | Receive request enable         |

#### ISR Bit Fields

| Bit | Mask   | Name      | Description                    |
|-----|--------|-----------|--------------------------------|
| 7   | `0x80` | `HREQ`    | Host request                   |
| 6   | `0x40` | `DMA`     | DMA status                     |
| 4   | `0x10` | `HF3`     | Host flag 3                    |
| 3   | `0x08` | `HF2`     | Host flag 2 (ROM waits for this)|
| 2   | `0x04` | `TRDY`    | Transmit ready                 |
| 1   | `0x02` | `TXDE`    | Transmit data register empty   |
| 0   | `0x01` | `RXDF`    | Receive data register full     |

### Keyboard/Mouse/Sound — KMS Chip

| Address        | Width | R/W | Register                         |
|----------------|-------|-----|----------------------------------|
| `0x0200 E000`  | 8     | R/W | Sound status (R) / Sound control (W) |
| `0x0200 E001`  | 8     | R/W | KM status (R) / KM control (W)  |
| `0x0200 E002`  | 8     | R/W | TX status (R) / TX control (W)   |
| `0x0200 E003`  | 8     | R/W | Command status (R) / Command (W) |
| `0x0200 E004`  | 32    | R/W | KMS Data                         |
| `0x0200 E008`  | 32    | R   | KM Data (keyboard/mouse events)  |
| `0x0200 E00C`  | 32    | R   | (reserved)                       |

### Serial — Zilog 8530 (SCC)

| Address        | Width | R/W | Register                         |
|----------------|-------|-----|----------------------------------|
| `0x0201 8000`  | 8     | R/W | SCC Channel B Control            |
| `0x0201 8001`  | 8     | R/W | SCC Channel A Control            |
| `0x0201 8002`  | 8     | R/W | SCC Channel B Data               |
| `0x0201 8003`  | 8     | R/W | SCC Channel A Data               |
| `0x0201 8004`  | 32    | R/W | Serial Interface Clock           |

Port A = alternate console (serial port A). Port B = serial port B.

### Hardclock Timer

| Address        | Width | R/W | Register                           |
|----------------|-------|-----|------------------------------------|
| `0x0201 6000`  | 8     | R/W | Timer high byte (period MSB)       |
| `0x0201 6001`  | 8     | R/W | Timer low byte (period LSB)        |
| `0x0201 6004`  | 8     | R/W | Timer CSR                          |

#### Timer CSR Bit Fields

| Bit | Mask   | Name       | Description                              |
|-----|--------|------------|------------------------------------------|
| 7   | `0x80` | `ENABLE`   | Enable periodic interrupt                |
| 6   | `0x40` | `UPDATE`   | Latch high:low into period register      |

**Reading CSR clears the timer interrupt.** Writing CSR also clears the interrupt. The kernel's `us_timer_init()` writes period bytes, then writes `ENABLE|UPDATE` to CSR to start periodic interrupts.

### Event Counter (Microsecond Timer)

| Address        | Width | R/W | Register                           |
|----------------|-------|-----|------------------------------------|
| `0x0201 A000`  | 8     | R/W | Latch trigger (read latches counter; write resets) |
| `0x0201 A001`  | 8     | R   | Event counter high (bits 19–16)    |
| `0x0201 A002`  | 8     | R   | Event counter mid (bits 15–8)      |
| `0x0201 A003`  | 8     | R   | Event counter low (bits 7–0)       |

The event counter is a free-running 20-bit microsecond counter. Read byte 0 to latch, then read bytes 1–3 for the value. The kernel extends this to 32 bits in software via `event_sync()` in the timer interrupt handler.

### Ethernet — AT&T 7213

| Address        | Width | R/W | Register                         |
|----------------|-------|-----|----------------------------------|
| `0x0200 6000`  | 8     | R/W | TX Status / TX Status Write      |
| `0x0200 6001`  | 8     | R/W | TX Mask                          |
| `0x0200 6002`  | 8     | R/W | RX Status                        |
| `0x0200 6003`  | 8     | R/W | RX Mask                          |
| `0x0200 6004`  | 8     | R/W | TX Mode                          |
| `0x0200 6005`  | 8     | R/W | RX Mode                          |
| `0x0200 6006`  | 8     | R/W | Control                          |
| `0x0200 6008`–`0x0200 600D` | 8 | R/W | Node ID (MAC address, 6 bytes) |

### Printer — NeXTlaser Interface

| Address        | Width | R/W | Register                         |
|----------------|-------|-----|----------------------------------|
| `0x0200 F000`  | 8     | R/W | Printer CSR byte 0               |
| `0x0200 F001`  | 8     | R/W | Printer CSR byte 1               |
| `0x0200 F002`  | 8     | R/W | Printer CSR byte 2               |
| `0x0200 F003`  | 8     | R/W | Printer CSR byte 3               |
| `0x0200 F004`  | 32    | R/W | Printer Data                     |

### Brightness Control

| Address        | Width | R/W | Register                         |
|----------------|-------|-----|----------------------------------|
| `0x0201 0000`  | 32    | R/W | Brightness level                 |

### GPIO Register

| Address        | Width | R/W | Register                         |
|----------------|-------|-----|----------------------------------|
| `0x0201 2000`  | 8×4   | R/W | GPIO (possibly MO drive related) |

### RAMDAC — Brooktree Bt463 (Turbo Color only)

| Address        | Width | R/W | Register                         |
|----------------|-------|-----|----------------------------------|
| `0x0201 C000`  | 8     | R/W | RAMDAC register 0                |
| `0x0201 C001`  | 8     | R/W | RAMDAC register 1                |
| `0x0201 C002`  | 8     | R/W | RAMDAC register 2                |
| `0x0201 C003`  | 8     | R/W | RAMDAC register 3                |

---

## Video / Framebuffer

| Address        | Size   | Description                                    |
|----------------|--------|------------------------------------------------|
| `0x0B000000`   | 256 KB | Mono framebuffer — non-Turbo (1120×832, 2-bit) |
| `0x0C000000`   | 256 KB | Mono framebuffer — Turbo (1120×832, 2-bit)     |

The Turbo ROM writes display data to `0x0C000000`. Non-Turbo uses `0x0B000000`. Both map to a 288 bytes/line × 832 scanline buffer. Each byte encodes 4 pixels at 2 bits per pixel (MSB first): `00`=white, `01`=light grey, `10`=dark grey, `11`=black.

---

## NVRAM / RTC

The NVRAM (MCS1850 on Turbo, Dallas DS1287 on non-Turbo) is **not** memory-mapped. It is accessed via a bit-banged serial protocol through **SCR2** register bits (`RTDATA`, `RTCLK`, `RTCE` at `0x0200D000`).

Protocol: assert CE → clock in 8-bit address (MSB first) → clock in/out 8-bit data → deassert CE.

NVRAM contents (32 bytes):

| Offset | Field           | Description                              |
|--------|-----------------|------------------------------------------|
| 0–3    | Volume/brightness/reset | System preferences                 |
| 4–9    | HW password/ethernet | Hardware password, partial MAC        |
| 10–11  | ni_simm         | SIMM configuration (4 bits per socket)   |
| 12–13  | ni_adobe        | (reserved)                               |
| 14–16  | ni_pot          | POST test flags                          |
| 17     | Clock/console   | Bit 7: new clock chip; Bit 5: alt console|
| 18–29  | ni_bootcmd      | Boot command string (12 chars, null-padded)|
| 30–31  | ni_cksum        | Ones-complement checksum                 |

---

## Boot Sequence Register Access Order

During a typical `b sd` boot, the ROM and kernel access registers in this order:

1. **ROM POST**: SCR1 (identity), SCR2 (RTC/NVRAM read), DSP (probe ISR_HF2)
2. **ROM SCSI boot**: ESP registers (RESET, SELECT, TI, ICCS), DMA CSR+data
3. **Kernel early init**: MMU (TC, SRP, ITT/DTT via MOVEC), CINV/CPUSH
4. **Kernel configure()**: ESP (bus reset, SELECT+ATN per target), DMA (init all channels), floppy (82077 probe+DOR test), DSP (init+DMA), KMS, SCC, ethernet, printer, brightness
5. **Kernel root mount**: ESP (SELECT+READ), DMA transfer to RAM

---

## Sources

This register map was compiled from:

- **Previous emulator** (`ioMemTabTurbo.c`, `sysReg.c`, `esp.c`, `dma.c`, `floppy.c`) — the most accurate NeXT hardware emulator, validated against real hardware
- **NeXTMach kernel source** (`johnsonjh/NeXTMach` mk-108.1) — `next/cpu.h`, `nextdev/screg.h`, `nextdev/dma.h`, `nextdev/fd_reg.h`
- **QEMU `hw/m68k/next-cube.c`** — Mark Cave-Ayland's v3 series (useful for structure but uses reorganised addresses)
