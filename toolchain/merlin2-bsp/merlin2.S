/*
 * merlin2.S -- board support for the Merlin 2 (m68k emulator).
 *
 * Uses TRAP #15 BIOS calls for serial I/O.
 * Function number in D0.B, parameters in D1/D2/D3/A1.
 *
 * These stubs provide the same interface as the TS2's tutor.S
 * so newlib's _write_r/_read_r glue works unchanged.
 */

#include "merlin2.h"

	.title "merlin2.S -- Merlin 2 BSP"

	.text
	.global _exit
	.global outln
	.global outbyte
	.global inbyte
	.global havebyte

/*
 * _exit -- Return to the BIOS monitor.
 *
 * crt0 saves the monitor stack pointer at startup into _monitor_sp.
 * We restore it here so RTS returns to the BIOS after its JSR (A0).
 */
	.text
	.align	2
_exit:
	move.l	_monitor_sp,%sp		/* restore stack to BIOS JSR return point */
	rts				/* return to BIOS monitor */

/*
 * inbyte -- get a byte from the serial port via TRAP #15
 *	d0 - contains the byte read in
 *
 * TRAP #15 function 5: read character -> D1.B
 */
	.text
	.align	2
inbyte:
	movem.l	%d1,-(%sp)
	move.b	#5,%d0			/* MERLIN2_TRAP_READ_CHAR */
	trap	#15
	move.b	%d1,%d0			/* result in D1.B -> D0 */
	ext.w	%d0
	ext.l	%d0
	movem.l	(%sp)+,%d1
	rts

/*
 * outbyte -- send a byte out the serial port via TRAP #15
 *	d0 - contains the byte to be sent
 *
 * Converts newline to CR+LF.
 * TRAP #15 function 6: write character from D1.B
 */
	.text
	.align	2
outbyte:
	movem.l	%d0/%d1,-(%sp)
	cmp.b	#0x0A,%d0		/* Is it newline? */
	bne.s	.Lnotnl
	move.b	#0x0D,%d1		/* Send CR first */
	move.b	#6,%d0
	trap	#15
	move.b	#0x0A,%d0		/* Then send LF */
.Lnotnl:
	move.b	%d0,%d1			/* char -> D1.B */
	move.b	#6,%d0			/* MERLIN2_TRAP_WRITE_CHAR */
	trap	#15
	movem.l	(%sp)+,%d0/%d1
	rts

/*
 * outln -- send a string of bytes out the serial port with CR/LF
 *	a0 - contains the address of the string's first byte
 *	a1 - contains the address of the string's last byte
 *
 * Uses TRAP #15 function 0: print string at (A1) with length D1.W, with CRLF
 */
	.text
	.align	2
outln:
	movem.l	%d0/%d1/%a1,-(%sp)
	move.l	%a1,%d1			/* last byte addr */
	sub.l	%a0,%d1			/* length = last - first */
	addq.l	#1,%d1			/* inclusive */
	move.l	%a0,%a1			/* string pointer -> A1 */
	move.b	#0,%d0			/* MERLIN2_TRAP_PRINT_STR (with CRLF) */
	trap	#15
	movem.l	(%sp)+,%d0/%d1/%a1
	rts

/*
 * outstr -- send a string of bytes out the serial port without CR/LF
 *	a0 - contains the address of the string's first byte
 *	a1 - contains the address of the string's last byte
 */
	.text
	.align	2
outstr:
	movem.l	%d0/%d1/%a1,-(%sp)
	move.l	%a1,%d1
	sub.l	%a0,%d1
	addq.l	#1,%d1
	move.l	%a0,%a1
	move.b	#1,%d0			/* MERLIN2_TRAP_PRINT_STR_RAW (no CRLF) */
	trap	#15
	movem.l	(%sp)+,%d0/%d1/%a1
	rts

/*
 * havebyte -- check if there is a byte waiting in the serial port
 *	returns 1 if data available, 0 otherwise
 *
 * TRAP #15 function 7: char ready -> D1.B (0 or 1)
 */
	.text
	.align	2
havebyte:
	movem.l	%d1,-(%sp)
	move.b	#7,%d0			/* MERLIN2_TRAP_CHAR_READY */
	trap	#15
	move.b	%d1,%d0			/* result in D1.B -> D0 */
	ext.w	%d0
	ext.l	%d0
	movem.l	(%sp)+,%d1
	rts
