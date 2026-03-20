# Merlin 2 GCC Cross-Compiler Toolchain

M68K GCC cross-compiler for the Merlin 2 emulator, built under Cygwin on Windows.

Builds **binutils 2.44**, **GCC 14.2.0** (C and C++), and **newlib 4.5.0** for `m68k-elf`,
with a Merlin 2 Board Support Package (BSP) that uses TRAP #15 BIOS calls for serial I/O.

## Prerequisites

### Cygwin packages

Install Cygwin from <https://www.cygwin.com/>, then add required packages:

```bash
setup-x86_64.exe -q -P gcc-core,gcc-g++,make,bison,flex,texinfo,wget,autoconf,automake,libtool
```

Verify autotools Perl modules are working:

```bash
autoreconf --version
```

If it fails with Perl errors, reinstall the `autoconf` and `automake` packages.

### Existing tools

These are already available on the Merlin 2 development machine:

- **vasm** (m68k assembler): `C:\code\vasm68k\vasmm68k_mot.exe`
- **GHDL**: `C:\code\ghdl-mcode-5.1.1-mingw64\bin\ghdl.exe`

## Building

```bash
cd toolchain
make all        # Full build (~30-60 min)
```

Individual stages can be built separately:

```bash
make binutils     # Cross binutils (as, ld, objdump, etc.)
make gcc-stage1   # GCC compiler (no libgcc yet)
make newlib       # Newlib C library + Merlin 2 BSP
make gcc-libgcc   # Rebuild libgcc against newlib
```

The toolchain installs to `~/.local` by default. Override with:

```bash
make all INSTALL_DIR=/path/to/install
```

### 68000 ISA purity

GCC is configured with `--with-cpu=68000` and `CFLAGS_FOR_TARGET="-mcpu=68000"` to
ensure all generated code and libraries (libgcc, newlib) use only 68000-legal
instructions. Without this, GCC's default m68k target is 68020, and library code
(e.g. `__divsi3`, `__mulsi3`) would contain 68020-only opcodes like `extb.l`,
`muls.l`, and 32-bit displacement addressing modes.

The `-Wa,-mcpu=68020` flag is passed only to the **assembler** so it accepts
coprocessor (F-line) opcodes; it does not affect code generation.

## Usage

Add the install directory to your PATH:

```bash
export PATH=$HOME/.local/bin:$PATH
```

Compile a C program for Merlin 2:

```bash
m68k-elf-gcc -m68000 -O2 -Tmerlin2.ld -o program.srec program.c
```

For programs using the FPU (68881):

```bash
m68k-elf-gcc -m68000 -m68881 -Wa,-mcpu=68020 -ffast-math -O2 -Tmerlin2.ld -o program.srec program.c -lm
```

### Compiler flags

| Flag | Purpose |
|------|---------|
| `-m68000` | Target 68000 CPU (Merlin 2 runs a 68000 with FPU via F-line trapping) |
| `-m68881` | Enable FPU instructions (68881/68882) |
| `-Wa,-mcpu=68020` | Tell assembler to accept FPU opcodes (required with `-m68000 -m68881`) |
| `-ffast-math` | Allow GCC to replace libm calls (`sin`, `cos`, etc.) with hardware FPU instructions (`FSIN`, `FCOS`, etc.). Without this, GCC calls newlib's software float library instead of using the 68881 |
| `-O2` | Optimisation level |
| `-Tmerlin2.ld` | Use Merlin 2 linker script (S-record output) |
| `-lm` | Link math library (for any remaining soft-float functions) |

### `-ffast-math` and hardware transcendentals

By default, GCC with `-m68881` only uses the FPU for basic arithmetic (`FMOVE`,
`FADD`, `FMUL`, `FDIV`). Calls to `sin()`, `cos()`, `tan()`, etc. still link
against newlib's software implementation, which does **not** use the 68881.

Adding `-ffast-math` allows GCC to emit hardware instructions directly:

| C function | Without `-ffast-math` | With `-ffast-math` |
|------------|----------------------|-------------------|
| `sin(x)` | `jsr sin` (software) | `fsin.x %fp0,%fp1` |
| `cos(x)` | `jsr cos` (software) | `fcos.x %fp0,%fp1` |
| `sqrt(x)` | `jsr sqrt` (software) | `fsqrt.x %fp0,%fp1` |

This dramatically reduces code size (no soft-float library pulled in) and
executes on the FPGA FPU hardware.

### Loading and running

1. Output is in Motorola S-record format (`.srec`)
2. Load into the Merlin 2 emulator using the monitor's `L` command
3. Execute with `G 2004` (program entry point, after the data section)

On exit, the program returns cleanly to the BIOS monitor prompt. The BSP's
`_exit()` restores the monitor stack pointer saved at startup by `crt0.S`,
then uses `RTS` to return to the BIOS after its `JSR` dispatch.

Programs are **re-runnable** — `G 2004` works repeatedly without reloading
the S-record. The crt0 startup code backs up the `.data` section on first
run and restores it on subsequent runs, giving newlib's `printf` and
`malloc` a clean initial state each time.

## Examples

Build the example programs:

```bash
make examples
```

| Example | Description | FPU? |
|---------|-------------|------|
| `hello.c` | Serial "Hello" message | No |
| `fputest.c` | `sin(1.0)` via hardware `FSIN` | Yes |
| `fireworks.c` | Particle fireworks with gravity and trails | Yes |
| `rtctest.c` | RTC date/time display, set, and tick counter | No |

