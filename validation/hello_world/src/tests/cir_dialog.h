/*
 * cir_dialog.h
 * CIR dialog protocol test — validates the AN-947 coprocessor interface
 * state machine from the ARM Cortex-A53 over AXI-Lite.
 */

#ifndef CIR_DIALOG_H
#define CIR_DIALOG_H

/* Run CIR dialog tests. Returns number of failures. */
int cir_dialog_run(void);

#endif /* CIR_DIALOG_H */
