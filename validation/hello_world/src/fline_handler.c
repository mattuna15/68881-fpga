/*
 * fline_handler.c
 * F-line (coprocessor) instruction handler for the Musashi M68K emulator.
 *
 * When Musashi encounters an F-line opcode ($Fxxx), it calls
 * fline_illg_callback(). We decode the 68881 instruction, fetch
 * operands from the software register file or M68K memory, drive
 * the hardware FPU via fpu_periph, and write the result back.
 *
 * Reference: MC68881/MC68882 Floating-Point Coprocessor User's Manual
 *
 * F-line opword format (first word):
 *   15..12 = 1111       (F-line)
 *   11..9  = CpID       (001 = FPU)
 *    8..6  = type
 *    5..0  = varies (EA mode/reg, or instruction-specific)
 *
 * Command word (second word, for type 0b000 general instructions):
 *   15     = R/M        (0=reg-to-reg, 1=memory/imm to reg)
 *   14     = 0
 *   13..10 = source spec (R/M=0: src FP reg; R/M=1: format code)
 *    9..7  = destination FP register
 *    6..0  = opcode
 */

#include "fline_handler.h"
#include "fpu_periph.h"
#include "cir_periph.h"
#include "fp_regfile.h"
#include "emu_memory.h"
#include "musashi/m68k.h"
#include "xil_printf.h"

/* ------------------------------------------------------------------ */
/* 68881 command word opcode (bits 6:0) → CORE_V1 opcode mapping       */
/* ------------------------------------------------------------------ */

/* 68881 opcode field values (from Motorola reference) */
#define M68K_FP_FMOVE     0x00
#define M68K_FP_FINT      0x01
#define M68K_FP_FSINH     0x02
#define M68K_FP_FINTRZ    0x03
#define M68K_FP_FSQRT     0x04
/* 0x05 unused */
#define M68K_FP_FLOGNP1   0x06
/* 0x07 unused */
#define M68K_FP_FETOXM1   0x08
#define M68K_FP_FTANH     0x09
#define M68K_FP_FATAN     0x0A
/* 0x0B unused */
#define M68K_FP_FASIN     0x0C
#define M68K_FP_FATANH    0x0D
#define M68K_FP_FSIN      0x0E
#define M68K_FP_FTAN      0x0F
#define M68K_FP_FETOX     0x10
#define M68K_FP_FTWOTOX   0x11
#define M68K_FP_FTENTOX   0x12
/* 0x13 unused */
#define M68K_FP_FLOGN     0x14
#define M68K_FP_FLOG10    0x15
#define M68K_FP_FLOG2     0x16
/* 0x17 unused */
#define M68K_FP_FABS      0x18
#define M68K_FP_FCOSH     0x19
#define M68K_FP_FNEG      0x1A
/* 0x1B unused */
#define M68K_FP_FACOS     0x1C
#define M68K_FP_FCOS      0x1D
#define M68K_FP_FGETEXP   0x1E
#define M68K_FP_FGETMAN   0x1F
#define M68K_FP_FDIV      0x20
#define M68K_FP_FMOD      0x21
#define M68K_FP_FADD      0x22
#define M68K_FP_FMUL      0x23
#define M68K_FP_FSGLDIV   0x24
#define M68K_FP_FREM      0x25
#define M68K_FP_FSCALE    0x26
#define M68K_FP_FSGLMUL   0x27
#define M68K_FP_FSUB      0x28
/* 0x29..0x2F unused */
#define M68K_FP_FSINCOS   0x30  /* 0x30..0x37: cos reg in bits 2:0 */
/* 0x38 = FCMP, 0x3A = FTST */
#define M68K_FP_FCMP      0x38
#define M68K_FP_FTST      0x3A

/*
 * Map 68881 7-bit opcode → CORE_V1 opcode ID.
 * Returns 0 (invalid) for unmapped opcodes.
 */
static u8 map_opcode(unsigned int m68k_op)
{
    switch (m68k_op) {
    case M68K_FP_FMOVE:    return FPOP_MOVE;
    case M68K_FP_FINT:     return FPOP_INT;
    case M68K_FP_FSINH:    return FPOP_SINH;
    case M68K_FP_FINTRZ:   return FPOP_INTRZ;
    case M68K_FP_FSQRT:    return FPOP_SQRT;
    case M68K_FP_FLOGNP1:  return FPOP_LOGNP1;
    case M68K_FP_FETOXM1:  return FPOP_ETOXM1;
    case M68K_FP_FTANH:    return FPOP_TANH;
    case M68K_FP_FATAN:    return FPOP_ATAN;
    case M68K_FP_FASIN:    return FPOP_ASIN;
    case M68K_FP_FATANH:   return FPOP_ATANH;
    case M68K_FP_FSIN:     return FPOP_SIN;
    case M68K_FP_FTAN:     return FPOP_TAN;
    case M68K_FP_FETOX:    return FPOP_ETOX;
    case M68K_FP_FTWOTOX:  return FPOP_TWOTOX;
    case M68K_FP_FTENTOX:  return FPOP_TENTOX;
    case M68K_FP_FLOGN:    return FPOP_LOGN;
    case M68K_FP_FLOG10:   return FPOP_LOG10;
    case M68K_FP_FLOG2:    return FPOP_LOG2;
    case M68K_FP_FABS:     return FPOP_ABS;
    case M68K_FP_FCOSH:    return FPOP_COSH;
    case M68K_FP_FNEG:     return FPOP_NEG;
    case M68K_FP_FACOS:    return FPOP_ACOS;
    case M68K_FP_FCOS:     return FPOP_COS;
    case M68K_FP_FGETEXP:  return FPOP_GETEXP;
    case M68K_FP_FGETMAN:  return FPOP_GETMAN;
    case M68K_FP_FDIV:     return FPOP_DIV;
    case M68K_FP_FMOD:     return FPOP_MOD;
    case M68K_FP_FADD:     return FPOP_ADD;
    case M68K_FP_FMUL:     return FPOP_MUL;
    case M68K_FP_FSGLDIV:  return FPOP_SGLDIV;
    case M68K_FP_FREM:     return FPOP_REM;
    case M68K_FP_FSCALE:   return FPOP_SCALE;
    case M68K_FP_FSGLMUL:  return FPOP_SGLMUL;
    case M68K_FP_FSUB:     return FPOP_SUB;
    case M68K_FP_FCMP:     return FPOP_CMP;
    case M68K_FP_FTST:     return FPOP_TST;
    default:
        /* FSINCOS range: 0x30..0x37 */
        if (m68k_op >= 0x30 && m68k_op <= 0x37)
            return FPOP_SINCOS;
        return 0;
    }
}

