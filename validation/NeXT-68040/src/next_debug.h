/*
 * next_debug.h
 * Compile-time debug toggles and shared diagnostic state for the
 * NeXT 68040LC emulator.
 *
 * Each toggle gates a block of instrumentation whose hot-path cost or
 * log volume makes it unsuitable for normal runs.  Flip a toggle to 1
 * to re-enable during investigation — and flip it back before
 * committing.
 */

#ifndef NEXT_DEBUG_H
#define NEXT_DEBUG_H

#include <stdint.h>

/* DMA CSR-write ring buffer, tight-loop detector (stack walk + register
 * snapshot + code dump), DMA IRQ set/clear tracking, per-register
 * read/write logging. Introduced while chasing the post-mach_init
 * dma_start → RESET loop. */
#ifndef NEXT_DEBUG_DMA
#define NEXT_DEBUG_DMA 1
#endif

/* ESP command / status / control trace with PC and instruction count.
 * Enabled dynamically when the DMA tight-loop detector fires
 * (requires NEXT_DEBUG_DMA as well). */
#ifndef NEXT_DEBUG_ESP_TRACE
#define NEXT_DEBUG_ESP_TRACE 1
#endif

/* Kernel OUTER-loop BTST probe at PC=$040146BC — dumps A3-relative
 * flag byte and surrounding memory to identify the polling target. */
#ifndef NEXT_DEBUG_OUTER_BTST
#define NEXT_DEBUG_OUTER_BTST 1
#endif

/* Global instruction counter, incremented once per instruction in
 * emu_instr_hook.  Used as a timestamp by the debug instrumentation
 * above. Defined in main.c. */
extern uint64_t emu_instr_count;

#endif /* NEXT_DEBUG_H */
