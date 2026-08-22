# PE — Verification Report

**DUT:** `src/pe.sv` (95 lines) — INT8 MAC cell, weight-stationary
**Tools:** SymbiYosys + Bitwuzla, OSS Yosys frontend
**Result:** PASS — proof by k-induction, 8/8 covers reachable

---

## Setup

Properties live in `pe_fv.sv`, a wrapper that instantiates the DUT. The RTL is
unmodified.

The multiplier is inline (`assign mult_result = data_in_west * weight_reg`), so it
cannot be blackboxed. At single-PE scale this is fine — the proof runs in about a
second. Internal state needs no hierarchical access: `weight_reg` and `accumulator`
are exposed as `weight_debug` and `acc_debug`.

## DUT Behavior

| Condition | `weight_reg` | `data_out_east` | `psum_out_south` | `accumulator` |
|---|---|---|---|---|
| `reset` | 0 | 0 | 0 | 0 |
| `enable & wl` | `data_in_west` | 0 | `psum_in_north` (bypass) | unchanged |
| `enable & !wl` | unchanged | `data_in_west` | `psum_in_north + mult` | `clear_acc ? mult : acc+mult` |
| `!enable` | unchanged | held | held | unchanged |

Two behaviors are easy to overlook: during weight load the east output is **zeroed**
rather than passed through, and the south output **bypasses** the MAC.

## Properties

| Section | Coverage |
|---|---|
| 1 — Assumptions | Empty by design (see below) |
| 2 — Weight stationary | Weight holds in all non-load cases including `!enable`; correct value on load |
| 3 — Pass-through | Zeroed on load, one-cycle delay on compute, held when disabled |
| 4 — Psum path | Bypass and MAC branches proven separately |
| 5 — Accumulator | `clear_acc` overwrite, normal accumulation, hold |
| 6 — Hold | `!enable` behavior |
| 7 — Reset | All four registers clear |
| 8 — Cover | 8 reachability checks |
| 9 — Signed corner | `(−128)×(−128) = 16384` |

**Section 1 is empty deliberately.** All control signals originate from the array
level; there is no protocol to constrain at PE scope. Leaving inputs free means the
`!enable` branch and the `weight_load` / `clear_acc` collision are both exercised.

**Section 2 is the critical one.** Weight-stationary dataflow depends entirely on the
weight surviving the computation. Its `else` branch also covers `!enable`, where the
RTL has no `weight_reg` assignment at all.

**Section 4** recomputes the product from `data_in_west` and `weight_debug` rather than
reading `dut.mult_result`. The functional form still catches a broken multiplier; the
structural one would not.

## Issues Found During Development

**Arithmetic inside `$past` truncates.** Written as
`$past($signed(a) * $signed(b))`, the multiply is self-determined at 8 bits and gets
masked before the comparison. The DUT held −2065; the property expected −17, which is
−2065 truncated to 8 bits.

The sibling accumulate property survived only because `acc_debug` (32 bits) widened the
expression context — correct by accident.

Fix: apply `$past` to the operands, do the arithmetic outside.
`$signed($past(a)) * $signed($past(b))`.

**Mixed signed/unsigned relational comparison.** `cover (psum_out_south < '0)` was
reported unreachable. `'0` is an unsigned literal, and one unsigned operand forces the
whole relational expression unsigned — nothing is less than zero. Equality is
unaffected, which is why `!= '0` worked.

The same bug passed silently in `cover (acc_debug > 100)`: under unsigned
interpretation a negative accumulator is a large number, so the cover was reachable via
a case it was never meant to describe.

Fix: `$signed()` on every relational comparison in a signed datapath.

**`.sby` script paths.** `[files]` paths resolve relative to the `.sby`; `[script]`
runs from inside the flattened `<task>/src/` directory after copying. Script paths must
be bare filenames.

## Results

| Mode | Result |
|---|---|
| `bmc` (depth 20) | PASS |
| `cover` | PASS — 8/8 |
| `prove` | PASS — k-induction |

Mutation testing confirms sensitivity: inverting the accumulator update, breaking
pass-through, and removing the bypass assignment each drop at least one assertion.

## Open Items

- `clear_acc` is ignored when asserted alongside `weight_load` — the RTL only reads it
  in the `enable && !weight_load` branch. Whether this is deliberate depends on the
  sequencer's behavior.
- Section 6 (hold) is empty as a standalone block; hold is asserted inside the `else`
  branches of sections 2–5.
