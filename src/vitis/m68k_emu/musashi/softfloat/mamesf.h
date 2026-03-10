/*
 * mamesf.h — Minimal type definitions for softfloat (non-MAME build).
 * Must be compatible with the types defined in m68kcpu.h.
 */
#ifndef MAMESF_H
#define MAMESF_H

/* Type aliases that softfloat needs but m68kcpu.h doesn't define */
typedef signed char        int8;
typedef signed short       int16;
typedef signed int         int32;
typedef signed long long   int64;
typedef unsigned short     bits16;
typedef unsigned int       bits32;
typedef signed int         sbits32;
typedef unsigned long long bits64;
typedef signed long long   sbits64;

typedef int                flag;

/* 64-bit literal macro */
#define LIT64(a) a##ULL

/* Softfloat status — softfloat.h defines enums for rounding/exception */
typedef struct {
    signed char float_rounding_mode;
    signed char float_exception_flags;
    signed char floatx80_rounding_precision;
    signed char float_detect_tininess;
} float_status;

/* Tininess detection constants are defined as enums in softfloat.h */

#endif /* MAMESF_H */
