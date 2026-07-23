# Formal Property Verification Exercise — FIFO

A hands-on exercise built around Chapter 4 (*Formal Property Verification*) of
**Formal Verification: An Essential Toolkit for Modern VLSI Design**
(Seligman, Schubert, Achutha Kiran Kumar).

The book walks through a combination-lock example. This repo applies the same
methodology to a synchronous FIFO — a design small enough to prove quickly,
but rich enough to hide real bugs.

Everything runs on the open-source toolchain: **Yosys + SymbiYosys**. No
commercial license required.

---

## What this exercise teaches

The point is not "how do I run a formal tool". It is the working method the
chapter argues for:

- **Covers come before assertions.** Two of the three bugs in this design are
  findable without writing a single `assert`.
- **A green assertion report means nothing on its own.** Level 4 demonstrates
  this with a single line of code.
- **Covers ask "is this reachable", assertions ask "is this correct".** The
  third bug is invisible to covers even though the relevant cover is hit.
- **Most of your time goes to one question:** is this a design bug, or is my
  property wrong?

---

## Repository layout

```
not-solved/                 the exercise — buggy RTL, skeleton properties with TODOs
solved/                     my own worked solution
fifo_props_ANSWERS.svh      reference answer key, for comparison
```

Start in `not-solved/`. Open the others once you are done, or when you are
genuinely stuck on a specific step.

Each exercise directory contains:

| File | Purpose |
|---|---|
| `rtl/fifo.sv` | the design under verification |
| `fv/fifo_props.svh` | covers, assumptions, assertions |
| `fifo.sby` | SymbiYosys task file |

The `fifo/`, `fifo_bmc/` and `fifo_cover/` directories under `solved/` are
SymbiYosys output from an actual run, kept as a record of the results. They
are regenerated from scratch on every invocation.

The properties file is pulled into the module with `` `include `` under
`` `ifdef FORMAL ``. Yosys has no `bind` support, so this is how verification
code is kept out of the synthesizable source (the spirit of the book's
Tip 4.1).

---

## Setup

The easiest route is the OSS CAD Suite, which bundles Yosys, SymbiYosys and
the SMT solvers:

```bash
# https://github.com/YosysHQ/oss-cad-suite-build/releases
source /path/to/oss-cad-suite/environment

yosys -V && sby --help > /dev/null && echo ready
```

## Running

```bash
cd not-solved

sby -f fifo.sby cover     # Level 1 — run this first
sby -f fifo.sby bmc       # Level 2 — bug hunt
sby -f fifo.sby prove     # Level 5 — unbounded proof
```

Waveforms:

```bash
gtkwave fifo_cover/engine_0/trace0.vcd   # one VCD per reached cover
gtkwave fifo_bmc/engine_0/trace.vcd      # first assertion violation
```

Map log line numbers back to source:

```bash
grep -n "cover(" fv/fifo_props.svh
```

---

## Working through it

### Level 0 — write the spec first

Before writing any property, write the specification in one paragraph. Covers
should be derivable from that paragraph, not from reading the RTL. Skipping
this step is why "what should I even cover?" feels like an unanswerable
question.

> A DEPTH-entry synchronous FIFO. `count` is the number of entries. `empty`
> means 0 entries, `full` means DEPTH entries. Pushing when full and popping
> when empty are forbidden (a rule the user must obey). `push` and `pop` may
> occur in the same cycle. Data comes out in FIFO order. Pointers wrap at
> DEPTH-1.

### Level 1 — covers only

Fill in the `TODO L*` and `TODO H*` items. Do not write assertions yet.

