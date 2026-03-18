#!/bin/bash
# Patch newlib's libgloss/m68k/Makefile.in to add Merlin 2 BSP target.
# Usage: patch-newlib.sh <path-to-Makefile.in>
set -e

MF="$1"
if [ ! -f "$MF" ]; then
    echo "ERROR: $MF not found" >&2
    exit 1
fi

# 1. Add MERLIN2 variables after TS2_OBJS line
sed -i '/^TS2_OBJS=.*tutor\.o/a \
\
#\
# here'\''s all the Merlin 2 target stuff\
#\
MERLIN2_LDFLAGS=\t-L${srcdir} -Tmerlin2.ld\
MERLIN2_BSP=\tlibmerlin2.a\
MERLIN2_OBJS=\tmerlin2.o' "$MF"

# 2. Add ${MERLIN2_BSP} to all_m68k target (on the line with TS2_BSP)
sed -i 's/${TS2_BSP} ${MVME162_BSP}/${TS2_BSP} ${MERLIN2_BSP} ${MVME162_BSP}/' "$MF"

# 3. Add build rule for MERLIN2_BSP after MVME162_BSP rule
sed -i '/^${MVME162_BSP}: $(OBJS) ${MVME162_OBJS}/i \
${MERLIN2_BSP}: $(OBJS) ${MERLIN2_OBJS}\
\t${AR} ${ARFLAGS} $@ $(OBJS) ${MERLIN2_OBJS}\
\t${RANLIB} $@\
' "$MF"

# 4. Add install rules after ts2.ld install line
sed -i '/INSTALL_DATA.*srcdir.*ts2\.ld/a \
\t# install Merlin 2 stuff\
\t$(INSTALL_PROGRAM) $(MERLIN2_BSP) $(DESTDIR)$(tooldir)/lib${MULTISUBDIR}/$(MERLIN2_BSP)\
\t$(INSTALL_DATA) ${srcdir}/merlin2.ld $(DESTDIR)$(tooldir)/lib${MULTISUBDIR}/merlin2.ld\
\t$(INSTALL_DATA) ${srcdir}/merlin2.h $(DESTDIR)$(tooldir)/lib${MULTISUBDIR}/merlin2.h' "$MF"

echo "Makefile.in patched for Merlin 2 BSP."
