/*
 * m68kcpu_pmmu_shim.h
 * Tiny exported accessor so fline_handler.c can check PMMU_ENABLED
 * without pulling in the entirety of m68kcpu.h (which isn't meant to
 * be included outside the Musashi core).
 */
#ifndef M68KCPU_PMMU_SHIM_H
#define M68KCPU_PMMU_SHIM_H

/* Returns non-zero if the PMMU (TC enable bit) is on. */
int fh_pmmu_enabled(void);

#endif
