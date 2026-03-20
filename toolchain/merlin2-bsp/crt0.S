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
	.long 0		/* MUST be in .data, NOT .bss -- written before BSS is zeroed */

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

/*
 * Magic cookie address: 4 bytes below __stack.
 * If it contains $4D524E32 ("MRN2"), .data has been backed up.
 */
DATA_MAGIC = 0x4D524E32

_start:
	/* Save monitor SP in a register (can't use _monitor_sp yet —
	 * it's in .data which may be overwritten by restore below) */
	move.l	%sp, %d7

	/* Set stack pointer if __stack is non-zero */
	move.l	#__stack, %a0
	cmp.l	#0, %a0
	beq.s	1f
	move.l	%a0, %sp
1:
	/* Set up initial stack frame */
	link	%a6, #-8

	/*
	 * .data backup/restore for re-run support.
	 *
	 * On first run (after S-record load), .data is pristine. We save a
	 * copy to a backup area below the stack. On subsequent runs (G 2004),
	 * we detect the magic cookie and restore .data from the backup,
	 * giving newlib/printf a clean initial state.
	 *
	 * Backup area: __stack - 4 (magic) - data_size (backup copy)
	 */
	move.l	#__stack, %a0
	subq.l	#4, %a0
	cmp.l	#DATA_MAGIC, (%a0)
	bne.s	.Ldata_save

	/* --- Re-run: restore .data from backup --- */
	move.l	#__data_start, %a1	/* destination: .data in RAM */
	move.l	#_edata, %d0
	sub.l	%a1, %d0		/* d0 = data size in bytes */
	beq.s	.Ldata_done
	move.l	%a0, %a2
	sub.l	%d0, %a2		/* a2 = backup start (below magic) */
	subq.l	#1, %d0
.Ldata_restore_loop:
	move.b	(%a2)+, (%a1)+
	dbf	%d0, .Ldata_restore_loop
	clr.w	%d0
	subq.l	#1, %d0
	bcc.s	.Ldata_restore_loop
	bra.s	.Ldata_done

.Ldata_save:
	/* --- First run: save .data to backup area --- */
	move.l	#__data_start, %a1	/* source: .data in RAM */
	move.l	#_edata, %d0
	sub.l	%a1, %d0		/* d0 = data size in bytes */
	beq.s	.Ldata_mark
	move.l	%a0, %a2
	sub.l	%d0, %a2		/* a2 = backup start (below magic) */
	move.l	%a1, %a3		/* a3 = source */
	subq.l	#1, %d0
.Ldata_save_loop:
	move.b	(%a3)+, (%a2)+
	dbf	%d0, .Ldata_save_loop
	clr.w	%d0
	subq.l	#1, %d0
	bcc.s	.Ldata_save_loop
.Ldata_mark:
	move.l	#DATA_MAGIC, (%a0)	/* set cookie */
.Ldata_done:
	/* Now safe to write _monitor_sp (after .data restore) */
	move.l	%d7, _monitor_sp

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
