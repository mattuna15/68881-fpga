# Particle Fireworks Demo — Design Spec

## Context
First C-based graphics demo for the Merlin 2 GCC toolchain, exercising the
MC68881 FPGA FPU (FSIN/FCOS via `-ffast-math`) and direct framebuffer writes.
Builds on the newly verified GCC cross-compiler toolchain.

## Display
- 640x480 viewport centred on 1280x720 framebuffer
- Offset: (320, 120)
- Pixel address: `0x800000 + ((y+120)*1280 + (x+320))*4`
- Direct framebuffer writes for particle rendering
- TRAP #15 for mode switching (D0=17) and initial clear (D0=18)

## Particle System
- Max 4 rockets, each bursts into 64 particles (256 particles max)
- Rocket: position (x,y), velocity (dy), target height, colour, state (rising/burst/dead)
- Particle: position (x,y float), velocity (vx,vy float), colour (ARGB), life (ticks)
- Gravity: ~0.05 pixels/tick applied to vy each frame
- Particles die at life=0 or outside viewport

## Burst Geometry
- 64 particles per burst, uniform circle: angle = `i * (2*PI/64)`
- Hardware FSIN/FCOS for angle decomposition
- Speed = base + random variation
- Colour inherited from rocket, dims with remaining life

## Frame Loop
1. Fade: sweep 640x480, `pixel = (pixel >> 1) & 0x7F7F7F7F`
2. Update rockets: advance, check burst height, spawn particles
3. Update particles: gravity, position, decrement life
4. Draw particles: write ARGB to framebuffer (bounds check)
5. Spawn new rocket if fewer than 2 active
6. Frame pace via TRAP #15 D0=8 (GET_TIME), ~30ms target

## Reusable Library (`toolchain/lib/`)
Thin wrappers, no abstraction layers:

**merlin2_gfx.h/c:**
- `gfx_set_mode(int mode)` — TRAP #15 D0=17
- `gfx_clear(uint32_t colour)` — TRAP #15 D0=18
- `gfx_set_pixel(int x, int y, uint32_t argb)` — TRAP #15 D0=19
- `gfx_screen_info(int *w, int *h)` — TRAP #15 D0=21
- `gfx_fb_ptr(int x, int y)` — returns volatile uint32_t* for direct writes
- `gfx_get_time(void)` — TRAP #15 D0=8

**merlin2_rand.h/c:**
- `rand_seed(uint32_t s)`
- `rand_next(void)` — LCG, returns uint32_t
- `rand_range(int min, int max)`

## Random Number Generator
- LCG seeded from GET_TIME at startup
- Used for: launch x, colour selection, speed variation, target height

## Colour Palette
6 burst colours: red, gold, green, blue, white, magenta — one per burst,
selected randomly at launch.

## Build
- New file: `toolchain/examples/fireworks.c`
- Library sources: `toolchain/lib/merlin2_gfx.c`, `toolchain/lib/merlin2_rand.c`
- Added to Makefile as FPU target: `-m68881 -ffast-math`
- Examples include lib sources directly (no .a library)

## File Layout
```
toolchain/
  lib/
    merlin2_gfx.h
    merlin2_gfx.c
    merlin2_rand.h
    merlin2_rand.c
  examples/
    fireworks.c
    Makefile        # updated with fireworks target
```

## Verification
- Load fireworks.srec via BIOS `L` command
- Run with `G 2004`
- Visual: rockets rise, burst into particle circles, trails fade, gravity droop
- Returns to monitor on keypress or after timeout
