#include <stdio.h>
#include <math.h>
#include "../lib/merlin2_gfx.h"
#include "../lib/merlin2_rand.h"

/* 640x480 viewport centred on 1280x720 framebuffer */
#define VP_W    640
#define VP_H    480
#define VP_X    320
#define VP_Y    120
_Static_assert(VP_X + VP_W <= GFX_SCREEN_W, "Viewport exceeds screen width");
_Static_assert(VP_Y + VP_H <= GFX_SCREEN_H, "Viewport exceeds screen height");

/* Physics */
#define GRAVITY     0.06f
#define PARTICLES_PER_BURST 32

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
    float old_x, old_y;
    float vx, vy;
    uint32_t colour;
    int life;
    int max_life;
} particle_t;

static rocket_t rocket;
static particle_t particles[PARTICLES_PER_BURST];

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

static uint32_t dim_colour(uint32_t colour, int life, int max_life)
{
    if (max_life <= 0 || life <= 0)
        return 0xFF000000;
    unsigned r = (colour >> 16) & 0xFF;
    unsigned g = (colour >> 8) & 0xFF;
    unsigned b = colour & 0xFF;
    r = r * (unsigned)life / (unsigned)max_life;
    g = g * (unsigned)life / (unsigned)max_life;
    b = b * (unsigned)life / (unsigned)max_life;
    return 0xFF000000 | (r << 16) | (g << 8) | b;
}

static void spawn_rocket(void)
{
    rocket.x = (float)rand_range(120, VP_W - 120);
    rocket.y = (float)(VP_H - 1);
    rocket.dy = -4.0f - (float)rand_range(0, 15) * 0.1f;
    rocket.target_y = (float)rand_range(80, VP_H / 3);
    rocket.colour = palette[rand_range(0, (int)PALETTE_SIZE - 1)];
    rocket.state = ROCKET_RISING;
}

static void burst_rocket(void)
{
    float speed_base = 1.5f;
    int i;
    for (i = 0; i < PARTICLES_PER_BURST; i++) {
        particle_t *p = &particles[i];
        float angle = (float)i * (2.0f * (float)M_PI / (float)PARTICLES_PER_BURST);
        float speed = speed_base + (float)rand_range(0, 10) * 0.1f;
        p->x = rocket.x;
        p->y = rocket.y;
        p->old_x = rocket.x;
        p->old_y = rocket.y;
        p->vx = cosf(angle) * speed;
        p->vy = sinf(angle) * speed;
        p->colour = rocket.colour;
        p->max_life = rand_range(30, 50);
        p->life = p->max_life;
    }
    rocket.state = ROCKET_BURST;
}

static int update_and_draw(void)
{
    int alive = 0;
    int i;

    /* Update rocket */
    if (rocket.state == ROCKET_RISING) {
        /* Erase old position */
        put_pixel((int)rocket.x, (int)rocket.y + 1, 0xFF000000);
        rocket.y += rocket.dy;
        /* Draw rocket */
        put_pixel((int)rocket.x, (int)rocket.y, 0xFFFFFFFF);
        if (rocket.y <= rocket.target_y)
            burst_rocket();
    }

    /* Update particles */
    for (i = 0; i < PARTICLES_PER_BURST; i++) {
        particle_t *p = &particles[i];
        if (p->life <= 0)
            continue;

        /* Erase at old position */
        put_pixel((int)p->old_x, (int)p->old_y, 0xFF000000);

        /* Physics */
        p->vy += GRAVITY;
        p->old_x = p->x;
        p->old_y = p->y;
        p->x += p->vx;
        p->y += p->vy;
        p->life--;

        /* Bounds check */
        if ((int)p->x < 0 || (int)p->x >= VP_W ||
            (int)p->y < 0 || (int)p->y >= VP_H) {
            p->life = 0;
            continue;
        }

        /* Draw at new position with fading colour */
        uint32_t c = dim_colour(p->colour, p->life, p->max_life);
        put_pixel((int)p->x, (int)p->y, c);
        alive++;
    }

    return alive;
}

int main(void)
{
    int i;

    printf("Fireworks demo - press any key to exit\n");

    rand_seed(gfx_get_time());
    gfx_set_mode(1);
    gfx_clear(0xFF000000);

    rocket.state = ROCKET_DEAD;
    for (i = 0; i < PARTICLES_PER_BURST; i++)
        particles[i].life = 0;

    spawn_rocket();

    while (!gfx_char_ready()) {
        int alive = update_and_draw();

        /* Spawn next rocket when current burst dies */
        if (rocket.state != ROCKET_RISING && alive == 0)
            spawn_rocket();
    }

    gfx_set_mode(0);
    printf("Done.\n");
    return 0;
}
