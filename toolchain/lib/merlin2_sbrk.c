/*
 * merlin2_sbrk.c -- Custom sbrk that zeroes allocated memory.
 *
 * Overrides the stock newlib/libgloss sbrk to ensure the heap is clean
 * on re-run (G 2004 without reload). The stock sbrk just advances a
 * pointer, leaving stale malloc metadata from the previous run, which
 * causes malloc to hang on the second invocation.
 *
 * This version zeroes all memory returned by sbrk, so malloc always
 * sees a clean arena regardless of previous heap state.
 */

#include <stdint.h>
#include <errno.h>

extern char _end[];          /* linker symbol: end of BSS */
extern char __data_start[];  /* linker symbol: start of .data */
extern char _edata[];        /* linker symbol: end of .data */
extern char __stack[];       /* linker symbol: top of stack (heap limit) */

static char *heap_ptr;

void *sbrk(int incr)
{
    char *prev;

    if (heap_ptr == 0) {
        /* Heap starts after the .data backup area placed by crt0 at _end.
         * Backup layout: [data copy (data_size bytes)] [4-byte magic cookie]
         * So heap begins at _end + data_size + 4, aligned to 8 bytes. */
        unsigned long data_size = (unsigned long)(_edata - __data_start);
        unsigned long backup_end = (unsigned long)_end + data_size + 4;
        heap_ptr = (char *)((backup_end + 7) & ~7UL);  /* align to 8 */
    }

    prev = heap_ptr;

    /* Check for overflow against stack */
    char *stack_limit = (char *)((unsigned long)__stack - 256);
    if (heap_ptr + incr > stack_limit) {
        errno = ENOMEM;
        return (void *)-1;
    }

    heap_ptr += incr;

    /* Zero the newly allocated region so malloc sees clean metadata */
    if (incr > 0) {
        char *p = prev;
        char *end = prev + incr;
        while (p < end)
            *p++ = 0;
    }

    return (void *)prev;
}
