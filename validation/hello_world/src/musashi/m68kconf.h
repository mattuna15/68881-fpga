/*
 * m68kconf.h — Musashi configuration for mc68881 FPU validation.
 *
 * M68000 only. Internal FPU/MMU disabled — we trap F-line instructions
 * and drive the real mc68881 hardware FPU over AXI-Lite.
 */

#ifndef M68KCONF__HEADER
#define M68KCONF__HEADER

#define M68K_OPT_OFF             0
#define M68K_OPT_ON              1
#define M68K_OPT_SPECIFY_HANDLER 2

/* Not building for MAME */
#define M68K_COMPILE_FOR_MAME      M68K_OPT_OFF

/* ------------------------------------------------------------------ */
/* CPU variants: M68000 only                                           */
/* ------------------------------------------------------------------ */
#define M68K_EMULATE_010            M68K_OPT_OFF
#define M68K_EMULATE_EC020          M68K_OPT_OFF
#define M68K_EMULATE_020            M68K_OPT_OFF
#define M68K_EMULATE_030            M68K_OPT_OFF
#define M68K_EMULATE_040            M68K_OPT_OFF

/* ------------------------------------------------------------------ */
/* Memory access — simple flat model                                   */
/* ------------------------------------------------------------------ */
#define M68K_SEPARATE_READS         M68K_OPT_OFF
#define M68K_SIMULATE_PD_WRITES     M68K_OPT_OFF

/* ------------------------------------------------------------------ */
/* Interrupts                                                          */
/* ------------------------------------------------------------------ */
#define M68K_EMULATE_INT_ACK        M68K_OPT_SPECIFY_HANDLER
extern int emu_int_ack_callback(int int_level);
#define M68K_INT_ACK_CALLBACK(level) emu_int_ack_callback(level)

/* ------------------------------------------------------------------ */
/* F-line trap: wire to our handler so we intercept FPU instructions    */
/* ------------------------------------------------------------------ */
#define M68K_ILLG_HAS_CALLBACK      M68K_OPT_SPECIFY_HANDLER
extern int fline_illg_callback(int opcode);
#define M68K_ILLG_CALLBACK(opcode)  fline_illg_callback(opcode)

/* ------------------------------------------------------------------ */
/* Features we don't need                                              */
/* ------------------------------------------------------------------ */
#define M68K_EMULATE_BKPT_ACK       M68K_OPT_OFF
#define M68K_EMULATE_TRACE          M68K_OPT_OFF
#define M68K_EMULATE_RESET          M68K_OPT_OFF
#define M68K_CMPILD_HAS_CALLBACK    M68K_OPT_OFF
#define M68K_RTE_HAS_CALLBACK       M68K_OPT_OFF
#define M68K_TAS_HAS_CALLBACK       M68K_OPT_OFF
#define M68K_TRAP_HAS_CALLBACK      M68K_OPT_OFF
#define M68K_EMULATE_FC             M68K_OPT_OFF
#define M68K_MONITOR_PC             M68K_OPT_OFF
#define M68K_INSTRUCTION_HOOK       M68K_OPT_OFF
#define M68K_EMULATE_PREFETCH       M68K_OPT_OFF
#define M68K_EMULATE_ADDRESS_ERROR  M68K_OPT_OFF
#define M68K_LOG_ENABLE             M68K_OPT_OFF
#define M68K_LOG_1010_1111          M68K_OPT_OFF
#define M68K_LOG_TRAP               M68K_OPT_OFF

/* No PMMU */
#define M68K_EMULATE_PMMU           M68K_OPT_OFF

/* Use 64-bit integers for speed */
#define M68K_USE_64_BIT             M68K_OPT_ON

#endif /* M68KCONF__HEADER */