/* ------------------------------------------------------------------ */
/* Classify operations                                                 */
/* ------------------------------------------------------------------ */
static int is_dyadic(unsigned int m68k_op)
{
    switch (m68k_op) {
    case M68K_FP_FADD:  case M68K_FP_FSUB:  case M68K_FP_FMUL:
    case M68K_FP_FDIV:  case M68K_FP_FMOD:  case M68K_FP_FREM:
    case M68K_FP_FSCALE: case M68K_FP_FSGLDIV: case M68K_FP_FSGLMUL:
    case M68K_FP_FCMP:
        return 1;
    default:
        return 0;
    }
}

/* ------------------------------------------------------------------ */
/* Format codes (from command word bits 12:10 when R/M=1)              */
/*   0=Long int, 1=Single, 2=Extended, 3=Packed BCD,                   */
/*   4=Word int, 5=Double, 6=Byte int                                  */
/* ------------------------------------------------------------------ */
#define FMT_LONG     0
#define FMT_SINGLE   1
#define FMT_EXTENDED 2
#define FMT_PACKED   3
#define FMT_WORD     4
#define FMT_DOUBLE   5
#define FMT_BYTE     6

/* Size in bytes of each format for EA memory reads */
static int fmt_size(int fmt)
{
    switch (fmt) {
    case FMT_BYTE:     return 1;
    case FMT_WORD:     return 2;
    case FMT_LONG:     return 4;
    case FMT_SINGLE:   return 4;
    case FMT_DOUBLE:   return 8;
    case FMT_EXTENDED: return 12;
    case FMT_PACKED:   return 12;
    default:           return 0;
    }
}

/* ------------------------------------------------------------------ */
/* Convert memory-format operand to FP80                               */
/* ------------------------------------------------------------------ */

/* Convert 32-bit IEEE single to FP80 */
static fp80_t single_to_fp80(u32 s)
{
    u32 sign = (s >> 31) & 1;
    u32 exp  = (s >> 23) & 0xFF;
    u32 frac = s & 0x7FFFFF;

    if (exp == 0 && frac == 0)
        return FP80(sign << 15, 0, 0);  /* +-zero */

    if (exp == 0xFF) {
        /* Inf or NaN */
        u32 e = (sign << 15) | 0x7FFF;
        if (frac == 0)
            return FP80(e, 0x80000000, 0x00000000);  /* Inf: J-bit set */
        else
            return FP80(e, 0xC0000000 | (frac << 8), 0);  /* NaN: J-bit + QNaN */
    }

    if (exp == 0) {
        /* Denormal: bias is 127, extended bias is 16383 */
        /* Normalize: find leading 1 in frac */
        int shift = 0;
        u32 f = frac;
        while (!(f & 0x400000)) { f <<= 1; shift++; }
        f <<= 1; shift++;  /* shift out the implicit bit */
        u32 e16 = 16383 - 126 - shift;
        return FP80((sign << 15) | (e16 & 0x7FFF),
                    0x80000000 | (f << 8), 0);
    }

    /* Normal */
    u32 e16 = (exp - 127) + 16383;
    u32 sig_h = 0x80000000 | (frac << 8);
    return FP80((sign << 15) | (e16 & 0x7FFF), sig_h, 0);
}

/* Convert 64-bit IEEE double to FP80 */
static fp80_t double_to_fp80(u32 hi, u32 lo)
{
    u32 sign = (hi >> 31) & 1;
    u32 exp  = (hi >> 20) & 0x7FF;
    u32 frac_h = hi & 0xFFFFF;
    u32 frac_l = lo;

    if (exp == 0 && frac_h == 0 && frac_l == 0)
        return FP80(sign << 15, 0, 0);

    if (exp == 0x7FF) {
        u32 e = (sign << 15) | 0x7FFF;
        if (frac_h == 0 && frac_l == 0)
            return FP80(e, 0x80000000, 0x00000000);  /* Inf: J-bit set */
        else
            return FP80(e, 0xC0000000 | (frac_h << 11) | (frac_l >> 21),
                        frac_l << 11);  /* NaN: J-bit + QNaN */
    }

    if (exp == 0) {
        /* Denormal double → normalize */
        unsigned long long frac64 = ((unsigned long long)frac_h << 32) | frac_l;
        int shift = 0;
        while (!(frac64 & (1ULL << 51))) { frac64 <<= 1; shift++; }
        frac64 <<= 1; shift++;
        u32 e16 = 16383 - 1022 - shift;
        unsigned long long sig = (1ULL << 63) | (frac64 << 11);
        return FP80((sign << 15) | (e16 & 0x7FFF),
                    (u32)(sig >> 32), (u32)sig);
    }

    /* Normal */
    u32 e16 = (exp - 1023) + 16383;
    /* Shift 52-bit fraction into 63-bit significand, prepend J-bit */
    unsigned long long sig = ((unsigned long long)frac_h << 32) | frac_l;
    sig <<= 11;
    sig |= (1ULL << 63);  /* explicit integer bit */
    return FP80((sign << 15) | (e16 & 0x7FFF),
                (u32)(sig >> 32), (u32)sig);
}

/* Convert signed 32-bit integer to FP80 */
static fp80_t long_to_fp80(u32 val)
{
    if (val == 0)
        return FP80_ZERO;

    u32 sign = 0;
    u32 v = val;
    if (val & 0x80000000u) {
        sign = 1;
        v = ~val + 1u;  /* unsigned negate — safe for 0x80000000 */
    }

    /* Find position of MSB */
    int msb = 31;
    while (msb > 0 && !(v & (1u << msb))) msb--;

    u32 e16 = 16383 + msb;
    /* Shift value so MSB is at bit 63 of significand */
    unsigned long long sig = (unsigned long long)v << (63 - msb);

    return FP80((sign << 15) | (e16 & 0x7FFF),
                (u32)(sig >> 32), (u32)sig);
}

