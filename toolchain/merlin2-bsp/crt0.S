/*
 * crt0.S -- startup file for Merlin 2 (m68k-elf, 68000-only)
 *
 * Based on the newlib crt0.S by Cygnus Support.
 * Modified to use jsr instead of jbsr/bsr.l for 68000 compatibility.
 * Symbol names adjusted for ELF (no leading underscore on C symbols).
 *
 * Copyright (c) 1995, 1996, 1998 Cygnus Support
 *
 * The authors hereby grant permission to use, copy, modify, distribute,
 * and license this software and its documentation for any purpose, provided
 * that existing copyright notices are retained in all copies and that this
 * notice is included verbatim in any distributions. No written agreement,
 * license, or royalty fee is required for any of the authorized uses.
 */

	.title "crt0.S for Merlin 2 (68000)"

/*
 * Define an empty environment.
 */
	.data
	.align 2
	.global environ
environ:
	.long 0

	.align 2
	.global _monitor_sp
_monitor_sp:
	.long 0

	.align	2
	.text

/* These are defined in C code. */
	.extern main
	.extern exit
	.extern atexit
	.extern __do_global_dtors

/*
 * These values are set in the linker script.
 */
	.extern __stack
	.extern __bss_start
	.extern _end

/*
 * Hook symbols provided by the linker script (zero = not present).
 */
	.extern _hardware_init_hook
	.extern _software_init_hook

/*
 * Entry point.
 */
	.global _start
	.global start
	.weak start
	.set start,_start

_start:
	/* Save monitor return address and stack pointer for _exit */
	move.l	%sp, _monitor_sp

	/* Set stack pointer if __stack is non-zero */
	move.l	#__stack, %a0
	cmp.l	#0, %a0
	beq.s	1f
	move.l	%a0, %sp
1:
	/* Set up initial stack frame */
	link	%a6, #-8

	/*
	 * Zero out the BSS section.
	 */
	move.l	#__bss_start, %d1
	move.l	#_end, %d0
	cmp.l	%d0, %d1
	beq.s	3f
	move.l	%d1, %a0
	sub.l	%d1, %d0
	subq.l	#1, %d0
2:
	clr.b	(%a0)+
	dbf	%d0, 2b
	clr.w	%d0
	subq.l	#1, %d0
	bcc.s	2b
3:

	/*
	 * Initialize target specific stuff. Only execute these
	 * functions if they exist.
	 */
	lea	_hardware_init_hook, %a0
	cmp.l	#0, %a0
	beq.s	4f
	jsr	(%a0)
4:
	lea	_software_init_hook, %a0
	cmp.l	#0, %a0
	beq.s	5f
	jsr	(%a0)
5:

	/*
	 * Call the main routine from the application.
	 * main(argc, argv, environ)
	 * We pass argv as a pointer to NULL.
	 */
	move.l	#__FINI_SECTION__, (%sp)
	jsr	atexit

	jsr	__INIT_SECTION__

	pea	0
	pea	environ
	pea	(4,%sp)
	pea	0
	jsr	main
	move.l	%d0, -(%sp)

	/*
	 * Drop into _exit in case the user doesn't.
	 */
	jsr	_exit
