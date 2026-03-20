/*
 * merlin2.h -- TRAP #15 function constants for the Merlin 2 BIOS.
 *
 * These match the dispatch table in bios.s (TRAP #15 handler).
 * Function number goes in D0.B before executing TRAP #15.
 */

#ifndef _MERLIN2_H
#define _MERLIN2_H

/* Serial I/O */
#define MERLIN2_TRAP_PRINT_STR      0   /* A1=string, D1.W=len, with CRLF */
#define MERLIN2_TRAP_PRINT_STR_RAW  1   /* A1=string, D1.W=len, no CRLF */
#define MERLIN2_TRAP_READ_STR       2   /* A1=buffer -> D1.W=len */
#define MERLIN2_TRAP_PRINT_NUM      3   /* D1.L=signed number (decimal) */
#define MERLIN2_TRAP_READ_NUM       4   /* -> D1.L (unimplemented) */
#define MERLIN2_TRAP_READ_CHAR      5   /* -> D1.B */
#define MERLIN2_TRAP_WRITE_CHAR     6   /* D1.B=char */
#define MERLIN2_TRAP_CHAR_READY     7   /* -> D1.B (0=no, 1=yes) */

/* Timer */
#define MERLIN2_TRAP_GET_TIME       8   /* -> D1.L milliseconds */

/* Display control */
#define MERLIN2_TRAP_SET_ECHO      12   /* D1.B: 0=off, 1=on */
#define MERLIN2_TRAP_PRINT_CRLF    13   /* A1=string, with CRLF */
#define MERLIN2_TRAP_PRINT_RAW     14   /* A1=string, no CRLF */
#define MERLIN2_TRAP_PRINT_BASE    15   /* D1.L=number, D2.B=base */
#define MERLIN2_TRAP_DISPLAY_CTL   16   /* D1.B: 0=prompt off, 1=on, 2=LF off, 3=LF on */

/* Graphics */
#define MERLIN2_TRAP_SET_MODE      17   /* D1.B: 0=text, 1=graphics */
#define MERLIN2_TRAP_CLEAR_FB      18   /* D1.L=ARGB fill colour */
#define MERLIN2_TRAP_SET_PIXEL     19   /* D1.W=X, D2.W=Y, D3.L=ARGB */
#define MERLIN2_TRAP_GET_PIXEL     20   /* D1.W=X, D2.W=Y -> D1.L=ARGB */
#define MERLIN2_TRAP_SCREEN_INFO   21   /* -> D1.W=width, D2.W=height */

/* RTC */
#define MERLIN2_TRAP_GET_RTC       22   /* -> D1.L=Unix seconds */
#define MERLIN2_TRAP_GET_DATETIME  23   /* -> D1.L=YYYYMMDD BCD, D2.L=HHMMSSwd BCD */
#define MERLIN2_TRAP_SET_RTC       24   /* D1.L=Unix seconds */
#define MERLIN2_TRAP_GET_TICKS     25   /* -> D1.L=Timer C tick count */

/* Mouse */
#define MERLIN2_TRAP_GET_MOUSE     26   /* -> D1.B=buttons, D2.W=deltaX, D3.W=deltaY (clears deltas) */
#define MERLIN2_TRAP_GET_MOUSE_POS 27   /* -> D1.W=absX, D2.W=absY */
#define MERLIN2_TRAP_SET_MOUSE_POS 28   /* D1.W=absX, D2.W=absY (set absolute position) */

#endif /* _MERLIN2_H */
