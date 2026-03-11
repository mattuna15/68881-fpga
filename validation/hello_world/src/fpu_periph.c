/*
 * fpu_periph.c
 * FPU peripheral driver — register-mapped interface over AXI-Lite.
 * Refactored from mc68881_e2e_test.c.
 */

#include "fpu_periph.h"

/* ------------------------------------------------------------------ */
/* Bus probe                                                           */
/* ------------------------------------------------------------------ */
int fpu_probe(void)
{
    /* Switch from default CIR mode to peripheral mode so that OPB/OPA
     * writes hit the operand registers instead of the CIR decode. */
    fpu_wr(OFF_CIR_MODE, 0);

    u32 status = fpu_rd(OFF_STATUS);
    if (status == 0xFFFFFFFFu)
        return FPU_BUS_ERR;
    return FPU_OK;
}

/* ------------------------------------------------------------------ */
/* Operand load / result read                                          */
/* ------------------------------------------------------------------ */
void fpu_load_opa(fp80_t v)
{
    fpu_wr(OFF_OPA_L, v.l);
    fpu_wr(OFF_OPA_H, v.h);
    fpu_wr(OFF_OPA_E, v.e);
}

void fpu_load_opb(fp80_t v)
{
    fpu_wr(OFF_OPB_L, v.l);
    fpu_wr(OFF_OPB_H, v.h);
    fpu_wr(OFF_OPB_E, v.e);
}

fp80_t fpu_read_res(void)
{
    fp80_t r;
    r.l = fpu_rd(OFF_RES_L);
    r.h = fpu_rd(OFF_RES_H);
    r.e = fpu_rd(OFF_RES_E) & 0xFFFFu;
    return r;
}

/* ------------------------------------------------------------------ */
/* Wait for completion                                                 */
/* ------------------------------------------------------------------ */
int fpu_wait_done(void)
{
    for (int i = 0; i < FPU_TIMEOUT_POLLS; i++)
        if (fpu_rd(OFF_STATUS) & STATUS_VALID)
            return FPU_OK;
    return FPU_TIMEOUT;
}

/* ------------------------------------------------------------------ */
/* Execute binary operation                                            */
/* ------------------------------------------------------------------ */
int fpu_exec(u8 opcode, fp80_t a, fp80_t b, fp80_t *result)
{
    fpu_wr(OFF_CIR_MODE, 0);   /* Ensure peripheral mode (OPA/OPB overlap CIR) */
    fpu_load_opa(a);
    fpu_load_opb(b);
    fpu_wr(OFF_OPSEL, OPSEL(opcode));

    int rc = fpu_wait_done();
    if (rc != FPU_OK)
        return rc;

    if (result)
        *result = fpu_read_res();
    return FPU_OK;
}

/* ------------------------------------------------------------------ */
/* Execute unary/monadic operation                                     */
/* ------------------------------------------------------------------ */
int fpu_exec_unary(u8 opcode, fp80_t a, fp80_t *result)
{
    fpu_wr(OFF_CIR_MODE, 0);   /* Ensure peripheral mode (OPA overlaps CIR) */
    fpu_load_opa(a);
    fpu_wr(OFF_OPSEL, OPSEL(opcode));

    int rc = fpu_wait_done();
    if (rc != FPU_OK)
        return rc;

    if (result)
        *result = fpu_read_res();
    return FPU_OK;
}

/* ------------------------------------------------------------------ */
/* FMOVECR: load constant from ROM                                    */
/* ------------------------------------------------------------------ */
int fpu_movecr(u8 rom_offset, fp80_t *result)
{
    fpu_wr(OFF_CIR_MODE, 0);   /* Ensure peripheral mode (OPA_L overlaps CIR) */
    fpu_wr(OFF_MOVE_CFG, MOVE_CFG_FMOVECR(0));   /* dst_idx=0 */
    fpu_wr(OFF_OPA_L, rom_offset & 0x7Fu);        /* constant code */
    fpu_wr(OFF_OPSEL, OPSEL(FPOP_MOVE));           /* trigger MOVE */

    int rc = fpu_wait_done();
    if (rc != FPU_OK)
        return rc;

    if (result)
        *result = fpu_read_res();
    return FPU_OK;
}

/* ------------------------------------------------------------------ */
/* Control / status registers                                          */
/* ------------------------------------------------------------------ */
u32 fpu_read_fpsr(void)        { return fpu_rd(OFF_FPSR); }
u32 fpu_read_fpcr(void)        { return fpu_rd(OFF_FPCR); }
void fpu_write_fpcr(u32 val)   { fpu_wr(OFF_FPCR, val); }
u32 fpu_read_fpiar(void)       { return fpu_rd(OFF_FPIAR); }
void fpu_write_fpiar(u32 val)  { fpu_wr(OFF_FPIAR, val); }

/* ------------------------------------------------------------------ */
/* FP80 comparison with tolerance                                      */
/* Exact match on exp+sign, then allow significand to differ by        */
/* up to tol_hi:tol_lo ULPs.                                          */
/* ------------------------------------------------------------------ */
int fp80_close(fp80_t got, fp80_t exp, u32 tol_hi, u32 tol_lo)
{
    if (got.e != exp.e)
        return 0;

    /* 64-bit abs(got_sig - exp_sig) via manual subtraction */
    u32 dh, dl;
    int borrow;
    if (got.h > exp.h || (got.h == exp.h && got.l >= exp.l)) {
        dl = got.l - exp.l;
        borrow = (got.l < exp.l) ? 1 : 0;
        dh = got.h - exp.h - borrow;
    } else {
        dl = exp.l - got.l;
        borrow = (exp.l < got.l) ? 1 : 0;
        dh = exp.h - got.h - borrow;
    }

    if (dh > tol_hi) return 0;
    if (dh < tol_hi) return 1;
    return dl <= tol_lo;
}