/* Convert signed 16-bit integer to FP80 */
static fp80_t word_to_fp80(u32 val)
{
    int sval = (short)(val & 0xFFFF);
    return long_to_fp80((u32)(int)sval);
}

/* Convert signed 8-bit integer to FP80 */
static fp80_t byte_to_fp80(u32 val)
{
    int sval = (signed char)(val & 0xFF);
    return long_to_fp80((u32)(int)sval);
}

/* ------------------------------------------------------------------ */
/* Read operand from M68K memory in the given format, advance addr     */
/* ------------------------------------------------------------------ */
static fp80_t read_mem_operand(unsigned int addr, int fmt)
{
    u32 w0, w1, w2;

    switch (fmt) {
    case FMT_BYTE:
        return byte_to_fp80(m68k_read_memory_8(addr));

    case FMT_WORD:
        return word_to_fp80(m68k_read_memory_16(addr));

    case FMT_LONG:
        return long_to_fp80(m68k_read_memory_32(addr));

    case FMT_SINGLE:
        return single_to_fp80(m68k_read_memory_32(addr));

    case FMT_DOUBLE:
        w0 = m68k_read_memory_32(addr);
        w1 = m68k_read_memory_32(addr + 4);
        return double_to_fp80(w0, w1);

    case FMT_EXTENDED:
        /* 96-bit extended in memory: sign+exp(16) + zero(16) + sig(64) */
        w0 = m68k_read_memory_32(addr);      /* [31:16]=exp, [15:0]=0 */
        w1 = m68k_read_memory_32(addr + 4);  /* sig_hi */
        w2 = m68k_read_memory_32(addr + 8);  /* sig_lo */
        return FP80((w0 >> 16) & 0xFFFF, w1, w2);

    case FMT_PACKED:
        xil_printf("FLINE: packed BCD format not implemented, substituting zero\r\n");
        return FP80_ZERO;

    default:
        xil_printf("FLINE: unknown operand format %d\r\n", fmt);
        return FP80_ZERO;
    }
}

/* ------------------------------------------------------------------ */
/* M68K effective address evaluation                                   */
/* Reads extension words from M68K memory and computes the EA.         */
/* Returns the effective address, advances *pc past extension words.    */
/* ------------------------------------------------------------------ */

/* EA mode and register from the opword bits [5:0] */
#define EA_MODE(opword)  (((opword) >> 3) & 7)
#define EA_REG(opword)   ((opword) & 7)

/*
 * Compute effective address for the given mode/reg.
 * *pc points to the first extension word (after the command word).
 * On return, *pc is advanced past any consumed extension words.
 */
static unsigned int eval_ea(int mode, int reg, unsigned int *pc)
{
    unsigned int addr;
    unsigned int ext;

    switch (mode) {
    case 0: /* Dn — data register (shouldn't reach here for FP mem ops) */
        return 0;
    case 1: /* An — address register */
        return 0;
    case 2: /* (An) */
        return m68k_get_reg(NULL, M68K_REG_A0 + reg);
    case 3: /* (An)+ — postincrement (caller must handle increment) */
        return m68k_get_reg(NULL, M68K_REG_A0 + reg);
    case 4: /* -(An) — predecrement (caller must handle decrement) */
        return m68k_get_reg(NULL, M68K_REG_A0 + reg);
    case 5: /* (d16, An) */
        ext = m68k_read_memory_16(*pc);
        *pc += 2;
        addr = m68k_get_reg(NULL, M68K_REG_A0 + reg);
        return addr + (int)(short)ext;
    case 6: /* (d8, An, Xn) — brief extension word */
        ext = m68k_read_memory_16(*pc);
        *pc += 2;
        addr = m68k_get_reg(NULL, M68K_REG_A0 + reg);
        {
            int disp = (signed char)(ext & 0xFF);
            int xreg = (ext >> 12) & 15;
            int xval;
            if (xreg < 8)
                xval = (int)m68k_get_reg(NULL, M68K_REG_D0 + xreg);
            else
                xval = (int)m68k_get_reg(NULL, M68K_REG_A0 + (xreg - 8));
            if (!(ext & 0x0800))
                xval = (int)(short)xval;  /* word index */
            return addr + disp + xval;
        }
    case 7: /* special modes based on reg */
        switch (reg) {
        case 0: /* (xxx).W — absolute short */
            ext = m68k_read_memory_16(*pc);
            *pc += 2;
            return (unsigned int)(int)(short)ext;
        case 1: /* (xxx).L — absolute long */
            addr = m68k_read_memory_32(*pc);
            *pc += 4;
            return addr;
        case 2: /* (d16, PC) */
            ext = m68k_read_memory_16(*pc);
            addr = *pc + (int)(short)ext;
            *pc += 2;
            return addr;
        case 3: /* (d8, PC, Xn) */
            ext = m68k_read_memory_16(*pc);
            addr = *pc;
            *pc += 2;
            {
                int disp = (signed char)(ext & 0xFF);
                int xreg = (ext >> 12) & 15;
                int xval;
                if (xreg < 8)
                    xval = (int)m68k_get_reg(NULL, M68K_REG_D0 + xreg);
                else
                    xval = (int)m68k_get_reg(NULL, M68K_REG_A0 + (xreg - 8));
                if (!(ext & 0x0800))
                    xval = (int)(short)xval;
                return addr + disp + xval;
            }
        case 4: /* #imm — immediate data follows in the extension words */
            /* For FP immediate, the data is inline after the command word.
             * The caller reads it via read_mem_operand at *pc.
             * We return *pc as the address and don't advance here —
             * the caller will advance after reading the operand. */
            return *pc;
        }
        break;
    }
    return 0;
}

