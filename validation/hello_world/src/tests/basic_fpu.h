/*
 * basic_fpu.h
 * Integration test: Musashi + F-line handler + hardware FPU.
 * Uses hand-assembled M68K FPU instruction sequences.
 */

#ifndef BASIC_FPU_H
#define BASIC_FPU_H

/* Run basic FPU integration tests. Returns number of failures. */
int basic_fpu_run(void);

#endif /* BASIC_FPU_H */
