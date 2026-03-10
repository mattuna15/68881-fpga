/*
 * periph_smoke.h
 * Peripheral-mode smoke test — validates fpu_periph API against
 * known e2e_test.c vectors (no Musashi, no emulator).
 */

#ifndef PERIPH_SMOKE_H
#define PERIPH_SMOKE_H

/* Run peripheral smoke tests. Returns number of failures. */
int periph_smoke_run(void);

#endif /* PERIPH_SMOKE_H */
