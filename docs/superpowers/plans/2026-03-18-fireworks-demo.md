# Fireworks Demo Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a particle fireworks demo in C that runs on the Merlin 2 with hardware FPU, producing rising rockets that burst into fading particle circles with gravity and trail effects.

**Architecture:** Reusable graphics/RNG library in `toolchain/lib/`, fireworks demo in `toolchain/examples/fireworks.c`. TRAP #15 inline assembly wrappers for BIOS calls. Direct framebuffer writes at `0x800000` for performance. 640x480 viewport centred on 1280x720 display.

**Tech Stack:** m68k-elf-gcc 14.2.0, `-m68000 -m68881 -ffast-math`, Merlin 2 BSP, TRAP #15 BIOS calls, hardware FSIN/FCOS.

**Spec:** `docs/superpowers/specs/2026-03-18-fireworks-demo-design.md`

---

## Task 1: Create graphics library header and source

**Files:**
- Create: `toolchain/lib/merlin2_gfx.h`
- Create: `toolchain/lib/merlin2_gfx.c`

- [ ] **Step 1: Create `toolchain/lib/merlin2_gfx.h`**

```c
#ifndef MERLIN2_GFX_H
#define MERLIN2_GFX_H

#include <stdint.h>

/* Framebuffer constants */
#define GFX_FB_BASE     0x800000
#define GFX_SCREEN_W    1280
#define GFX_SCREEN_H    720

/* TRAP #15 wrappers */
void gfx_set_mode(int mode);
void gfx_clear(uint32_t colour);
void gfx_set_pixel(int x, int y, uint32_t argb);
void gfx_screen_info(int *w, int *h);
uint32_t gfx_get_time(void);
int gfx_char_ready(void);

/* Direct framebuffer access */
static inline volatile uint32_t *gfx_fb_ptr(int x, int y)
{
    return (volatile uint32_t *)(GFX_FB_BASE + (y * GFX_SCREEN_W + x) * 4);
}

#endif /* MERLIN2_GFX_H */
```

- [ ] **Step 2: Create `toolchain/lib/merlin2_gfx.c`**

Implement each TRAP #15 wrapper using inline assembly. The calling convention is:
function number in D0.B, parameters in D1/D2/D3, results returned in D1/D2.

```c
#include "merlin2_gfx.h"

void gfx_set_mode(int mode)
{
    register long d0 __asm__("d0") = 17;
    register long d1 __asm__("d1") = mode;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1) : : "memory");
}

void gfx_clear(uint32_t colour)
{
    register long d0 __asm__("d0") = 18;
    register long d1 __asm__("d1") = (long)colour;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1) : : "memory");
}

void gfx_set_pixel(int x, int y, uint32_t argb)
{
    register long d0 __asm__("d0") = 19;
    register long d1 __asm__("d1") = x;
    register long d2 __asm__("d2") = y;
    register long d3 __asm__("d3") = (long)argb;
    __asm__ volatile("trap #15" : "+d"(d0), "+d"(d1), "+d"(d2), "+d"(d3) : : "memory");
}

void gfx_screen_info(int *w, int *h)
{
    register long d0 __asm__("d0") = 21;
    register long d1 __asm__("d1");
    register long d2 __asm__("d2");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1), "=d"(d2) : : "memory");
    if (w) *w = (int)(d1 & 0xFFFF);
    if (h) *h = (int)(d2 & 0xFFFF);
}

uint32_t gfx_get_time(void)
{
    register long d0 __asm__("d0") = 8;
    register long d1 __asm__("d1");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1) : : "memory");
    return (uint32_t)d1;
}

int gfx_char_ready(void)
{
    register long d0 __asm__("d0") = 7;
    register long d1 __asm__("d1");
    __asm__ volatile("trap #15" : "+d"(d0), "=d"(d1) : : "memory");
    return (int)(d1 & 1);
}
```

- [ ] **Step 3: Commit**

```bash
git add toolchain/lib/merlin2_gfx.h toolchain/lib/merlin2_gfx.c
git commit -m "Add merlin2_gfx library: TRAP #15 graphics wrappers and direct FB access"
```

---

## Task 2: Create random number library

**Files:**
- Create: `toolchain/lib/merlin2_rand.h`
- Create: `toolchain/lib/merlin2_rand.c`

