# Formal Verification of a TPU Design

Formal verification of selected RTL modules from
[RightNow-AI/tiny-tpu](https://github.com/RightNow-AI/tiny-tpu), an 8×8
weight-stationary systolic array TPU written in SystemVerilog.

Properties are written as immediate assertions in separate wrapper modules — the
upstream RTL is never modified. Verification runs on the fully open-source toolchain:
SymbiYosys with the Yosys frontend and the Bitwuzla SMT solver.

## Status

| Module | Lines | BMC | Cover | k-induction |
|---|---:|:---:|:---:|:---:|
| `pe.sv` | 95 | PASS | 8/8 | **PASS** |
| `decoder.sv` | 328 | PASS | 19/19 | **PASS** |
| `systolic_array.sv` | 170 | — | — | blocked (see below) |

Both completed modules are proven for all time, not just within a bounded window, and
both have been checked with mutation testing to confirm the properties are sensitive to
injected bugs.

## Layout

```
formal/
├── Makefile
├── common/
│   └── fv_macros.vh        # $stable / $rose / $fell / $onehot0 substitutes
├── pe/
│   ├── pe_fv.sv            # wrapper + properties
│   └── pe.sby
└── decoder/
    ├── decoder_fv.sv
    └── decoder.sby
```

Clone this alongside the upstream `src/` directory — the `.sby` files reference
`../../src/`.

## Running

```bash
cd formal

make check-pe        # parse check first
make pe-bmc          # fast debug loop
make pe-cover        # vacuity check — do not skip
make pe-prove        # the real proof

make check-decoder
make decoder         # runs bmc + cover + prove
```

Requires [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build), which bundles
Yosys, SymbiYosys, and the solvers.

Read `PASS` in `prove` mode as "holds for all time." `bmc` only means no counterexample
within `depth` cycles, and `UNKNOWN` in `prove` mode means the induction step failed —
not that the proof succeeded.

## What Is Verified

**`pe.sv`** — the MAC cell. Weight stationarity under every condition including when
disabled, activation pass-through with its zeroing behavior during weight load, the
partial-sum path in both bypass and MAC modes, local accumulation with `clear_acc`, hold
behavior, reset, and the INT8 signed corner case where `(−128) × (−128) = 16384`.

**`decoder.sv`** — the 16-opcode instruction decoder. Field extraction, opcode-to-control
mapping written as equivalences so that mutual exclusion and invalid-opcode behavior
follow without separate properties, hold behavior when decoding is inactive, reset
values, and flag wiring.

Detailed writeups, including the reasoning behind the property structure and the
mistakes made along the way, are in the report files.

## Notes

The decoder's `loop_end` output is never assigned by any branch — a dead port. The
`*_start` outputs are levels rather than pulses; they stay asserted until the next
decode.

`systolic_array.sv` is blocked by tooling rather than difficulty. Its interesting state
lives in internal wires (`data_h`, `psum_v`), and the open-source Yosys frontend supports
neither hierarchical references nor `bind`, so a wrapper cannot reach them. The
properties are written but cannot be run without a Verific-based frontend. Modules that
expose their state on ports — as the PE does through its debug outputs — remain fully
verifiable with this toolchain.

## Toolchain Constraint

The open-source Yosys frontend does not support temporal SVA: no `|=>`, `##N`,
sequences, `disable iff`, `default clocking`, or `s_eventually`. Everything here is
written as immediate assertions inside clocked blocks with manual guards:

```systemverilog
always_ff @(posedge clk)
    if (f_past_valid && !$past(reset) && $past(condition))
        assert (...);
```

`f_past_valid` is required on every property because `$past` is undefined on the first
cycle. `common/fv_macros.vh` provides substitutes for `$stable`, `$rose`, `$fell`, and
`$onehot0`, whose availability varies by Yosys version.
