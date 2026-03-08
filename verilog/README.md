# Verilog Conversion Output

These Verilog files are auto-generated from the canonical VHDL sources in `src/` using `ghdl --synth`.

**These files are supplied as-is for information only. No guarantee of correctness is made and no tests are run on the converted code.** The VHDL sources are the authoritative implementation.

## Timing constraints

The design relies on multi-cycle path constraints defined in `src/mc68881_top.xdc`. These constraints are essential for timing closure — without them, many internal paths will fail timing at 33 MHz. The XDC file is Xilinx-specific; if targeting another platform (Intel/Quartus, Lattice, etc.), convert the constraints to the equivalent format (e.g. SDC for Quartus). Key constraint groups include multi-cycle paths for the sequential FP units (multiply, add, divide), trig engine hold states, format conversion paths, and operand staging.

## Regeneration

The conversion is run automatically by the pre-push git hook. To regenerate manually:

```
powershell -ExecutionPolicy Bypass -File scripts/convert_to_verilog.ps1
```

or (with ghdl in PATH):

```
bash scripts/convert_to_verilog.sh
```