/* ------------------------------------------------------------------ */
/* Handle type 000 general FPU instructions                            */
/* (arithmetic, move, tst, cmp, etc.)                                  */
/* ------------------------------------------------------------------ */
static int handle_general(unsigned int opword, unsigned int pc)
{
    unsigned int cmd = m68k_read_memory_16(pc);
    pc += 2;

    int rm      = (cmd >> 14) & 1;
    int src_spec = (cmd >> 10) & 7;
    int dst_reg  = (cmd >>  7) & 7;
    int m68k_op  = cmd & 0x7F;

    u8 core_op = map_opcode(m68k_op);
    if (core_op == 0 && m68k_op != M68K_FP_FMOVE) {
        xil_printf("FLINE: unknown opcode 0x%02x\r\n", m68k_op);
        m68k_set_reg(M68K_REG_PC, pc);
        return 1;
    }

    fp80_t src_val;

    if (rm == 0) {
        /* Register-to-register: src_spec = source FP register */
        src_val = fp_reg_get(src_spec);
    } else {
        /* Memory/immediate to register: src_spec = format code */
        int fmt = src_spec;
        int ea_mode = EA_MODE(opword);
        int ea_reg  = EA_REG(opword);

        unsigned int ea_addr;

        if (ea_mode == 0) {
            /* Data register direct: read Dn value, convert by format */
            u32 dreg_val = m68k_get_reg(NULL, M68K_REG_D0 + ea_reg);
            switch (fmt) {
            case FMT_BYTE:   src_val = byte_to_fp80(dreg_val & 0xFF); break;
            case FMT_WORD:   src_val = word_to_fp80(dreg_val & 0xFFFF); break;
            case FMT_LONG:   src_val = long_to_fp80(dreg_val); break;
            case FMT_SINGLE: src_val = single_to_fp80(dreg_val); break;
            default:
                xil_printf("FLINE: Dn source with fmt %d unsupported\r\n", fmt);
                m68k_set_reg(M68K_REG_PC, pc);
                return 0;  /* unhandled — let Musashi take the exception */
            }
            ea_addr = 0; /* not used */
        } else if (ea_mode == 7 && ea_reg == 4) {
            /* Immediate: data follows command word at pc */
            ea_addr = pc;
            src_val = read_mem_operand(ea_addr, fmt);
        } else if (ea_mode == 4) {
            /* Pre-decrement -(An): decrement first, then use new address */
            int opsz = fmt_size(fmt);
            unsigned int an = m68k_get_reg(NULL, M68K_REG_A0 + ea_reg);
            an -= opsz;
            m68k_set_reg(M68K_REG_A0 + ea_reg, an);
            ea_addr = an;
            src_val = read_mem_operand(ea_addr, fmt);
        } else {
            ea_addr = eval_ea(ea_mode, ea_reg, &pc);
            src_val = read_mem_operand(ea_addr, fmt);
        }

        /* Advance PC past the inline operand data */
        int operand_size = fmt_size(fmt);

        if (ea_mode == 7 && ea_reg == 4) {
            /* Immediate data: always word-aligned, round up */
            pc += (operand_size + 1) & ~1;
        }

        /* Post-increment: advance An after use */
        if (ea_mode == 3) {
            unsigned int an = m68k_get_reg(NULL, M68K_REG_A0 + ea_reg);
            m68k_set_reg(M68K_REG_A0 + ea_reg, an + operand_size);
        }
    }

    /* --- Execute the operation --- */

    fp80_t result;
    int rc;

    if (m68k_op == M68K_FP_FTST) {
        /* TST: just send to hardware for FPSR update, no result writeback */
        rc = fpu_exec_unary(FPOP_TST, src_val, &result);
        if (rc != FPU_OK)
            xil_printf("FLINE: TST timeout — FPSR not updated\r\n");
        else
            fp_reg_set_fpsr(fpu_read_fpsr());

    } else if (m68k_op == M68K_FP_FCMP) {
        /* CMP: dst - src, update FPSR, no writeback */
        fp80_t dst_val = fp_reg_get(dst_reg);
        rc = fpu_exec(FPOP_CMP, dst_val, src_val, &result);
        if (rc != FPU_OK)
            xil_printf("FLINE: CMP timeout — FPSR not updated\r\n");
        else
            fp_reg_set_fpsr(fpu_read_fpsr());

    } else if (m68k_op >= 0x30 && m68k_op <= 0x37) {
        /* FSINCOS: cos_reg = opcode[2:0], sin result to dst_reg */
        int cos_reg = m68k_op & 7;
        fp80_t sin_res, cos_res;

        /* Use SIN for dst_reg, COS for cos_reg */
        rc = fpu_exec_unary(FPOP_SIN, src_val, &sin_res);
        if (rc == FPU_OK) {
            fp_reg_set(dst_reg, sin_res);
            rc = fpu_exec_unary(FPOP_COS, src_val, &cos_res);
            if (rc == FPU_OK)
                fp_reg_set(cos_reg, cos_res);
        }
        if (rc != FPU_OK) {
            xil_printf("FLINE: SINCOS timeout\r\n");
            fp_reg_set(dst_reg, FP80_SNAN);
            fp_reg_set(cos_reg, FP80_SNAN);
        }

    } else if (is_dyadic(m68k_op)) {
        /* Dyadic: result = op(dst, src) — note: dst is first operand */
        fp80_t dst_val = fp_reg_get(dst_reg);
        rc = fpu_exec(core_op, dst_val, src_val, &result);
        if (rc != FPU_OK) {
            xil_printf("FLINE: op 0x%02x timeout\r\n", m68k_op);
            fp_reg_set(dst_reg, FP80_SNAN);
        } else {
            fp_reg_set(dst_reg, result);
        }

    } else if (m68k_op == M68K_FP_FMOVE) {
        /* FMOVE: store directly to software register file.
         * Format conversion (single/double/long/etc → FP80) is already done.
         * The hardware MOVE operates on the hardware register file (for CIR),
         * not our software register file, so we handle this in software. */
        fp_reg_set(dst_reg, src_val);

    } else {
        /* Monadic: result = op(src) */
        rc = fpu_exec_unary(core_op, src_val, &result);
        if (rc != FPU_OK) {
            xil_printf("FLINE: op 0x%02x timeout\r\n", m68k_op);
            fp_reg_set(dst_reg, FP80_SNAN);
        } else {
            fp_reg_set(dst_reg, result);
        }
    }

    m68k_set_reg(M68K_REG_PC, pc);
    return 1;
}

