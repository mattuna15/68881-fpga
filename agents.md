# agents.md

## Repository overview
- MC68881-compatible FPU core targeting VHDL-2008 and Xilinx Artix-7.
- Sources live in `src/` with testbenches under `tb/`.

## Development notes
- Keep updates aligned with `docs/mc68881_plan_checklist.txt`.
- Add or extend testbench coverage in `tb/` for any new RTL behavior.
- Maintain VHDL-2008 compatibility and avoid vendor-specific primitives.
- Testbenches in `tb/` must be self-checking (assertions with descriptive names), wait on
   DUT-valid signals before checking results, and avoid reserved identifiers (e.g., `label`)
   in procedure/function arguments or signal names.
