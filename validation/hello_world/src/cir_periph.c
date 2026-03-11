/*
 * cir_periph.c
 * CIR (Coprocessor Interface Register) driver — AN-947 dialog protocol
 * over AXI-Lite.
 */

#include "cir_periph.h"
#include "xil_printf.h"

/* ------------------------------------------------------------------ */
/* Poll CIR_RESPONSE until non-BUSY                                    */
/* ------------------------------------------------------------------ */
u16 cir_poll_response(void)
{
    for (int i = 0; i < CIR_TIMEOUT_POLLS; i++) {
        u32 resp = cir_rd(OFF_CIR_RESPONSE);
        u16 r = (u16)(resp & 0xFFFFu);
        if (i < 5)
            xil_printf("  [poll %d] resp=0x%08lx r=0x%04x\r\n",
                       i, resp, (unsigned)r);
        if (r != CIR_BUSY)
            return r;
    }
    xil_printf("  [poll TIMEOUT]\r\n");
    return 0;   /* timeout — returns BUSY (0) */
}

/* ------------------------------------------------------------------ */
/* Poll until NULL release                                             */
/* ------------------------------------------------------------------ */
int cir_wait_null(void)
{
    for (int i = 0; i < CIR_TIMEOUT_POLLS; i++) {
        u32 resp = cir_rd(OFF_CIR_RESPONSE);
        u16 r = (u16)(resp & 0xFFFFu);
        if (r == CIR_NULL)
            return CIR_OK;
    }
    xil_printf("  [wait_null TIMEOUT]\r\n");
    return CIR_TIMEOUT;
}

/* ------------------------------------------------------------------ */
/* Register-to-register dialog                                         */
/* CIR_IDLE -> write Command + OpWord -> poll BUSY -> NULL             */
/* ------------------------------------------------------------------ */
int cir_cpgen_reg_to_reg(u8 src_reg, u8 dst_reg, u8 opcode)
{
    u16 cmd = CIR_CMD_REG(src_reg, dst_reg, opcode);

    /* Ensure CIR mode is active (may have been disabled by peripheral ops). */
    cir_wr(OFF_CIR_RESPONSE, 1);

    /* Write Command before OpWord: the FSM leaves CIR_IDLE only when
     * both cir_command_written and cir_opword_written are set.  Writing
     * Command first ensures command_reg is latched before the OpWord
     * write completes the pair and lets the FSM advance. */
    cir_wr(OFF_CIR_COMMAND, (u32)cmd);
    cir_wr(OFF_CIR_OPWORD, CIR_OPWORD_CPGEN);

    return cir_wait_null();
}

/* ------------------------------------------------------------------ */
/* Memory-to-register dialog                                           */
/* CIR_IDLE -> write Command + OpWord -> poll XFER_TO_CP              */
/*   -> write operand words -> poll NULL                               */
/* ------------------------------------------------------------------ */
int cir_cpgen_mem_to_reg(u8 fmt, u8 dst_reg, u8 opcode,
                         const u32 *operand_words, int word_count)
{
    if (word_count < 1 || word_count > 3)
        return CIR_TIMEOUT;  /* invalid transfer size */

    u16 cmd = CIR_CMD_MEM2REG(fmt, dst_reg, opcode);

    /* Ensure CIR mode is active (may have been disabled by peripheral ops). */
    cir_wr(OFF_CIR_RESPONSE, 1);

    xil_printf("  [m2r] cmd=0x%04x resp_before=0x%04x\r\n",
               (unsigned)cmd,
               (unsigned)(cir_rd(OFF_CIR_RESPONSE) & 0xFFFFu));

    cir_wr(OFF_CIR_COMMAND, (u32)cmd);
    xil_printf("  [m2r] after cmd: resp=0x%04x\r\n",
               (unsigned)(cir_rd(OFF_CIR_RESPONSE) & 0xFFFFu));

    cir_wr(OFF_CIR_OPWORD, CIR_OPWORD_CPGEN);
    xil_printf("  [m2r] after opw: resp=0x%04x status=0x%02x\r\n",
               (unsigned)(cir_rd(OFF_CIR_RESPONSE) & 0xFFFFu),
               (unsigned)(cir_rd(OFF_STATUS) & 0x7Fu));

    /* Poll for XFER_TO_CP_* and validate response primitive */
    u16 resp = cir_poll_response();
    if (resp == 0)
        return CIR_TIMEOUT;

    u16 expected_resp = (word_count == 1) ? CIR_XFER_TO_CP_4 :
                        (word_count == 2) ? CIR_XFER_TO_CP_8 : CIR_XFER_TO_CP_12;
    if (resp != expected_resp) {
        xil_printf("  [m2r] unexpected resp: got 0x%04x, expected 0x%04x\r\n",
                   (unsigned)resp, (unsigned)expected_resp);
        return CIR_TIMEOUT;
    }

    /* Write operand words to CIR_OPERAND */
    for (int i = 0; i < word_count; i++)
        cir_wr(OFF_CIR_OPERAND, operand_words[i]);

    return cir_wait_null();
}

/* ------------------------------------------------------------------ */
/* Register-to-memory readback dialog                                  */
/* CIR_IDLE -> write Command + OpWord -> poll XFER_FROM_CP            */
/*   -> read operand words -> poll NULL                                */
/* ------------------------------------------------------------------ */
int cir_cpgen_reg_to_mem(u8 fmt, u8 src_reg,
                         u32 *result_words, int word_count)
{
    if (word_count < 1 || word_count > 3)
        return CIR_TIMEOUT;  /* invalid transfer size */

    u16 cmd = CIR_CMD_REG2MEM(fmt, src_reg, FPOP_MOVE);

    /* Ensure CIR mode is active (may have been disabled by peripheral ops). */
    cir_wr(OFF_CIR_RESPONSE, 1);

    cir_wr(OFF_CIR_COMMAND, (u32)cmd);
    cir_wr(OFF_CIR_OPWORD, CIR_OPWORD_CPGEN);

    /* Poll for XFER_FROM_CP_* and validate response primitive */
    u16 resp = cir_poll_response();
    if (resp == 0)
        return CIR_TIMEOUT;

    u16 expected_resp = (word_count == 1) ? CIR_XFER_FROM_CP_4 :
                        (word_count == 2) ? CIR_XFER_FROM_CP_8 : CIR_XFER_FROM_CP_12;
    if (resp != expected_resp) {
        xil_printf("  [r2m] unexpected resp: got 0x%04x, expected 0x%04x\r\n",
                   (unsigned)resp, (unsigned)expected_resp);
        return CIR_TIMEOUT;
    }

    /* Read operand words from CIR_OPERAND */
    for (int i = 0; i < word_count; i++)
        result_words[i] = cir_rd(OFF_CIR_OPERAND);

    return cir_wait_null();
}