/* ------------------------------------------------------------------ */
/* Handle FMOVECR (type 000, R/M=0, opcode bits match)                */
/* Command word: 0 1 0 1 1 1 dst[2:0] rom_offset[6:0]                 */
/* ------------------------------------------------------------------ */
static int is_fmovecr(unsigned int cmd)
{
    /* Bits 15..10 = 010111 = 0x17 shifted left by 10 → 0x5C00 */
    return (cmd & 0xFC00) == 0x5C00;
}

static int handle_fmovecr(unsigned int cmd, unsigned int pc)
{
    int dst_reg    = (cmd >> 7) & 7;
    int rom_offset = cmd & 0x7F;

    fp80_t result;
    int rc = fpu_movecr((u8)rom_offset, &result);
    if (rc != FPU_OK) {
        xil_printf("FLINE: FMOVECR timeout\r\n");
        fp_reg_set(dst_reg, FP80_SNAN);
    } else {
        fp_reg_set(dst_reg, result);
    }

    m68k_set_reg(M68K_REG_PC, pc);
    return 1;
}

/* ------------------------------------------------------------------ */
/* Handle FBcc (type 01x: branch on FP condition)                      */
/* Opword: 1111 001 01s cccccc                                         */
/*   s=0 → 16-bit displacement, s=1 → 32-bit displacement             */
/*   cccccc = condition code                                           */
/* ------------------------------------------------------------------ */
static int handle_fbcc(unsigned int opword, unsigned int pc)
{
    int size_bit = (opword >> 6) & 1;
    int condition = opword & 0x3F;
    unsigned int branch_pc = pc;  /* PC of displacement word(s) */
    int displacement;

    if (size_bit == 0) {
        /* 16-bit displacement */
        displacement = (int)(short)m68k_read_memory_16(pc);
        pc += 2;
    } else {
        /* 32-bit displacement */
        displacement = (int)m68k_read_memory_32(pc);
        pc += 4;
    }

    /* Evaluate condition from FPSR */
    u32 fpsr = fp_reg_get_fpsr();
    /* FPSR condition code bits: N(27), Z(26), I(25), NAN(24) */
    int cc_n   = (fpsr >> 27) & 1;
    int cc_z   = (fpsr >> 26) & 1;
    int cc_i   = (fpsr >> 25) & 1;
    int cc_nan = (fpsr >> 24) & 1;

    int take_branch = 0;

    switch (condition & 0x1F) {
    case 0x00: take_branch = 0; break;                                /* F */
    case 0x01: take_branch = cc_z; break;                             /* EQ */
    case 0x02: take_branch = !(cc_nan | cc_z | cc_n); break;         /* OGT */
    case 0x03: take_branch = cc_z | !(cc_nan | cc_n); break;         /* OGE */
    case 0x04: take_branch = cc_n & !(cc_nan | cc_z); break;         /* OLT */
    case 0x05: take_branch = cc_z | (cc_n & !cc_nan); break;         /* OLE */
    case 0x06: take_branch = !(cc_nan | cc_z); break;                /* OGL */
    case 0x07: take_branch = !cc_nan; break;                         /* OR */
    case 0x08: take_branch = cc_nan; break;                          /* UN */
    case 0x09: take_branch = cc_nan | cc_z; break;                   /* UEQ */
    case 0x0A: take_branch = cc_nan | !(cc_n | cc_z); break;        /* UGT */
    case 0x0B: take_branch = cc_nan | cc_z | !cc_n; break;          /* UGE */
    case 0x0C: take_branch = cc_nan | (cc_n & !cc_z); break;        /* ULT */
    case 0x0D: take_branch = cc_nan | cc_z | cc_n; break;           /* ULE */
    case 0x0E: take_branch = !cc_z; break;                           /* NE */
    case 0x0F: take_branch = 1; break;                               /* T */
    case 0x10: take_branch = 0; break;                               /* SF */
    case 0x11: take_branch = cc_z; break;                            /* SEQ */
    case 0x12: take_branch = !(cc_nan | cc_z | cc_n); break;        /* GT */
    case 0x13: take_branch = cc_z | !(cc_nan | cc_n); break;        /* GE */
    case 0x14: take_branch = cc_n & !(cc_nan | cc_z); break;        /* LT */
    case 0x15: take_branch = cc_z | (cc_n & !cc_nan); break;        /* LE */
    case 0x16: take_branch = !(cc_nan | cc_z); break;               /* GL */
    case 0x17: take_branch = !cc_nan; break;                        /* GLE */
    case 0x18: take_branch = cc_nan; break;                         /* NGLE */
    case 0x19: take_branch = cc_nan | cc_z; break;                  /* NGL */
    case 0x1A: take_branch = cc_nan | !(cc_n | cc_z); break;       /* NLE */
    case 0x1B: take_branch = cc_nan | cc_z | !cc_n; break;         /* NLT */
    case 0x1C: take_branch = cc_nan | (cc_n & !cc_z); break;       /* NGE */
    case 0x1D: take_branch = cc_nan | cc_z | cc_n; break;          /* NGT */
    case 0x1E: take_branch = !cc_z; break;                          /* SNE */
    case 0x1F: take_branch = 1; break;                              /* ST */
    }

    if (take_branch)
        pc = branch_pc + displacement;

    m68k_set_reg(M68K_REG_PC, pc);
    return 1;
}

