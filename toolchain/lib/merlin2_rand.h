#ifndef MERLIN2_RAND_H
#define MERLIN2_RAND_H

#include <stdint.h>

void rand_seed(uint32_t s);
uint32_t rand_next(void);
int rand_range(int min, int max);

#endif /* MERLIN2_RAND_H */
