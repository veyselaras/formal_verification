// ---------------------------------------------------------------------------
// fifo_props.svh - SKELETON. Fill in the TODOs yourself.
//
// Included into fifo.sv, so it has direct access to all internal signals.
// NO SVA sequences, NO |->, NO ##, NO disable iff - the Verific-less Yosys
// frontend does not support them. Temporal checks are written with $past.
//
// Work through LEVEL 0 -> 1 -> 2 -> 3 -> 4 in order. Do NOT skip ahead to
// the assertions: the whole point of the chapter is that covers come first.
// ---------------------------------------------------------------------------

  // =========================================================================
  // LEVEL 0a - Infrastructure (given, nothing to do here)
  // =========================================================================

  reg f_past_valid;
  initial f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;

  // One clean reset: rst high at t=0, low forever after.
  initial assume(rst);
  always @(posedge clk) if (f_past_valid) assume(!rst);

  // =========================================================================
  // LEVEL 0b - ASSUMPTIONS (given)
  //
  // Tip 4.3: start with the small set that is clearly required. You are not
  // supposed to get this right up front - discovering the missing ones is
  // part of the debug process.
  // =========================================================================

  always @(posedge clk) if (!rst) begin
    assume(!(push && full));    // never write to a full FIFO
    assume(!(pop  && empty));   // never read from an empty FIFO
  end

  // =========================================================================
  // LEVEL 1 - COVER PROPERTIES   ->  sby -f fifo.sby cover
  //
  // Tip 4.2 / 4.4: write and run these FIRST, before any assertion.
  //
  // Before you write anything, write down the spec in one paragraph:
  //   "A DEPTH-entry synchronous FIFO. count is the number of entries.
  //    empty means 0 entries, full means DEPTH entries. Pushing when full
  //    and popping when empty are forbidden. push and pop may occur in the
  //    same cycle. Data comes out in FIFO order. Pointers wrap at DEPTH-1."
  //
  // Every cover below should be derivable from that paragraph, not from
  // reading the RTL.
  // =========================================================================

  // Helper state for multi-cycle covers.
  // Yosys has no SVA sequences, so "A happened, and LATER B happened" is
  // expressed by latching a flag when A occurs and covering flag && B.

  // TODO H1: a flag that latches once the FIFO has been full at least once.
  //          Reset it on rst.
  //
  //   reg f_was_full;
  //   initial f_was_full = 1'b0;
  //   always @(posedge clk)
  //     if (rst)        f_was_full <= 1'b0;
  //     else if (????)  f_was_full <= 1'b1;

  // TODO H2: a flag that latches once a full round trip has completed,
  //          i.e. the FIFO filled up AND then drained completely.
  //          Hint: its trigger condition uses the flag from H1.

  // --- Single-cycle covers -------------------------------------------------
  always @(posedge clk) if (f_past_valid && !rst) begin

    // TODO L1:  the FIFO can be empty
    // TODO L2:  the FIFO can be full
    // TODO L3:  a push can happen
    // TODO L4:  a pop can happen
    // TODO L5:  push and pop can happen in the same cycle
    // TODO L6:  count can reach full capacity
    //           (how many entries should a DEPTH-entry FIFO hold when full?
    //            answer from the spec, not from the RTL)
    // TODO L7:  count can reach one below full capacity
    // TODO L8:  the FIFO can operate in between - neither full nor empty
    // TODO L9:  the FIFO filled up and then drained          (needs H1)
    // TODO L10: the FIFO filled, drained, and filled again   (needs H2)
    //           This is the one that proves the pointers wrap correctly and
    //           the FIFO is genuinely reusable. It will also be the deepest
    //           trace, so watch the step count.

  end

  // --- Covers that need history -------------------------------------------
  // $past requires its own guarded block: !$past(rst) as well as !rst.
  always @(posedge clk) if (f_past_valid && !rst && !$past(rst)) begin

    // TODO L11: the read pointer wraps from DEPTH-1 back to 0
    // TODO L12: the write pointer wraps from DEPTH-1 back to 0

  end

  // -------------------------------------------------------------------------
  // STOP. Run: sby -f fifo.sby cover
  //
  // Read the log carefully:
  //   - how many "reached cover statement" lines are there?
  //   - is there an "unreached cover statements" list at the end?
  //   - at which STEP was each cover hit? A trace that is much shorter than
  //     you expected means the tool found a shortcut you did not anticipate,
  //     and that shortcut is usually a bug.
  //
  // Map log line numbers back to code with:
  //   grep -n "cover(" fv/fifo_props.svh
  //
  // Two of the three RTL bugs are findable here, without writing a single
  // assertion. Find them before moving on.
  // -------------------------------------------------------------------------

  // =========================================================================
  // LEVEL 2 - SAFETY ASSERTIONS   ->  sby -f fifo.sby bmc
  //
  // Tip 4.5: keep every check as simple and single-purpose as possible.
  // Prefer several small assertions over one large equivalent one - when a
  // small one fails it tells you exactly which rule broke.
  //
  // Syntax reminder: there is no |-> in Yosys. Write implications as
  //   if (condition) assert(consequence);
  // =========================================================================

  // --- A) Same-cycle invariants -------------------------------------------
  // Things that must hold at every point in time. No $past here.
  always @(posedge clk) if (f_past_valid && !rst) begin

    // TODO A1: relationship between the empty flag and count
    //          Careful: you want an EQUIVALENCE, not a conjunction.
    //          assert(empty && count == 0) claims the FIFO is always empty.
    // TODO A2: relationship between the full flag and count
    //          Use the DEPTH parameter, never a hardcoded number.
    // TODO A3: full and empty can never both be asserted
    // TODO A4: count stays within the specified bounds
    // TODO A5: count agrees with the distance between the pointers.
    //          Widths differ: count is [PTR_W:0], the pointers are [PTR_W-1:0].
    //          Slice count down with count[PTR_W-1:0] or a full FIFO
    //          (where wptr == rptr) will fail spuriously.

  end

  // --- B) Cycle-to-cycle transition rules ---------------------------------
  // "If X happened last cycle, then Y must hold now."
  //
  // Important: $past(push) only means the push SIGNAL was high. A push into
  // a full FIFO does not take effect - look at how the RTL guards it and put
  // the same condition in your antecedent, or you will get false failures.
  always @(posedge clk) if (f_past_valid && !rst && !$past(rst)) begin

    // TODO B1: neither push nor pop last cycle -> count unchanged
    // TODO B2: effective push only              -> count incremented
    // TODO B3: effective pop only               -> count decremented
    // TODO B4: both effective                   -> count unchanged
    // TODO B5: no effective push                -> write pointer holds
    // TODO B6: no effective pop                 -> read pointer holds

  end

  // -------------------------------------------------------------------------
  // STOP. Run: sby -f fifo.sby bmc
  //
  // BMC stops at the FIRST violation, so you will fix bugs one at a time,
  // shortest counterexample first.
  //
  // For every failure ask, in this order:
  //   1. How many cycles is the trace?
  //   2. At which cycle does the first unexpected thing happen?
  //   3. Is this an RTL bug, or is MY assertion wrong?
  // Question 3 is where most of your time will go, and telling the two apart
  // is the real skill.
  //
  // After every fix, re-run cover as well. A fix can silently kill a cover.
  //
  // The third bug lives behind one of the B rules. Covers cannot find it:
  // a cover only asks "is this situation reachable", never "does the design
  // behave correctly in it". That question belongs to assertions.
  // -------------------------------------------------------------------------


  // =========================================================================
  // LEVEL 4 - OVER-CONSTRAINT EXPERIMENT
  //
  // Uncomment the line below and run BOTH tasks:
  //
  //   sby -f fifo.sby bmc     -> clean PASS, every assertion proven
  //   sby -f fifo.sby cover   -> FAIL, five covers unreachable
  //
  // A single assume did that. Three quarters of the FIFO never touched by
  // verification, and a completely green assertion table to show for it.
  //
  // In a real project nobody writes this line on purpose. It creeps in as an
  // innocent-looking constraint somebody added to silence an annoying
  // counterexample, and then nobody re-runs the covers.
  //
  // Comment it back out when you have seen it.
  // =========================================================================

  // always @(posedge clk) if (!rst) assume(count <= 2);
