# agents.md

## Repository overview
- MC68881-compatible FPU core targeting VHDL-2008 and Xilinx Artix-7.
- Sources live in `src/` with testbenches under `tb/`.

## Development notes
- Keep updates aligned with `docs/mc68881_plan_checklist.txt`.
- Use `docs/68881-programming.txt` as the instruction-set reference for opcode groups,
  data formats, and control/system operation behavior when planning or implementing features.
- For `FMOVECR` constant values, use the upstream QEMU m68k constant ROM table as a
  cross-reference (`target/m68k/fpu_helper.c`, `fpu_rom[128]`) and keep
  `docs/fmovecr_qemu_summary.md` in sync when constants or expectations change.
- Add or extend testbench coverage in `tb/` for any new RTL behavior.
- Maintain VHDL-2008 compatibility and avoid vendor-specific primitives.
- Use `scripts/run_tests.ps1` for local verification; set `GHDL_EXE` if GHDL is not on PATH.
- The pre-push hook in `.githooks/pre-push` runs tests to block failing pushes (enable via
  `git config core.hooksPath .githooks`).
- Testbenches in `tb/` must be self-checking (assertions with descriptive names), wait on
   DUT-valid signals before checking results, and avoid reserved identifiers (e.g., `label`)
   in procedure/function arguments or signal names.
- Testbenches in `tb/` should log key transactions and expected vs. observed results using
  `report` statements (severity `note`) to aid debugging.
- Testbenches that validate FP80 values must deconstruct the value into sign/exponent/mantissa
  (or full 80-bit recomposition from bus words) and compare against the expected FP80 encoding
  before asserting; do not compare raw integer literals against FP80 results.
