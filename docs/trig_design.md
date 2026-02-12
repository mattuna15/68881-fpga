# MC68881 trig implementation note

The trig extension (`FSIN`, `FCOS`, `FTAN`, `FSINCOS`) is implemented as a shared polynomial kernel in `mc68881_pkg` and dispatched through the existing ALU/microsequencer path.

## Resource-efficiency choice

The current core already has reusable add/mul/div datapath functions and deterministic ALU latency scheduling, so trig uses:

1. shared range-reduction (`fmod(x, 2*pi)` + nearest-quadrant via `2/pi`),
2. shared low-order sine/cosine Taylor kernels evaluated with Horner-style multiply/add chaining,
3. shared reconstruction by quadrant,
4. tan as `sin/cos` reusing the existing divider.

No new standalone multiplier/divider units are instantiated; this preserves FPGA resource sharing and keeps cycle control in the existing operation cycle tables.

## Cycle tuning

Cycle-visible timing is controlled by `OP_DESCRIPTORS(...).arith_cycles(...)` and `alu_latency` entries in `mc68881_pkg.vhd`. Latency numbers for trig ops are centralized there so measured hardware timings can be tuned later without changing the trig math path.