/* ------------------------------------------------------------------ */
/* Handle FMOVE to/from control registers (type 100/101)               */
/* Command word: 10 d dr[2:0] 0000000000                               */
/*   d=0 → ea to FPcr, d=1 → FPcr to ea                               */
/*   dr: bit 12=FPCR, bit 11=FPSR, bit 10=FPIAR                       */
/* ------------------------------------------------------------------ */
static int handle_fmove_ctrl(unsigned int opword, unsigned int cmd,
                              unsigned int pc)
{
    int direction = (cmd >> 13) & 1;  /* 0=ea→reg, 1=reg→ea */
    int regsel    = (cmd >> 10) & 7;  /* which control regs */
    int ea_mode   = EA_MODE(opword);
    int ea_reg    = EA_REG(opword);

    if (direction == 0) {
        /* EA → control register(s) */
        unsigned int ea_addr = eval_ea(ea_mode, ea_reg, &pc);
        if (regsel & 4) {
            u32 val = m68k_read_memory_32(ea_addr);
            ea_addr += 4;
            fp_reg_set_fpcr(val);
            fpu_write_fpcr(val);
        }
        if (regsel & 2) {
            u32 val = m68k_read_memory_32(ea_addr);
            ea_addr += 4;
            fp_reg_set_fpsr(val);
        }
        if (regsel & 1) {
            u32 val = m68k_read_memory_32(ea_addr);
            ea_addr += 4;
            fp_reg_set_fpiar(val);
            fpu_write_fpiar(val);
        }
    } else {
        /* Control register(s) → EA */
        unsigned int ea_addr = eval_ea(ea_mode, ea_reg, &pc);
        if (regsel & 4) {
            m68k_write_memory_32(ea_addr, fp_reg_get_fpcr());
            ea_addr += 4;
        }
        if (regsel & 2) {
            m68k_write_memory_32(ea_addr, fp_reg_get_fpsr());
            ea_addr += 4;
        }
        if (regsel & 1) {
            m68k_write_memory_32(ea_addr, fp_reg_get_fpiar());
            ea_addr += 4;
        }
    }

    m68k_set_reg(M68K_REG_PC, pc);
    return 1;
}

/* ------------------------------------------------------------------ */
/* Handle FMOVE FPn → <ea> (type 011 in command word)                  */
/* Command word: 011 fmt[2:0] dst[2:0] k-factor[6:0]                  */
/* ------------------------------------------------------------------ */
static int handle_fmove_to_mem(unsigned int opword, unsigned int cmd,
                                unsigned int pc)
{
    int fmt     = (cmd >> 10) & 7;
    int src_reg = (cmd >>  7) & 7;
    int ea_mode = EA_MODE(opword);
    int ea_reg  = EA_REG(opword);

    int operand_size = fmt_size(fmt);
    unsigned int ea_addr;

    fp80_t val = fp_reg_get(src_reg);

    if (ea_mode == 0) {
        /* Data register direct: convert FP80 and store to Dn */
        u32 result_val = 0;
        switch (fmt) {
        case FMT_LONG: case FMT_SINGLE: {
            /* Reuse the conversion logic: write to a temp and read back */
            u32 sign = (val.e >> 15) & 1;
            if (fmt == FMT_SINGLE) {
                int exp = (val.e & 0x7FFF) - 16383 + 127;
                u32 frac = (val.h >> 8) & 0x7FFFFF;
                if ((val.e & 0x7FFF) == 0x7FFF)
                    result_val = (sign << 31) | 0x7F800000 | frac;
                else if ((val.e & 0x7FFF) == 0 && val.h == 0 && val.l == 0)
                    result_val = sign << 31;
                else if (exp <= 0)
                    result_val = sign << 31;
                else if (exp >= 255)
                    result_val = (sign << 31) | 0x7F800000;
                else
                    result_val = (sign << 31) | ((u32)exp << 23) | frac;
            } else {
                /* FMT_LONG: FP80 → signed 32-bit integer */
                int exp = (val.e & 0x7FFF) - 16383;
                int shift = 63 - exp;
                unsigned long long sig = ((unsigned long long)val.h << 32) | val.l;
                int ival;
                if (exp < 0) ival = 0;
                else if (exp >= 31) ival = sign ? (int)0x80000000 : 0x7FFFFFFF;
                else { ival = (int)(sig >> shift); if (sign) ival = -ival; }
                result_val = (u32)ival;
            }
            break;
        }
        case FMT_WORD: {
            u32 sign = (val.e >> 15) & 1;
            int exp = (val.e & 0x7FFF) - 16383;
            int shift = 63 - exp;
            unsigned long long sig = ((unsigned long long)val.h << 32) | val.l;
            int ival;
            if (exp < 0) ival = 0;
            else if (exp >= 15) ival = sign ? -32768 : 32767;
            else { ival = (int)(sig >> shift); if (sign) ival = -ival; }
            /* Write lower 16 bits of Dn, preserve upper 16 */
            result_val = (m68k_get_reg(NULL, M68K_REG_D0 + ea_reg) & 0xFFFF0000)
                       | ((u32)(unsigned short)ival);
            break;
        }
        case FMT_BYTE: {
            u32 sign = (val.e >> 15) & 1;
            int exp = (val.e & 0x7FFF) - 16383;
            int shift = 63 - exp;
            unsigned long long sig = ((unsigned long long)val.h << 32) | val.l;
            int ival;
            if (exp < 0) ival = 0;
            else if (exp >= 7) ival = sign ? -128 : 127;
            else { ival = (int)(sig >> shift); if (sign) ival = -ival; }
            result_val = (m68k_get_reg(NULL, M68K_REG_D0 + ea_reg) & 0xFFFFFF00)
                       | ((u32)(unsigned char)ival);
            break;
        }
        default:
            xil_printf("FLINE: FMOVE to Dn unsupported fmt=%d\r\n", fmt);
            m68k_set_reg(M68K_REG_PC, pc);
            return 0;  /* unhandled — let Musashi take the exception */
        }
        m68k_set_reg(M68K_REG_D0 + ea_reg, result_val);
        m68k_set_reg(M68K_REG_PC, pc);
        return 1;
    }

    if (ea_mode == 4) {
        /* Pre-decrement -(An): decrement first, then use new address */
        unsigned int an = m68k_get_reg(NULL, M68K_REG_A0 + ea_reg);
        an -= operand_size;
        m68k_set_reg(M68K_REG_A0 + ea_reg, an);
        ea_addr = an;
    } else {
        ea_addr = eval_ea(ea_mode, ea_reg, &pc);
    }

    /* Convert FP80 to destination format and write to memory */
    switch (fmt) {
    case FMT_EXTENDED: {
        /* 96-bit: exp(16) + pad(16) + sig(64) */
        m68k_write_memory_32(ea_addr,     (val.e << 16));
        m68k_write_memory_32(ea_addr + 4, val.h);
        m68k_write_memory_32(ea_addr + 8, val.l);
        break;
    }
    case FMT_SINGLE: {
        /* Convert FP80 → IEEE single */
        u32 sign = (val.e >> 15) & 1;
        int exp = (val.e & 0x7FFF) - 16383 + 127;
        u32 frac = (val.h >> 8) & 0x7FFFFF;
        u32 s;
        if ((val.e & 0x7FFF) == 0x7FFF)
            s = (sign << 31) | 0x7F800000 | frac;
        else if ((val.e & 0x7FFF) == 0 && val.h == 0 && val.l == 0)
            s = sign << 31;
        else if (exp <= 0)
            s = sign << 31;  /* underflow → zero (simplified) */
        else if (exp >= 255)
            s = (sign << 31) | 0x7F800000;  /* overflow → inf */
        else
            s = (sign << 31) | ((u32)exp << 23) | frac;
        m68k_write_memory_32(ea_addr, s);
        break;
    }
    case FMT_DOUBLE: {
        u32 sign = (val.e >> 15) & 1;
        int exp = (val.e & 0x7FFF) - 16383 + 1023;
        unsigned long long sig = ((unsigned long long)val.h << 32) | val.l;
        sig <<= 1;  /* remove J-bit */
        sig >>= 12; /* 52-bit fraction */
        u32 hi, lo;
        if ((val.e & 0x7FFF) == 0x7FFF) {
            hi = (sign << 31) | 0x7FF00000 | (u32)(sig >> 32);
            lo = (u32)sig;
        } else if ((val.e & 0x7FFF) == 0 && val.h == 0 && val.l == 0) {
            hi = sign << 31; lo = 0;
        } else if (exp <= 0) {
            hi = sign << 31; lo = 0;
        } else if (exp >= 2047) {
            hi = (sign << 31) | 0x7FF00000; lo = 0;
        } else {
            hi = (sign << 31) | ((u32)exp << 20) | (u32)(sig >> 32);
            lo = (u32)sig;
        }
        m68k_write_memory_32(ea_addr, hi);
        m68k_write_memory_32(ea_addr + 4, lo);
        break;
    }
    case FMT_LONG: {
        /* Convert FP80 → signed 32-bit integer (truncate) */
        u32 sign = (val.e >> 15) & 1;
        int exp = (val.e & 0x7FFF) - 16383;
        int shift = 63 - exp;
        unsigned long long sig = ((unsigned long long)val.h << 32) | val.l;
        int ival;
        if (exp < 0)
            ival = 0;
        else if (exp >= 31)
            ival = sign ? (int)0x80000000 : 0x7FFFFFFF;  /* already signed */
        else {
            ival = (int)(sig >> shift);
            if (sign) ival = -ival;
        }
        m68k_write_memory_32(ea_addr, (u32)ival);
        break;
    }
    case FMT_WORD: {
        u32 sign = (val.e >> 15) & 1;
        int exp = (val.e & 0x7FFF) - 16383;
        int shift = 63 - exp;
        unsigned long long sig = ((unsigned long long)val.h << 32) | val.l;
        int ival;
        if (exp < 0)
            ival = 0;
        else if (exp >= 15)
            ival = sign ? -32768 : 32767;  /* already signed */
        else {
            ival = (int)(sig >> shift);
            if (sign) ival = -ival;
        }
        m68k_write_memory_16(ea_addr, (unsigned int)(short)ival);
        break;
    }
    case FMT_BYTE: {
        u32 sign = (val.e >> 15) & 1;
        int exp = (val.e & 0x7FFF) - 16383;
        int shift = 63 - exp;
        unsigned long long sig = ((unsigned long long)val.h << 32) | val.l;
        int ival;
        if (exp < 0)
            ival = 0;
        else if (exp >= 7)
            ival = sign ? -128 : 127;  /* already signed */
        else {
            ival = (int)(sig >> shift);
            if (sign) ival = -ival;
        }
        m68k_write_memory_8(ea_addr, (unsigned int)(unsigned char)ival);
        break;
    }
    default:
        xil_printf("FLINE: FMOVE to mem unsupported fmt=%d\r\n", fmt);
        break;
    }

    /* Post-increment: advance An after use */
    if (ea_mode == 3) {
        unsigned int an = m68k_get_reg(NULL, M68K_REG_A0 + ea_reg);
        m68k_set_reg(M68K_REG_A0 + ea_reg, an + operand_size);
    }

    m68k_set_reg(M68K_REG_PC, pc);
    return 1;
}