- [ ] **Step 1: Create `toolchain/lib/merlin2_rand.h`**

```c
#ifndef MERLIN2_RAND_H
#define MERLIN2_RAND_H

#include <stdint.h>

void rand_seed(uint32_t s);
uint32_t rand_next(void);
int rand_range(int min, int max);

#endif /* MERLIN2_RAND_H */
```

- [ ] **Step 2: Create `toolchain/lib/merlin2_rand.c`**

```c
#include "merlin2_rand.h"

static uint32_t rng_state = 1;

void rand_seed(uint32_t s)
{
    rng_state = s ? s : 1;
}

uint32_t rand_next(void)
{
    /* LCG: Numerical Recipes constants */
    rng_state = rng_state * 1664525u + 1013904223u;
    return rng_state;
}

int rand_range(int min, int max)
{
    if (min >= max) return min;
    uint32_t r = rand_next();
    return min + (int)(r % (unsigned)(max - min + 1));
}
```

- [ ] **Step 3: Commit**

```bash
git add toolchain/lib/merlin2_rand.h toolchain/lib/merlin2_rand.c
git commit -m "Add merlin2_rand library: LCG random number generator"
```

---

## Task 3: Write fireworks demo

**Files:**
- Create: `toolchain/examples/fireworks.c`

- [ ] **Step 1: Create `toolchain/examples/fireworks.c`**

