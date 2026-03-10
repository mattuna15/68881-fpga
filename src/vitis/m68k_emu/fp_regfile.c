/*
 * fp_regfile.c
 * Software FP80 register file — 8 data registers + 3 control registers.
 */

#include "fp_regfile.h"

static fp80_t fp_regs[8];
static unsigned int fpcr_shadow;
static unsigned int fpsr_shadow;
static unsigned int fpiar_shadow;

void fp_reg_init(void)
{
    for (int i = 0; i < 8; i++)
        fp_regs[i] = FP80_ZERO;
    fpcr_shadow  = 0;
    fpsr_shadow  = 0;
    fpiar_shadow = 0;
}

fp80_t fp_reg_get(int reg)
{
    return fp_regs[reg & 7];
}

void fp_reg_set(int reg, fp80_t val)
{
    fp_regs[reg & 7] = val;
}

void fp_reg_set_fpcr(unsigned int val)  { fpcr_shadow = val; }
unsigned int fp_reg_get_fpcr(void)      { return fpcr_shadow; }
void fp_reg_set_fpsr(unsigned int val)  { fpsr_shadow = val; }
unsigned int fp_reg_get_fpsr(void)      { return fpsr_shadow; }
void fp_reg_set_fpiar(unsigned int val) { fpiar_shadow = val; }
unsigned int fp_reg_get_fpiar(void)     { return fpiar_shadow; }
