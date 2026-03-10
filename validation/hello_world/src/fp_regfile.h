/*
 * fp_regfile.h
 * Software FP80 register file — mirrors the 8 data registers
 * inside a real mc68881. Maintained in ARM memory; the hardware
 * FPU operates on explicit OPA/OPB registers instead.
 */

#ifndef FP_REGFILE_H
#define FP_REGFILE_H

#include "fpu_periph.h"   /* fp80_t */

/* Reset all 8 FP registers to positive zero */
void fp_reg_init(void);

/* Get / set individual FP data registers (0..7) */
fp80_t fp_reg_get(int reg);
void   fp_reg_set(int reg, fp80_t val);

/* FPCR / FPSR / FPIAR shadow registers */
void fp_reg_set_fpcr(unsigned int val);
unsigned int fp_reg_get_fpcr(void);
void fp_reg_set_fpsr(unsigned int val);
unsigned int fp_reg_get_fpsr(void);
void fp_reg_set_fpiar(unsigned int val);
unsigned int fp_reg_get_fpiar(void);

#endif /* FP_REGFILE_H */
