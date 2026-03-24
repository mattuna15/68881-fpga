#ifndef MERLIN2_PRINT_H
#define MERLIN2_PRINT_H

/*
 * BIOS-direct print functions via TRAP #15.
 *
 * These bypass newlib stdio, which breaks on program re-run (G 2004)
 * because newlib's internal FILE state in .data becomes stale.
 * Use these instead of printf for programs that need to be re-runnable.
 *
 * bios_printf uses newlib's vsnprintf for formatting (stateless, no
 * malloc, works fine on re-run) then outputs via TRAP #15 D0=6.
 */

#include <stdarg.h>

/* Print a single character */
void bios_putchar(char c);

/* Print a null-terminated string */
void bios_puts(const char *s);

/* Print a null-terminated string followed by CR+LF */
void bios_println(const char *s);

/* Formatted print (subset of printf, uses vsnprintf internally) */
void bios_printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

#endif /* MERLIN2_PRINT_H */
