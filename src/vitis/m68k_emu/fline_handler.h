/*
 * fline_handler.h
 * F-line (coprocessor) instruction handler for the Musashi M68K emulator.
 * Decodes 68881 FPU instructions and drives the hardware FPU via
 * the peripheral (register-mapped) interface.
 */

#ifndef FLINE_HANDLER_H
#define FLINE_HANDLER_H

/*
 * Musashi illegal-instruction callback.
 * Called for every F-line ($Fxxx) opcode Musashi encounters.
 * Returns 1 if handled (instruction consumed), 0 if not ours.
 */
int fline_illg_callback(int opcode);

/*
 * Initialize the F-line handler subsystem.
 * Resets the software FP register file and syncs FPCR to hardware.
 */
void fline_init(void);

#endif /* FLINE_HANDLER_H */