```c
#include <stdio.h>
#include <math.h>
#include "../lib/merlin2_gfx.h"
#include "../lib/merlin2_rand.h"

/* Viewport (centred on 1280x720) */
#define VP_W    640
#define VP_H    480
#define VP_X    320
#define VP_Y    120

/* Physics */
#define GRAVITY     0.05f
#define MAX_ROCKETS 4
#define PARTICLES_PER_BURST 64
#define MAX_PARTICLES (MAX_ROCKETS * PARTICLES_PER_BURST)

/* Rocket states */
#define ROCKET_DEAD    0
#define ROCKET_RISING  1
#define ROCKET_BURST   2

typedef struct {
    float x, y;
    float dy;
    float target_y;
    uint32_t colour;
    int state;
} rocket_t;

typedef struct {
    float x, y;
    float vx, vy;
    uint32_t colour;
    int life;
} particle_t;

static rocket_t rockets[MAX_ROCKETS];
static particle_t particles[MAX_PARTICLES];

static const uint32_t palette[] = {
    0xFFFF2020,  /* red */
    0xFFFFD700,  /* gold */
    0xFF20FF20,  /* green */
    0xFF4080FF,  /* blue */
    0xFFFFFFFF,  /* white */
    0xFFFF40FF,  /* magenta */
};
#define PALETTE_SIZE (sizeof(palette) / sizeof(palette[0]))

static inline void put_pixel(int x, int y, uint32_t argb)
{
    if ((unsigned)x < VP_W && (unsigned)y < VP_H)
        *gfx_fb_ptr(x + VP_X, y + VP_Y) = argb;
}

static void fade_framebuffer(void)
{
    volatile uint32_t *p = gfx_fb_ptr(VP_X, VP_Y);
    int row, col;
    for (row = 0; row < VP_H; row++) {
        volatile uint32_t *rowp = p + row * GFX_SCREEN_W;
        for (col = 0; col < VP_W; col++) {
            uint32_t px = rowp[col];
            rowp[col] = (px >> 1) & 0x7F7F7F7F;
        }
    }
}

static uint32_t dim_colour(uint32_t colour, int life, int max_life)
{
    /* Scale RGB by life/max_life */
    unsigned r = (colour >> 16) & 0xFF;
    unsigned g = (colour >> 8) & 0xFF;
    unsigned b = colour & 0xFF;
    r = r * (unsigned)life / (unsigned)max_life;
    g = g * (unsigned)life / (unsigned)max_life;
    b = b * (unsigned)life / (unsigned)max_life;
    return 0xFF000000 | (r << 16) | (g << 8) | b;
}

static void spawn_rocket(rocket_t *r)
{
    r->x = (float)rand_range(100, VP_W - 100);
    r->y = (float)(VP_H - 1);
    r->dy = -3.0f - (float)rand_range(0, 20) * 0.1f;
    r->target_y = (float)rand_range(80, VP_H / 2);
    r->colour = palette[rand_range(0, (int)PALETTE_SIZE - 1)];
    r->state = ROCKET_RISING;
}

static void burst_rocket(rocket_t *r)
{
    float speed_base = 2.0f;
    int base = (int)(r - rockets) * PARTICLES_PER_BURST;
    int i;
    for (i = 0; i < PARTICLES_PER_BURST; i++) {
        particle_t *p = &particles[base + i];
        float angle = (float)i * (2.0f * (float)M_PI / (float)PARTICLES_PER_BURST);
        float speed = speed_base + (float)rand_range(0, 10) * 0.1f;
        p->x = r->x;
        p->y = r->y;
        p->vx = cosf(angle) * speed;
        p->vy = sinf(angle) * speed;
        p->colour = r->colour;
        p->life = rand_range(40, 70);
    }
    r->state = ROCKET_BURST;
}

static void update_rockets(void)
{
    int i;
    for (i = 0; i < MAX_ROCKETS; i++) {
        rocket_t *r = &rockets[i];
        if (r->state == ROCKET_RISING) {
            r->y += r->dy;
            /* Draw rocket trail */
            put_pixel((int)r->x, (int)r->y, 0xFFFFFFFF);
            if (r->y <= r->target_y)
                burst_rocket(r);
        }
    }
}

static int update_particles(void)
{
    int alive = 0;
    int i;
    for (i = 0; i < MAX_PARTICLES; i++) {
        particle_t *p = &particles[i];
        if (p->life <= 0)
            continue;
        p->vy += GRAVITY;
        p->x += p->vx;
        p->y += p->vy;
        p->life--;
        if ((int)p->x < 0 || (int)p->x >= VP_W ||
            (int)p->y < 0 || (int)p->y >= VP_H) {
            p->life = 0;
            continue;
        }
        uint32_t c = dim_colour(p->colour, p->life, 70);
        put_pixel((int)p->x, (int)p->y, c);
        alive++;
    }
    return alive;
}

static int count_active_rockets(void)
{
    int n = 0, i;
    for (i = 0; i < MAX_ROCKETS; i++)
        if (rockets[i].state == ROCKET_RISING)
            n++;
    return n;
}

static int any_burst_alive(int rocket_idx)
{
    int base = rocket_idx * PARTICLES_PER_BURST;
    int i;
    for (i = 0; i < PARTICLES_PER_BURST; i++)
        if (particles[base + i].life > 0)
            return 1;
    return 0;
}

int main(void)
{
    int i;

    printf("Fireworks demo — press any key to exit\n");

    rand_seed(gfx_get_time());
    gfx_set_mode(1);
    gfx_clear(0xFF000000);

    /* Clear particle/rocket state */
    for (i = 0; i < MAX_ROCKETS; i++)
        rockets[i].state = ROCKET_DEAD;
    for (i = 0; i < MAX_PARTICLES; i++)
        particles[i].life = 0;

    while (!gfx_char_ready()) {
        uint32_t frame_start = gfx_get_time();

        fade_framebuffer();
        update_rockets();
        update_particles();

        /* Spawn rockets: keep at least 2 rising, reuse dead slots */
        if (count_active_rockets() < 2) {
            for (i = 0; i < MAX_ROCKETS; i++) {
                if (rockets[i].state == ROCKET_DEAD ||
                    (rockets[i].state == ROCKET_BURST && !any_burst_alive(i))) {
                    spawn_rocket(&rockets[i]);
                    break;
                }
            }
        }

        /* Frame pacing: ~30ms target */
        while (gfx_get_time() - frame_start < 30)
            ;
    }

    gfx_set_mode(0);
    printf("Done.\n");
    return 0;
}
```

- [ ] **Step 2: Commit**

```bash
git add toolchain/examples/fireworks.c
git commit -m "Add particle fireworks demo using hardware FPU and direct framebuffer"
```

---

## Task 4: Update Makefile and build

**Files:**
- Modify: `toolchain/examples/Makefile`

- [ ] **Step 1: Update Makefile to add fireworks target and lib include path**

Add `-I../lib` to `FPU_CFLAGS`, add `fireworks.c` to sources, and add the
fireworks build rule that compiles the lib sources alongside:

