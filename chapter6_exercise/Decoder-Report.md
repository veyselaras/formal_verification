# Decoder — Verification Report

**DUT:** `src/decoder.sv` (328 lines) — 16-opcode instruction decoder
**Tools:** SymbiYosys + Bitwuzla, OSS Yosys frontend
**Result:** PASS — proof by k-induction, 19/19 covers reachable, no failures at any stage

---

## Setup

Properties live in `decoder_fv.sv`. The RTL is unmodified and parsed directly — no
`sv2v` needed. All state is visible on ports, so no hierarchical access is required.

## DUT Behavior

Three-way priority in one clocked block:

| Condition | Behavior |
|---|---|
| `reset` | all outputs cleared |
| `decode_enable \|\| core_state == STATE_DECODE` | fields extracted, all control signals cleared, matching `case` branch sets its own |
| neither | nothing assigned — implicit hold |

The clear-then-set idiom matters: every control signal is unconditionally driven low
before the `case` runs, which is what makes the equivalence form below valid.

## Property Structure

The obvious approach mirrors the RTL — 16 branches, each asserting the signals its
opcode sets. That proves only half of what matters unless every *other* signal is also
asserted low, which is roughly 16 × 20 assertions.

This set inverts the structure: it iterates over **output signals**, pinning each with
`==`:

```systemverilog
a_matmul_start : assert (matmul_start == (f_op == OP_MATMUL));

a_mem_read : assert (mem_read_enable ==
    ((f_op == OP_LOAD_W) || (f_op == OP_LOAD_A)));
```

One line per signal, constraining both directions. About twenty lines total.

Two things follow without extra properties:

- **Mutual exclusion.** `matmul_start` requires `f_op == OP_MATMUL`, `softmax_start`
  requires `OP_SOFTMAX`, and `f_op` holds one value. Same argument for the
  `is_memory` / `is_compute` / `is_control` trio.
- **Invalid opcodes.** For `f_op > OP_HALT` every operation signal is forced low. Only
  `a_is_control` needs an explicit term for the `default` branch.

Two outputs resist this form. `mem_target` and `activation_func` carry values whose
default (`0`) coincides with a valid opcode's result — `mem_target` is `2'b00` for both
`OP_LOAD_W` and `NOP`. These use nested conditionals. `array_clear_acc` is a third
case: the only output depending on an instruction flag (`~instruction[20]`) rather than
the opcode alone.

## Coverage

Nineteen covers: one per opcode, one for the invalid range, two for the accumulate
flag's paths through `array_clear_acc`.

The important one is separate:

```systemverilog
c_no_decode : cover ($past(!decode_enable && core_state != STATE_DECODE));
```

The hold section contains 26 assertions all guarded by the non-decoding condition. If
that condition were unreachable they would pass without firing.

This is why input assumptions were left empty. An early draft had
`assume (core_state == STATE_DECODE)`, which makes the second disjunct of the decode
condition permanently true, renders `decode_enable` irrelevant, and silently disables
the entire hold section. The decoder has no input protocol to enforce — even an invalid
opcode is defined behavior.

## Guard Shape

Every property in the mapping section sits under:

```systemverilog
if (f_past_valid && !$past(reset) &&
    $past(decode_enable || core_state == STATE_DECODE))
```

All three terms look at the previous cycle, since the outputs were written based on
that cycle's decision. Getting one wrong misaligns the property by a cycle and produces
failures that resemble RTL bugs.

## Results

| Mode | Result |
|---|---|
| parse | clean, no `sv2v` |
| `bmc` (depth 20) | PASS |
| `cover` | PASS — 19/19 |
| `prove` | PASS — k-induction |

No property failed at any stage. Mutation testing confirms sensitivity: inverting
`~instruction[20]` drops `a_clear_acc`; changing `mem_target` in the `OP_LOAD_A` branch
drops `a_mem_target`.

## Findings

**`loop_end` is a dead output.** No `case` branch assigns it — `OP_LOOP` raises
`loop_start` only. `a_loop_end_dead` asserts it is always low and the proof passes.
Either the loop-termination logic lives elsewhere or it is missing.

**`*_start` signals are levels, not pulses.** The hold section proves that outputs
persist when decoding is inactive, so `matmul_start` stays high until the next decode.
Relevant for `sequencer.sv`, which reads `matmul_decoded` when deciding whether to move
from `EXEC_WAIT` to `STORE_SETUP`.

**Invalid opcodes fail silently.** Unknown opcodes take the `default` branch and are
classified as control ops with no operation signals raised and no error output. A
corrupted instruction executes as a NOP with no indication.
