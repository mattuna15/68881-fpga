#!/bin/bash
# Quick rebuild/install of merlin2-crt0.o and libmerlin2.a without full newlib rebuild
export PATH=/home/mattp/.local/bin:$PATH
set -e

BSP_SRC=/cygdrive/c/code/68881-fpga/toolchain/merlin2-bsp
LIB_DIR=/home/mattp/.local/m68k-elf/lib

echo "=== Building merlin2-crt0.o ==="
m68k-elf-gcc -mcpu=68000 -c ${BSP_SRC}/crt0.S -o ${LIB_DIR}/merlin2-crt0.o

echo "=== Building merlin2.o ==="
m68k-elf-gcc -mcpu=68000 -I${BSP_SRC} -c ${BSP_SRC}/merlin2.S -o /tmp/merlin2.o

echo "=== Building libmerlin2.a ==="
m68k-elf-ar rcs ${LIB_DIR}/libmerlin2.a /tmp/merlin2.o
rm /tmp/merlin2.o

echo "=== Installing merlin2.ld ==="
cp ${BSP_SRC}/merlin2.ld ${LIB_DIR}/merlin2.ld

echo "=== Installed to ${LIB_DIR}/ ==="
