/*
 * import_shim.h
 * Force-included before all NeXTMach sources.
 * Converts #import to #include (GCC -include flag) and provides
 * missing BSD/NeXT type definitions for freestanding m68k-elf-gcc.
 */

#ifndef IMPORT_SHIM_H
#define IMPORT_SHIM_H

/* #import is just #include with include-guard semantics.
 * GCC supports #import natively (with a deprecation warning),
 * but we suppress the warning. */
#pragma GCC system_header

/* Basic types that NeXT/BSD headers expect */
typedef unsigned char   u_char;
typedef unsigned short  u_short;
typedef unsigned int    u_int;
typedef unsigned long   u_long;
typedef int             caddr_t;
typedef long            off_t;
typedef unsigned int    size_t;
typedef long            time_t;
typedef unsigned int    uint;
typedef int             dev_t;
typedef int             ino_t;
typedef int             daddr_t;

/* NULL */
#ifndef NULL
#define NULL ((void *)0)
#endif

/* Prevent pulling in real system headers */
#define _SYS_TYPES_H
#define _SYS_SIGNAL_H
#define _SYS_ERRNO_H
#define _SYS_PARAM_H
#define _CTYPE_H

/* Signal stub */
#define NSIG 32

/* errno stub */
extern int errno;
#define EIO     5
#define ENXIO   6
#define ENODEV  19

/* param stubs */
#define MAXPATHLEN 1024
#define NBPG       8192
#define DEV_BSIZE  512

#endif /* IMPORT_SHIM_H */