/* ------------------------------------------------------------------ */
/* FSAVE / FRESTORE via CIR cpSAVE/cpRESTORE dialog                    */
/*                                                                     */
/* Switches to CIR mode, executes the save/restore dialog to transfer  */
/* the FPU internal state frame, then returns to peripheral mode.      */
/* EmuTOS uses FSAVE/FRESTORE for FPU detection (_detect_fpu) and      */
/* context switching.                                                  */
/* ------------------------------------------------------------------ */

static void handle_fsave(unsigned int opword, unsigned int pc)
{
    int ea_mode = EA_MODE(opword);
    int ea_reg  = EA_REG(opword);

    /* --- CIR cpSAVE dialog --- */
    fpu_wr(OFF_CIR_MODE, 1);

    /* Write cpSAVE opword to start the dialog */
    cir_wr(OFF_CIR_OPWORD, CIR_OPWORD_CPSAVE);

    /* Read format word from Save CIR register.
     * FPGA transitions CIR_SAVE_WAIT → CIR_SAVE_FORMAT in one clock;
     * by the time our AXI read completes the format word is ready. */
    u16 format_word = (u16)cir_rd(OFF_CIR_SAVE);

    /* Read data words from Operand CIR.
     * Lower byte of format word = frame data size in bytes. */
    int n_words = (format_word & 0xFF) / 4;
    u32 frame_data[56];  /* max 53 words for 68882 busy frame */
    for (int i = 0; i < n_words; i++)
        frame_data[i] = cir_rd(OFF_CIR_OPERAND);

    /* Wait for CIR to return to idle */
    for (int i = 0; i < 100; i++) {
        if (cir_rd(OFF_CIR_RESPONSE) != CIR_BUSY)
            break;
    }

    /* Switch back to peripheral mode */
    fpu_wr(OFF_CIR_MODE, 0);

    /* --- Write frame to 68K memory --- */
    int total_frame_size = 4 + n_words * 4;  /* format longword + data */
    unsigned int ea_addr;

    if (ea_mode == 4) {
        /* -(An) predecrement */
        unsigned int an = m68k_get_reg(NULL, M68K_REG_A0 + ea_reg);
        an -= total_frame_size;
        m68k_set_reg(M68K_REG_A0 + ea_reg, an);
        ea_addr = an;
    } else {
        ea_addr = eval_ea(ea_mode, ea_reg, &pc);
    }

    /* Format word in upper 16 bits of first longword */
    m68k_write_memory_32(ea_addr, (u32)format_word << 16);

    /* Data words follow */
    for (int i = 0; i < n_words; i++)
        m68k_write_memory_32(ea_addr + 4 + i * 4, frame_data[i]);

    m68k_set_reg(M68K_REG_PC, pc);
}

