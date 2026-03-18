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

    printf("Fireworks demo - press any key to exit\n");

    rand_seed(gfx_get_time());
    gfx_set_mode(1);
    gfx_clear(0xFF000000);

    for (i = 0; i < MAX_ROCKETS; i++)
        rockets[i].state = ROCKET_DEAD;
    for (i = 0; i < MAX_PARTICLES; i++)
        particles[i].life = 0;

    while (!gfx_char_ready()) {
        uint32_t frame_start = gfx_get_time();

        fade_framebuffer();
        update_rockets();
        update_particles();

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