Verified output (all re-runnable without reload):

```
>G 2004
Hello from Merlin 2 GCC!
>G 2004
Hello from Merlin 2 GCC!
>G 2004
sin(1.000000) = 0.841471
```

See `examples/` for source code and `examples/Makefile` for build flags.

## GCC cross-compiler

The GCC cross-compiler is built from the `merlin-68k-toolchain/` git submodule
(upstream, unmodified) with Merlin 2-specific adaptations in the top-level
`Makefile`:

- `--with-cpu=68000` ensures 68000 is the default target for all libraries
- `CFLAGS_FOR_TARGET="-mcpu=68000"` passed to both GCC and libgcc builds
- `--disable-multilib` — single library variant (68000-only)
- newlib built with `-mcpu=68000` and Merlin 2 BSP patched in

After building, the toolchain is installed to `~/.local/bin/` and includes:

| Tool | Purpose |
|------|---------|
| `m68k-elf-gcc` | C/C++ compiler |
| `m68k-elf-as` | Assembler |
| `m68k-elf-ld` | Linker |
| `m68k-elf-objdump` | Disassembler (useful for verifying no 68020 leakage) |
| `m68k-elf-objcopy` | Binary format conversion |
| `m68k-elf-nm` | Symbol table listing |

To verify no 68020 instructions in a linked binary:

```bash
m68k-elf-objcopy -I srec -O binary program.srec program.bin
m68k-elf-objdump -D -b binary -m m68k:68020 program.bin | grep -E 'extb|muls\.l|divs\.l|divu\.l|mulu\.l'
```

An empty result confirms 68000 ISA purity.

## Memory map

| Region | Address range | Size | Purpose |
|--------|--------------|------|---------|
| BIOS workspace | `0x000000`-`0x001FFF` | 8 KB | Exception vectors, BIOS variables |
| Program RAM | `0x002000`-`0x7FDFFF` | ~8 MB | Code + data + BSS + heap |
| Stack | `0x7FDFFC` (grows down) | | Set by linker script |
| Framebuffer | `0x800000`-`0xB84FFF` | 3.6 MB | 1280x720 ARGB8888 |
| I/O registers | `0xFD0000`-`0xFD003F` | 64 bytes | MFP (USART, timers, RTC, datetime) |
| Graphics I/O | `0xFD0040`-`0xFD004F` | 16 bytes | Video mode, clear, screen info |
| BIOS ROM | `0xFE0000` | | Monitor firmware |

## Merlin 2 BSP

The BSP provides newlib syscall stubs via TRAP #15 BIOS calls:

| Function | TRAP #15 D0 | Description |
|----------|-------------|-------------|
| `_exit()` | N/A | Restores monitor SP, returns to BIOS via RTS |
| `outbyte(c)` | 6 | Write char (D1.B), `\n` -> `\r\n` |
| `inbyte()` | 5 | Read char -> D0 |
| `havebyte()` | 7 | Check RX ready -> D0 (0/1) |

Additional TRAP #15 functions:

| Function | TRAP D0 | Description |
|----------|---------|-------------|
| `gfx_set_mode()` | 17 | Switch text/graphics mode |
| `gfx_clear()` | 18 | Clear framebuffer with ARGB colour |
| `gfx_set_pixel()` | 19 | Set pixel (bounds-checked) |
| `gfx_get_pixel()` | 20 | Read pixel |
| `gfx_screen_info()` | 21 | Query screen dimensions |
| `rtc_get_time()` | 22 | Get Unix timestamp (seconds) |
| `rtc_get_datetime()` | 23 | Get BCD datetime (YYYYMMDD + HHMMSSwd) |
| `rtc_set_time()` | 24 | Set Unix timestamp |
| `rtc_get_ticks()` | 25 | Get Timer C tick counter (~133 Hz) |

See `merlin2-bsp/merlin2.h` for the complete function list.

### BSP quick rebuild

To update the BSP without a full newlib rebuild (e.g. after editing `crt0.S`
or `merlin2.S`):

```bash
bash merlin2-bsp/install-crt0.sh
```

This rebuilds `merlin2-crt0.o`, `libmerlin2.a`, and installs the linker
script to `~/.local/m68k-elf/lib/`.

## Directory structure

```
toolchain/
  merlin-68k-toolchain/    # Git submodule (upstream, unmodified)
  merlin2-bsp/             # Merlin 2 BSP (TRAP #15 stubs)
    merlin2.S              # Syscall implementations
    merlin2.ld             # Linker script
    merlin2.h              # TRAP #15 function constants
    crt0.S                 # 68000-compatible startup (.data backup/restore, monitor SP)
    install-crt0.sh        # Quick BSP rebuild script (crt0 + libmerlin2 + linker script)
  lib/                     # Reusable C libraries
    merlin2_gfx.h/c        # Graphics TRAP wrappers + direct FB access
    merlin2_rand.h/c       # LCG random number generator
    merlin2_rtc.h/c        # RTC and Timer C tick wrappers
    merlin2_sbrk.c         # Custom sbrk (zeroes heap, starts above .data backup)
  examples/                # Example programs
    hello.c                # Serial hello world
    fputest.c              # Hardware FPU sin() test
    fireworks.c            # Particle fireworks demo (FPU + graphics)
    rtctest.c              # RTC display, set, and tick counter
    Makefile
  Makefile                 # Top-level build wrapper
  README.md                # This file
```
