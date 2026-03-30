/*
 * m68kconf.h — Musashi configuration for NeXT 68040LC emulation.
 *
 * 68LC040 CPU (68040 without internal FPU). F-line trapping enabled
 * to route FPU instructions to the external MC68882 FPGA hardware.
 */

#ifndef M68KCONF__HEADER
#define M68KCONF__HEADER

#define M68K_OPT_OFF             0
#define M68K_OPT_ON              1
#define M68K_OPT_SPECIFY_HANDLER 2

/* Not building for MAME */
#define M68K_COMPILE_FOR_MAME      M68K_OPT_OFF

/* ------------------------------------------------------------------ */
/* CPU variants: 68040 enabled                                         */
/* ------------------------------------------------------------------ */
#define M68K_EMULATE_010            M68K_OPT_OFF
#define M68K_EMULATE_EC020          M68K_OPT_OFF
#define M68K_EMULATE_020            M68K_OPT_OFF
#define M68K_EMULATE_030            M68K_OPT_OFF
#define M68K_EMULATE_040            M68K_OPT_ON

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
/* F-line trap: intercept FPU instructions for external MC68882         */
/* ------------------------------------------------------------------ */
#define M68K_ILLG_HAS_CALLBACK      M68K_OPT_SPECIFY_HANDLER
extern int fline_illg_callback(int opcode);
#define M68K_ILLG_CALLBACK(opcode)  fline_illg_callback(opcode)

/* ------------------------------------------------------------------ */
/* Features                                                            */
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
#define M68K_INSTRUCTION_HOOK       M68K_OPT_SPECIFY_HANDLER
extern void emu_instr_hook(unsigned int pc);
#define M68K_INSTRUCTION_CALLBACK(pc) emu_instr_hook(pc)
#define M68K_EMULATE_PREFETCH       M68K_OPT_OFF
#define M68K_EMULATE_ADDRESS_ERROR  M68K_OPT_OFF
#define M68K_LOG_ENABLE             M68K_OPT_OFF
#define M68K_LOG_1010_1111          M68K_OPT_OFF
#define M68K_LOG_TRAP               M68K_OPT_OFF

/* Enable PMMU for 68040 MMU (kernel requires it for virtual memory). */
#define M68K_EMULATE_PMMU           M68K_OPT_ON

/* Use 64-bit integers for speed */
#define M68K_USE_64_BIT             M68K_OPT_ON

#endif /* M68KCONF__HEADER */