static void handle_frestore(unsigned int opword, unsigned int pc)
{
    int ea_mode = EA_MODE(opword);
    int ea_reg  = EA_REG(opword);

    /* --- Read frame from 68K memory --- */
    unsigned int ea_addr;

    if (ea_mode == 3) {
        /* (An)+ postincrement: use current An, advance after */
        ea_addr = m68k_get_reg(NULL, M68K_REG_A0 + ea_reg);
    } else {
        ea_addr = eval_ea(ea_mode, ea_reg, &pc);
    }

    /* Format word is upper 16 bits of first longword */
    u16 format_word = (u16)(m68k_read_memory_32(ea_addr) >> 16);

    /* Read data words */
    int n_words = (format_word & 0xFF) / 4;
    u32 frame_data[56];
    for (int i = 0; i < n_words; i++)
        frame_data[i] = m68k_read_memory_32(ea_addr + 4 + i * 4);

    /* Advance An for postincrement */
    if (ea_mode == 3) {
        int total_frame_size = 4 + n_words * 4;
        unsigned int an = m68k_get_reg(NULL, M68K_REG_A0 + ea_reg);
        m68k_set_reg(M68K_REG_A0 + ea_reg, an + total_frame_size);
    }

    /* --- CIR cpRESTORE dialog --- */
    fpu_wr(OFF_CIR_MODE, 1);

    /* Write cpRESTORE opword */
    cir_wr(OFF_CIR_OPWORD, CIR_OPWORD_CPRESTORE);

    /* Write format word to Restore CIR register */
    cir_wr(OFF_CIR_RESTORE, (u32)format_word);

    /* Write data words to Operand CIR (skip for null frame) */
    for (int i = 0; i < n_words; i++)
        cir_wr(OFF_CIR_OPERAND, frame_data[i]);

    /* Wait for CIR to return to idle */
    for (int i = 0; i < 100; i++) {
        if (cir_rd(OFF_CIR_RESPONSE) != CIR_BUSY)
            break;
    }

    /* Switch back to peripheral mode */
    fpu_wr(OFF_CIR_MODE, 0);

    m68k_set_reg(M68K_REG_PC, pc);
}

/* ------------------------------------------------------------------ */
/* Top-level F-line handler                                            */
/* ------------------------------------------------------------------ */
int fline_illg_callback(int opcode)
{
    unsigned int opword = (unsigned int)opcode & 0xFFFF;

    /* Check if this is an FPU instruction (CpID = 001) */
    if ((opword & 0xF200) != 0xF200)
        return 0;  /* not ours */

    unsigned int type = (opword >> 6) & 7;
    unsigned int pc = m68k_get_reg(NULL, M68K_REG_PC);

    /* Update FPIAR with instruction address */
    fp_reg_set_fpiar(pc - 2);  /* opword was at pc-2 */

    switch (type) {
    case 0: {
        /* Type 000: general instructions (arithmetic, FMOVECR, etc.) */
        unsigned int cmd = m68k_read_memory_16(pc);

        /* Check for FMOVECR first */
        if (is_fmovecr(cmd))
            return handle_fmovecr(cmd, pc + 2);

        /* Check for FMOVE to/from control regs */
        int cmd_type = (cmd >> 13) & 7;
        if (cmd_type == 4 || cmd_type == 5)
            return handle_fmove_ctrl(opword, cmd, pc + 2);

        /* FMOVE FPn → <ea> (cmd_type = 3 = 011) */
        if (cmd_type == 3)
            return handle_fmove_to_mem(opword, cmd, pc + 2);

        /* General arithmetic (cmd_type 0 or 2) */
        return handle_general(opword, pc);
    }

    case 1:
        /* Type 001: FDBcc / FScc / FTRAPcc — not yet implemented.
         * Return 0 (unhandled) so Musashi takes the exception rather
         * than us advancing PC by the wrong amount. */
        xil_printf("FLINE: FDBcc/FScc/FTRAPcc not implemented\r\n");
        return 0;

    case 2: /* FBcc.W */
    case 3: /* FBcc.L */
        return handle_fbcc(opword, pc);

    case 4: /* FSAVE <ea> */
        handle_fsave(opword, pc);
        return 1;

    case 5: /* FRESTORE <ea> */
        handle_frestore(opword, pc);
        return 1;

    default:
        xil_printf("FLINE: type %d not implemented\r\n", type);
        return 0;
    }
}

/* ------------------------------------------------------------------ */
/* Init                                                                */
/* ------------------------------------------------------------------ */
int fline_init(void)
{
    fp_reg_init();
    if (fpu_probe() != FPU_OK) {
        xil_printf("FATAL: fline_init: FPU not responding at 0x%08lx\r\n",
                   (u32)MC68881_BASE);
        return FPU_BUS_ERR;
    }
    /* Disable CIR mode — use peripheral register interface (OPSEL/OPA/OPB).
     * CIR is enabled by default on the FPU. The mode register is write-only
     * (reading ADDR_CIR_RESPONSE returns the dialog response, not the mode). */
    fpu_wr(OFF_CIR_MODE, 0);
    fpu_write_fpcr(0);
    return FPU_OK;
}
