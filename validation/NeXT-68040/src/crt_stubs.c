/*
 * crt_stubs.c
 * Provide _init/_fini stubs when linking with -nostartfiles.
 * These are normally provided by crti.o from the toolchain, but
 * we skip startfiles to avoid link-order issues with libxilstandalone.
 */

void _init(void) {}
void _fini(void) {}
