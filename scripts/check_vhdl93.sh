#!/bin/bash
# Verify all RTL sources compile under strict VHDL-93.
# Testbenches are excluded — they may use VHDL-2008.
# Usage: bash scripts/check_vhdl93.sh

GHDL_EXE="${GHDL_EXE:-ghdl}"

echo "Checking RTL VHDL-93 compatibility..."
"$GHDL_EXE" -a --std=93 -fsynopsys -fexplicit -C \
  src/mc68881_pkg.vhd \
  src/mc68881_fp80_mul_unit.vhd \
  src/mc68881_fp80_addsub_unit.vhd \
  src/mc68881_modrem_post_unit.vhd \
  src/mc68881_divrem_unit.vhd \
  src/mc68881_trig_unit.vhd \
  src/mc68881_sgl_ops_unit.vhd \
  src/mc68881_alu.vhd \
  src/mc68881_packed_decimal_unit.vhd \
  src/mc68881_top.vhd

if [ $? -eq 0 ]; then
  echo "PASS: All RTL sources are VHDL-93 compatible."
else
  echo "FAIL: VHDL-93 errors found."
  exit 1
fi
