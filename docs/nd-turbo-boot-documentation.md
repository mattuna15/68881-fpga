# Complete boot configuration for the NeXTstation Turbo running NeXTSTEP 3.3

The NeXTstation Turbo uses a ROM Monitor (not a traditional BIOS) as its firmware interface, with all configuration stored in battery-backed NVRAM accessed through the `p` command at the `NeXT>` prompt. The single most important thing to know: **when the clock battery dies — and after 30+ years, it has — NVRAM resets and the machine defaults to network boot (`en`), not disk boot**, which is the root cause of the majority of "dead NeXTstation" reports today. Changing the boot command to `sd` via the ROM Monitor is the fix. This report covers every configuration surface needed to bring a Turbo system up on NeXTSTEP 3.3, from ROM Monitor commands through SCSI layout, POST diagnostics, and version-specific requirements.

---

## 1. The ROM Monitor is your entire firmware interface

The NeXTstation Turbo has no BIOS setup screen or DIP switches. All machine-level configuration happens through the **ROM Monitor**, a command-line firmware shell accessed at the `NeXT>` prompt. NVRAM stores every persistent setting, backed by a lithium battery on the motherboard.

### Entering the ROM Monitor

| Method | How | When to use |
|--------|-----|-------------|
| **Startup keystroke** | Hold **right Command + ~ (tilde on numeric keypad)** immediately after "Testing System" disappears | Normal entry for configuration |
| **ADB keyboard (v74 ROM)** | Hold **Command bar + ~** (backtick above 7 on numpad) | Turbo systems with ADB peripherals |
| **NMI interrupt** | Press **both Command keys + ` (numpad backquote)** simultaneously while running | Drops to `nmi>` prompt; type `mon` to reach ROM Monitor |
| **Automatic** | Happens if no boot device is found or NVRAM is lost | Dead battery, missing disk |
| **Serial console** | Set "serial port A is alternate console" to yes; connect terminal to Port A | Headless operation |

### Complete ROM Monitor command set

Every command available at the `NeXT>` prompt:

| Command | Syntax | Function |
|---------|--------|----------|
| `b` | `b [device[(ctrl,unit,part)] [filename] [flags]]` | **Boot from device** — the primary boot command |
| `p` | `p` | **Inspect/modify all NVRAM configuration parameters** |
| `P` | `P` | Set or change the hardware password |
| `m` | `m` | Print memory configuration (SIMM sockets, sizes, addresses) |
| `e` | `e [lwb] [alist] [format]` | Examine memory at address (`lwb` = long/word/byte) |
| `ec` | `ec` | Print recorded system error codes from last boot |
| `ej` | `ej [drive#]` | Eject optical disk (default drive 0) |
| `eo` | `eo` | Same as `ej` (eject optical) |
| `ef` | `ef [drive#]` | Eject floppy disk |
| `a` | `a [n]` | Open address register (a0–a7) |
| `d` | `d [n]` | Open data register (d0–d7) |
| `r` | `r [regname]` | Open processor register |
| `s` | `s [systemreg]` | Open system register |
| `c` | `c` | Continue execution at last program counter |
| `S` | `S [fcode]` | Open function code (address space) |
| `R` | `R [radix]` | Set input radix for numeric values |
| `?` | `?` | Display help / list all commands |

For commands that display a current value and prompt with `?`, press Return to keep the value, type a new value to change it, or type `.` (period) to exit immediately.

### The ROM Monitor startup banner

When the Monitor starts, it identifies the system:

```
NeXT ROM Monitor 3.3 (v74)
CPU MC68040 33 MHz, memory 60 nS
Ethernet address: 0:0:f:1:47:62
Memory size 128MB
NeXT>
```

The version string `v74` is the critical identifier. The **33 MHz** clock confirms Turbo hardware (non-Turbo reads 25 MHz). The Ethernet address shown is the machine's MAC, hardcoded in ROM.

---

## 2. Every NVRAM variable and how to configure it

All NVRAM parameters are accessed through the `p` command. Each is displayed with its current value followed by `?` — press Return to keep, type a new value, or `.` to exit.

### Complete NVRAM parameter table

| Parameter | Values | Default | Purpose |
|-----------|--------|---------|---------|
| **boot command** | `sd`, `en`, `tp`, `fd`, `od`, or full `device(ctrl,unit,part)filename flags` syntax | `en()` (factory/reset default) | Default boot device and command string |
| **DRAM tests** | `yes` / `no` | `yes` | Run memory test at power-on |
| **perform power-on system test** | `yes` / `no` | `yes` | Master enable for all POST sub-tests |
| **sound out tests** | `yes` / `no` | `no` | Test DSP/sound hardware during POST |
| **SCSI tests** | `yes` / `no` | `no` | Test SCSI bus and devices during POST |
| **loop until keypress** | `yes` / `no` | `no` | Repeat POST diagnostics in a loop (burn-in mode) |
| **verbose test mode** | `yes` / `no` | `no` | Show each test step name and result on screen |
| **boot extended diagnostics** | `yes` / `no` | `no` | Boot from "diagnostic" root file (NeXT technician use) |
| **serial port A is alternate console** | `yes` / `no` | `no` | Redirect console I/O to serial Port A |
| **allow any ROM command even if password protected** | `yes` / `no` | `no` | Bypass password for ROM commands |
| **allow boot from any device even if password protected** | `yes` / `no` | `no` | Allow `b` command when password is set |
| **allow optical drive #0 eject even if password protected** | `yes` / `no` | `yes` | Permit MO disk ejection when locked |
| **enable parity checking if parity memory is present** | `yes` / `no` | `no` | Enable hardware parity error detection |

### Setting the boot command — the most critical variable

The boot command is the first parameter displayed when you type `p`. Its value determines what device the machine boots from at power-on:

```
NeXT> p
boot command: en()? sd
```

Common values and what they do:

| Boot command value | Effect |
|--------------------|--------|
| `sd` | Boot from internal SCSI hard drive (lowest SCSI ID) |
| `sd()` | Identical to `sd`, explicit default parameters |
| `sd(0,0,0)` | Boot from first SCSI device, unit 0, partition 0 |
| `sd(1,0,0)` | Boot from second-lowest SCSI ID device |
| `en` or `en()` | Boot from Ethernet via BOOTP/TFTP |
| `en()mach_kernel` | Network boot, requesting specific kernel filename |
| `fd` | Boot from internal floppy drive |
| `od` | Boot from magneto-optical drive |
| `sd -s` | Boot SCSI disk in single-user mode |

**After changing any NVRAM parameter**, you must power down cleanly: press the Power key, confirm with `y` when prompted. This ensures NVRAM writes are committed. If the battery is dead, settings will be lost at next power loss regardless.

### Network boot settings

The NeXT does **not** store IP addresses in NVRAM. Network identity is obtained dynamically via **BOOTP** (or DHCP in BOOTP-compatible mode) at boot time. The Ethernet MAC address is burned into ROM, not NVRAM. A network boot (`en`) triggers this sequence: BOOTP broadcast → server responds with IP and boot filename → TFTP downloads bootstrap loader → BOOTP again for kernel path → TFTP downloads kernel → kernel mounts root via NFS.

A critical BOOTP server requirement: the **vendor magic field** must be set to `auto` in `/etc/bootptab`, or the NeXT ignores the BOOTP response. For ISC DHCP, set `always-reply-rfc1048 false;`.

---

## 3. Firmware-level hardware configuration and specifications

### The Turbo's hardware identity

The NeXTstation Turbo runs a **Motorola MC68040 at 33 MHz** (non-Turbo: 25 MHz). A small number of "25 MHz Turbo" systems exist — these have the Turbo chipset but run at 25 MHz, still **15% faster** than first-generation non-Turbo boards due to chipset improvements. The Turbo chipset is identified by the **absence** of the large Fujitsu ASIC present on non-Turbo boards, and by having **4 SIMM slots** versus 8 on older designs.

### No DIP switches or jumpers

The NeXTstation motherboard has **no user-accessible DIP switches or jumpers**. All configuration is performed through the ROM Monitor `p` command and stored in NVRAM. SCSI device IDs are set via jumpers **on the drives themselves**, not on the motherboard.

### Memory configuration

| Parameter | Specification |
|-----------|--------------|
| **SIMM type** | 72-pin, FPM |
| **SIMM speed** | **70 ns** recommended; 80 ns or 100 ns will work but the memory clock slows to 100 ns |
| **SIMM slots** | 4 (Turbo); installed in **pairs** (interleaved) |
| **SIMM capacities** | 1 MB, 4 MB, 8 MB, 16 MB, 32 MB per SIMM |
| **Maximum RAM** | **128 MB** (4 × 32 MB) |
| **Minimum for NeXTSTEP 3.3** | **16 MB**; 24 MB recommended |
| **Parity** | Optional; x36 parity SIMMs supported, enabled via NVRAM |
| **Pairing rule** | SIMMs in a pair must be identical in capacity and speed; different pairs may differ |

Use the `m` command at the ROM Monitor to verify memory configuration. Turbo boards report sockets 0–3; non-Turbo boards report sockets 0–15.

### SCSI subsystem

The SCSI controller is an **NCR 53C90A** with NeXT-designed DMA (Integrated Channel Processor). It supports SCSI-1, 8-bit narrow, with synchronous transfers up to **~4 MB/s**. Internal connector is 50-pin IDC ribbon; external is Micro DB-50 (SCSI-2 physical connector).

### Display configuration

Monochrome Turbo systems output **1120 × 832 at 2-bit grayscale** (4 shades) over the proprietary DB-19 connector to the MegaPixel Display. Color Turbo systems output **1120 × 832 at 12-bit color** (4,096 colors) over a 13W3 connector. The MegaPixel Display (N4000/N4000A for non-ADB, **N4000B for ADB**) carries video, power, sound, and keyboard/mouse signals through the single DB-19 cable. No firmware display settings exist — resolution and bit depth are fixed by hardware.

### Serial console access

Both RS-423 serial ports use **Mini-DIN 8** connectors. Port A serves as the alternate console. Settings: **9600 baud, 8N1, no flow control**. The null modem wiring from NeXT Mini-DIN 8 to DB-9 RS-232:

| NeXT Pin | Signal | DB-9 Pin | Signal |
|----------|--------|----------|--------|
| 3 | TXD | 2 | RXD |
| 5 | RXD | 3 | TXD |
| 4 | GND | 5 | GND |
| 1 | DTR | 1 | DCD |
| 2 | DCD | 4 | DTR |
| 6 | RTS | 8 | CTS |
| 8 | CTS | 7 | RTS |

For headless operation without a MegaPixel Display, simulate a power button press by connecting a **~470 Ω resistor** between pin 6 (MON PWR SWITCH) and pin 19 (GND) on the DB-19 connector momentarily.

---

## 4. Boot drive requirements for NeXTSTEP 3.3

### Partition table and filesystem

NeXT uses its own **proprietary disk label format** — not MBR, not GPT. The label is **7,240 bytes** stored at offset 0 (sector 0) of the disk. It contains disk geometry, partition definitions, boot block pointers, and a checksum. The filesystem is a **4.3BSD UFS variant** (listed as type `4.3` in `/etc/fstab`, distinct from FreeBSD's `4.2BSD`). NeXTSTEP disks, including CD-ROMs, use this format — NeXT CDs are **not ISO 9660**.

### On-disk boot structure

The boot blocks are laid out as follows (for 512-byte sector disks):

| Region | Location | Size | Content |
|--------|----------|------|---------|
| Disk label | Block 0 | 7,240 bytes | Geometry, partition table, boot block pointers |
| Front porch | Blocks 0–319 | **320 blocks** | Housekeeping area including boot blocks |
| First-stage boot (z0) | Block **64** | — | Primary bootstrap loader |
| Second-stage boot (z1) | Block **192** | — | Secondary bootstrap (`/usr/standalone/boot`) |
| Root filesystem (partition a) | After front porch | Variable | UFS filesystem with kernel `sdmach` |

For 1024-byte sector disks, front porch is 160 blocks, z0 at block 32, z1 at block 96. The `disk` command writes these structures: `disk -t <disktype> -i /dev/rsd1a` installs the label, boot blocks, and creates UFS filesystems.

### SCSI ID conventions

| SCSI ID | Assignment |
|---------|-----------|
| **0** | Internal hard drive (boot device) |
| 1–5 | Additional devices (external drives, ZIP, etc.) |
| **6** | CD-ROM drive (recommended) |
| **7** | NeXTstation SCSI host adapter (NCR 53C90A) |

The boot drive **must have a lower SCSI ID** than the CD-ROM. Violating this causes SCSI device enumeration failures. The ROM Monitor's `bsd()` command boots from the lowest SCSI ID by default.

**Critical detail about the boot command's controller parameter**: the `ctrl` value in `bsd(ctrl,unit,part)` is a **logical index** (ordinal), not the SCSI ID. The ROM scans SCSI IDs from lowest to highest and assigns sequential indices. With drives at IDs 0 and 6, `bsd(0,0,0)` boots ID 0 and `bsd(1,0,0)` boots ID 6.

### Maximum partition size and the disktab

Individual partitions are limited to **2 GB** (4,194,304 blocks × 512 bytes). Larger drives must be split across multiple partitions. A bug in `BuildDisk` and `/usr/etc/disk` in NeXTSTEP 3.2 and earlier miscalculates geometry for drives exceeding 2 GB — manual disktab entries are required (documented in NeXTAnswers #1533).

The `/etc/disktab` file defines drive geometry. Key fields include `ty=fixed_rw_scsi` for type, `nc#`/`nt#`/`ns#` for CHS geometry (obtainable via `scsimodes`), `fp#320` for front porch size, `os=sdmach` for the boot kernel name, `z0#64`/`z1#192` for boot block locations, and `ba#8192`/`fa#1024` for UFS block/fragment sizes.

### Initializing a new drive

The standard procedure: low-level format with `sdform /dev/rsd1a` → get geometry with `scsimodes /dev/rsd1a` → create `/etc/disktab` entry → write label and filesystems with `disk -t <type> -i /dev/rsd1a`. The GUI alternative is `/NextAdmin/BuildDisk.app`, though it has the >2 GB bug in early versions.

---

## 5. Booting NeXTSTEP 3.3 from CD-ROM

**Only Turbo systems can boot directly from CD-ROM.** Non-Turbo machines must bootstrap through a floppy disk (`bfd -s`) or network boot, which then hands off to the CD.

### CD-ROM boot procedure on a Turbo

1. Set the CD-ROM drive to **SCSI ID 6** (or any ID 2–6; must be higher than the hard drive)
2. Insert the NeXTSTEP 3.3 installation CD
3. Enter the ROM Monitor (Command + ~ at startup)
4. Issue the boot command:

```
NeXT> bsd(n,0,0) sdmach -s rootdev=sdn
```

Where `n` is the **logical device index** of the CD-ROM — not its SCSI ID. If the only two SCSI devices present are a hard drive at ID 0 and a CD-ROM at ID 6, the CD-ROM is logical index 1:

```
NeXT> bsd(1,0,0) sdmach -s rootdev=sd1
```

### CD-ROM requirements

NeXTSTEP 3.3 CDs use the **NeXT disk label + UFS format**, not ISO 9660. The drive must be SCSI (not IDE/ATAPI). The NeXTSTEP 3.3 m68k/Intel installation CD and the SPARC/HPPA CD are separate media. For m68k, the CD must provide standard 512-byte sectors to the SCSI bus.

### Installation sequence

After booting from CD: language selection screen → installation menu → target disk selection → disk initialization (takes entire disk, no dual-boot) → base system copy → reboot → hard drive mounts as `/`, CD mounts as `/NEXTSTEP_INSTALL` → package installation continues → final configuration wizard. The installer writes `/etc/fstab` entries mapping `sd0a` to `/` and `sd1a` to `/NEXTSTEP_INSTALL`.

---

## 6. Power-on self-test and diagnostic capabilities

### POST sequence

When the Turbo powers on, the ROM executes hardware tests before attempting to boot. The screen shows a **"Testing System"** banner during POST. If any test fails, it changes to **"System Failed"**. In verbose mode, each test name and result is printed sequentially.

The POST sub-tests, all controllable via the `p` command:

- **DRAM test** — walks all installed memory; time-consuming with 128 MB, so it's separately enabled
- **Sound out tests** — exercises the Motorola 56001 DSP and audio circuitry
- **SCSI tests** — probes and tests the SCSI bus and connected devices
- **Verbose test mode** — displays the name and system message of every test step (essential for diagnosing boot problems)
- **Loop until keypress** — repeats all tests continuously for burn-in or intermittent fault detection

### Extended diagnostics and error codes

The **"boot extended diagnostics"** parameter causes the ROM to look for a `diagnostic` root file on reboot — this was a NeXT-internal technician tool and should normally be set to `no`. The `ec` command at the ROM Monitor prints **recorded system error codes** from the last boot attempt. Known error codes range from **0x41 to 0xE2**, documented in the NeXT Network & System Administration guide. These include CPU exceptions, memory faults, and SCSI errors.

The NeXTstation does **not use PC-style beep codes**. The power LED has minimal diagnostic function — it is either off (no power) or on (system running). Primary diagnostic output is on-screen or via serial console.

---

## 7. Common boot failures and how to fix them

### Dead NVRAM battery — the universal problem

Every surviving NeXTstation has a dead clock battery after 30+ years. The battery is typically a **Dallas DS1287** (or similar) with an entombed lithium cell. When dead, **all NVRAM resets to factory defaults**, and the boot command reverts to `en()` (network boot). The machine tries to netboot, finds no server, and either hangs "waiting for network" or drops to the ROM Monitor.

**Immediate fix**: Enter ROM Monitor → `p` → change boot command from `en` to `sd` → Return through remaining parameters → Power key to shut down → power on. This must be repeated at every power cycle until the battery is replaced. **Permanent fix**: replace the Dallas chip with a DS12887A, or Dremel open the package and solder an external CR2032 holder to the battery contacts.

### ROM version compatibility

| ROM Version | System | Key limitations |
|-------------|--------|----------------|
| v63 | Early 68040 | No ADB, no CD boot |
| v66 | Non-Turbo 68040 | Last non-Turbo ROM; no ADB, no CD boot |
| v73 | Pre-production | "Science experiment" — ADB code has bugs; very rare |
| **v74** | **Turbo (production)** | **Required for ADB peripherals, CD-ROM boot** |

ROMs are **not interchangeable** between Turbo and non-Turbo boards. A v74 ROM on a non-Turbo board will not work. Swapping ROMs also changes the machine's Ethernet MAC address, since the MAC is stored in ROM.

### SCSI termination

The SCSI bus must be terminated at **both physical ends**. The NCR 53C90A host adapter (ID 7) sits at one end. The internal hard drive (typically ID 0) must be terminated if it is the last device on the internal cable. If external SCSI devices are daisy-chained, only the **last device on the external chain** should be terminated; double-termination causes ghosted devices, timeouts, and boot hangs. In verbose mode, every SCSI device should appear during bus scan — a missing drive indicates a termination, cable, or power problem.

### Power supply failures

The Sony-manufactured PSU is the **most common hardware failure point**. MOSFET transistors fail from insufficient cooling, and 30-year-old electrolytic capacitors dry out. The **-12V rail** must supply at least **2A** (3.3A during MegaPixel Display CRT startup) — standard PC ATX supplies typically only provide 0.3A at -12V, making direct ATX substitution problematic without modification. Symptoms include a completely dead system, intermittent boots, or overheating.

### Capacitor degradation

Surface-mount electrolytic capacitors on the motherboard leak over decades, corroding PCB traces and damaging surrounding components. Turbo Color boards have documented capacitor replacement guides. Symptoms include intermittent crashes, sound problems, video artifacts, and failure to boot.

### Other failure modes

**Kernel not found**: A corrupt `/mach` kernel produces `sdmach: not found / load failed`. Recovery: boot single-user (`bsd -s`) or from floppy/CD, mount the hard drive, and copy a fresh kernel. **Filesystem corruption**: boot single-user and run `fsck`. **SCSI timeout errors**: check termination, cables, and power; use `/usr/etc/reasb` to reassign bad blocks. **Sound chip blocking boot**: if DSP hardware has failed, disable "sound out tests" in the ROM Monitor to bypass the hang. **MO drive bug**: a known NeXTSTEP bug causes slowdowns when both internal drives are connected but only one disk is inserted.

---

## 8. NeXTSTEP 3.3 version-specific requirements on Turbo hardware

**NeXTSTEP 3.3** (released 1995) was the **final NeXTSTEP release** and the most refined version for black hardware. It added HP PA-RISC and Sun SPARC support alongside Intel x86 and Motorola 68K. The Mach kernel version string reads: `NeXT Mach 3.3: Mon Oct 24 13:56:37 PDT 1994; root(rcbuilder):mk-171.9.obj~2/RC_m68k/RELEASE_M68K`.

### System requirements for 3.3 on 68040 Turbo

| Requirement | Specification |
|-------------|--------------|
| **Minimum RAM** | 16 MB |
| **Recommended RAM** | 24 MB |
| **Maximum addressable** | 256 MB (128 MB hardware limit on Turbo) |
| **Minimum disk (User)** | 150 MB; 250 MB recommended |
| **Minimum disk (User + Developer)** | 330 MB; 400 MB recommended |
| **Partition limit** | 2 GB per partition |
| **ROM version** | v74 required for Turbo systems with ADB peripherals |

### Differences from earlier versions and OPENSTEP

NeXTSTEP 3.3 is the most complete release for 68040 hardware. Compared to 3.1 and 3.2, it includes bug fixes, broader hardware support, and the final patch set (**Patch 3** for RISC, Developer Patch 2 for development tools). OPENSTEP 4.x (the successor, effectively "NeXTSTEP 4") continued to support 68040 hardware but reorganized APIs around the OpenStep specification. Some 3.3 applications require recompilation for OPENSTEP 4.x. OPENSTEP 4.2 was the final release on any platform.

### Known 3.3-specific issues

The **SCSI ID ordering bug during installation** is the most impactful: if the CD-ROM is assigned a lower SCSI ID than the hard drive, the installer writes swapped `/etc/fstab` entries, causing an infinite boot loop that restarts the installation. Always set the CD-ROM to a higher SCSI ID than the boot drive. The **BuildDisk >2 GB bug** from 3.2 persists in some configurations — manual disktab creation is the workaround for large drives. NeXTSTEP 3.3's floppy drive reads NeXT, Mac, and DOS formats but **formats only NeXT 2.88 MB Extended Density**.

### Turbo-specific considerations

The 33 MHz Turbo reports `System type: 5` and `Board revision: 0xf` via `hostinfo`. The rare 25 MHz Turbo variant has the same chipset and supports all Turbo features (128 MB RAM, ADB, CD boot) — it is 15% faster than the original 25 MHz non-Turbo despite the identical clock speed, due to chipset improvements. All Turbo boards are identified by 4 SIMM slots (versus 8 on non-Turbo) and the absence of the large Fujitsu ASIC.

## Conclusion

Bringing a NeXTstation Turbo up on NeXTSTEP 3.3 in 2026 is primarily a battle against dead batteries and aging capacitors, not configuration complexity. The ROM Monitor's `p` command is the single control surface for all firmware settings — there is no separate BIOS or jumper configuration. The critical first step is always setting the boot command from `en` to `sd`. For installation from CD, the Turbo's v74 ROM enables direct CD boot via `bsd(n,0,0)` — a capability non-Turbo systems lack entirely. SCSI termination discipline (both ends, never double-terminated) and correct ID ordering (boot drive lower than CD-ROM, host adapter at 7) prevent the most common SCSI failures. With 70 ns 72-pin SIMMs in matched pairs, the Turbo supports up to 128 MB — well above the 16 MB minimum for 3.3. The Sony PSU and motherboard capacitors are the remaining hardware risks, but with those addressed, the platform is remarkably straightforward: one firmware interface, one disk label format, one filesystem, and a boot architecture that has not changed since 1988.