```makefile
# Merlin 2 GCC examples
#
# Usage:
#   make              -- build all examples
#   make hello.srec   -- build just hello
#   make clean        -- remove build artifacts

PREFIX  ?= m68k-elf-
CC       = $(PREFIX)gcc
CFLAGS   = -m68000 -O2 -Wall
LDFLAGS  = -Tmerlin2.ld

# Library sources
LIB_DIR  = ../lib
LIB_SRCS = $(LIB_DIR)/merlin2_gfx.c $(LIB_DIR)/merlin2_rand.c

# FPU examples need -m68881
FPU_CFLAGS = $(CFLAGS) -m68881 -Wa,-mcpu=68020 -ffast-math -I$(LIB_DIR)

all: hello.srec hello.lst fputest.srec fputest.lst fireworks.srec fireworks.lst

# Non-FPU targets
hello.srec: hello.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

hello.lst: hello.c
	$(CC) $(CFLAGS) -S -fverbose-asm -o $@ $<

# FPU targets
fputest.srec: fputest.c
	$(CC) $(FPU_CFLAGS) $(LDFLAGS) -o $@ $< -lm

fputest.lst: fputest.c
	$(CC) $(FPU_CFLAGS) -S -fverbose-asm -o $@ $<

# Fireworks (FPU + graphics library)
fireworks.srec: fireworks.c $(LIB_SRCS)
	$(CC) $(FPU_CFLAGS) $(LDFLAGS) -o $@ $< $(LIB_SRCS) -lm

fireworks.lst: fireworks.c
	$(CC) $(FPU_CFLAGS) -I$(LIB_DIR) -S -fverbose-asm -o $@ $<

clean:
	rm -f *.srec *.lst *.o
```

- [ ] **Step 2: Build via Cygwin**

```bash
/c/cygwin64/bin/bash.exe -l -c "export PATH=/home/mattp/.local/bin:\$PATH && cd /cygdrive/c/code/68881-fpga/toolchain/examples && make clean && make all 2>&1"
```

Expected: all `.srec` and `.lst` files built with no errors.

- [ ] **Step 3: Verify fireworks.lst contains FSIN/FCOS instructions**

```bash
/c/cygwin64/bin/bash.exe -l -c "export PATH=/home/mattp/.local/bin:\$PATH && grep -i 'fsin\|fcos\|fmul\|fadd' /cygdrive/c/code/68881-fpga/toolchain/examples/fireworks.lst | head -10"
```

Expected: hardware FPU instructions present (not `jsr sin`/`jsr cos`).

- [ ] **Step 4: Verify no 68020 opcodes in linked binary**

```bash
/c/cygwin64/bin/bash.exe -l -c "export PATH=/home/mattp/.local/bin:\$PATH && m68k-elf-objcopy -I srec -O binary /cygdrive/c/code/68881-fpga/toolchain/examples/fireworks.srec /tmp/fw.bin && m68k-elf-objdump -D -b binary -m m68k:68020 /tmp/fw.bin | grep -E 'extb|muls\.l|divs\.l|divu\.l|mulu\.l' | head -5"
```

Expected: empty output (68000-pure).

- [ ] **Step 5: Commit**

```bash
git add toolchain/examples/Makefile
git commit -m "Add fireworks to examples Makefile with lib sources"
```

---

## Task 5: Test on hardware and final commit

- [ ] **Step 1: Load and run on Merlin 2**

1. Transfer `fireworks.srec` to the Merlin 2 serial terminal
2. Use BIOS `L` command to load
3. Run with `G 2004`
4. Visual check: rockets rise from bottom, burst into circular particles, trails fade, gravity pulls particles down
5. Press any key to exit — should return to monitor prompt

- [ ] **Step 2: Iterate if needed**

If particles are too fast/slow, adjust:
- `GRAVITY` (0.05f) — increase for faster droop
- Rocket `dy` (-3.0f base) — increase magnitude for faster rise
- `speed_base` (2.0f) — burst expansion speed
- Frame delay (30ms) — decrease for faster animation
- Particle `life` (40-70 range) — increase for longer trails

- [ ] **Step 3: Final commit with built .srec**

```bash
git add toolchain/examples/fireworks.srec toolchain/examples/fireworks.lst
git commit -m "Add fireworks demo built artefacts"
```

- [ ] **Step 4: Push and update PR**

```bash
git push origin graphics
```