Yosys supports no SVA sequences, so multi-cycle scenarios ("A happened, and
later B happened") are expressed by latching a flag when A occurs and covering
`flag && B`. Chaining two such flags gives you a three-stage scenario. This
technique carries over to protocol and liveness work later.

Then read the log carefully:

- how many `reached cover statement` lines are there?
- is there an `unreached cover statements` list at the end?
- **at which step was each cover hit?** A trace much shorter than you expected
  means the solver found a shortcut you did not anticipate — and that shortcut
  is usually a bug.

### Level 2 — assertions

Fill in the `TODO A*` and `TODO B*` items. There is no `|->` in Yosys; write
implications as `if (condition) assert(consequence);`.

BMC stops at the first violation, so you fix bugs one at a time, shortest
counterexample first. For each failure ask, in order: how long is the trace,
where does the first anomaly appear, and — most importantly — is this the
design's fault or my property's fault?

Re-run `cover` after every fix. A fix can silently kill a cover.

### Level 3 — data integrity (optional, harder)

Prove that data comes out in order and unmodified, without a scoreboard, using
a free-but-constant value (`$anyconst`) and a small tracking FSM.

This level is a step up: you are designing your own auxiliary hardware rather
than checking something the RTL already computes. Budget accordingly, and do
not skip the vacuity covers — without them the assertion can pass while
proving nothing.

The section ships commented out so the file compiles as-is.

### Level 4 — the over-constraint experiment

Uncomment one line:

```verilog
always @(posedge clk) if (!rst) assume(count <= 2);
```

Then run both tasks:

```
bmc    -> PASS   every assertion proven
cover  -> FAIL   five covers unreachable
```

Three quarters of the FIFO never touched by verification, and a completely
green assertion table to show for it.

In a real project nobody writes this line deliberately. It arrives as an
innocent-looking constraint someone added to silence an annoying
counterexample, and then nobody re-runs the covers. This is the chapter's
central warning, reproduced in about five minutes.

### Level 5 — bounded vs. full proof

`bmc` says "no violation up to depth 30" — a **bounded** proof. `prove`
attempts an unbounded one via k-induction.

If `prove` fails after the design is correct, that is not a bug: induction can
start from unreachable states that violate your assertions. The fix is to add
supporting invariants. Telling "what I want to prove" apart from "what the
proof engine needs in order to run" is where most formal effort goes on real
blocks.

Then scale `DEPTH` — 8 → 16 → 64 → 256 — and record proof times. The deep
scenario covers degrade fastest. This is the concrete feel of *formal
amenability*.

---

## The three bugs

Spoilers, obviously.

<details>
<summary>Click to reveal</summary>

**A — off-by-one in the `full` flag.** `full` asserts one entry early, so the
last slot is never usable. Nothing breaks; capacity is silently lost. Found
via an unreachable cover, with no assertions involved. In simulation every
test would pass.

**B — simultaneous push and pop.** An `if/else` chain misses the case where
both occur, so `count` increments while both pointers advance. Found by the
transition rule for the simultaneous case. Note that `cover(push && pop)` was
*hit* — the situation was reachable and exercised. Reachability is not
correctness.

**C — `rptr` missing from the reset block.** Formal starts it from an
arbitrary value, so the pointer/count invariant fails at cycle 1. Simulation
usually starts registers at zero and hides this entirely. This is the bug
class where formal's advantage over simulation is starkest.

</details>

---

## Notes on the Yosys subset

The book's examples are written in full SystemVerilog Assertions. Yosys
without Verific supports a much smaller subset, so everything here is
translated:

| SVA construct | In Yosys | Written here as |
|---|---|---|
| `assert property (a \|-> b)` | unsupported | `if (a) assert(b);` |
| `a \|=> b` | unsupported | `if ($past(a)) assert(b);` |
| `##1`, sequences | unsupported | helper registers |
| `bind` | unsupported | `` `ifdef FORMAL `include `` |
| `disable iff (rst)` | unsupported | `if (!rst) begin ... end` |
| free constant | — | `wire x = $anyconst;` |

`$past`, `$stable`, `$rose`, `$fell`, `$anyconst` and `$anyseq` all work, and
every temporal check in this repo is built from them.

Every block using `$past` is guarded with `f_past_valid && !$past(rst)`.
Forgetting that guard produces meaningless failures at time 0 and is the most
common beginner mistake with SymbiYosys.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Can't open include file "fifo_props.svh"` | both files must be listed under `[files]`; SBY flattens them into one directory |
| `syntax error, unexpected TOK_END` | a half-written `if` with no body — usually an unfilled TODO |
| assertions fail at time 0 | missing `f_past_valid` / `!$past(rst)` guard |
| `prove` is very slow | try `abc pdr` under `[engines]` |
| z3 not found | use `smtbmc yices` or `smtbmc boolector` |

---

## AI assistance

This exercise was designed and written with AI assistance, using
**Claude Opus 4.8** (Anthropic) at medium reasoning effort.

The AI produced the scaffolding: the intentionally buggy RTL, the property
skeleton with its TODOs, the SymbiYosys task file, the reference answer key
and this README. The exercise itself was worked through by hand — the covers
and assertions under `solved/` were written by me, and the three bugs were
found by reading cover reports and counterexample traces rather than by being
told where they were.

---

## Further reading

- Seligman, Schubert, Achutha Kiran Kumar — *Formal Verification: An Essential
  Toolkit for Modern VLSI Design*, 2nd ed.
- [SymbiYosys documentation](https://symbiyosys.readthedocs.io/)
- Clarke, Grumberg, Peled — *Model Checking*
