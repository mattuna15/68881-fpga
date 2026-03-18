#include "merlin2_rand.h"

static uint32_t rng_state = 1;

void rand_seed(uint32_t s)
{
    rng_state = s ? s : 1;
}

uint32_t rand_next(void)
{
    rng_state = rng_state * 1664525u + 1013904223u;
    return rng_state;
}

int rand_range(int min, int max)
{
    if (min >= max) return min;
    uint32_t r = rand_next();
    return min + (int)(r % (unsigned)(max - min + 1));
}
