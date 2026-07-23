// ---------------------------------------------------------------------------
// fifo_props.svh - FPV properties for the FIFO (SymbiYosys / Yosys style)
//
// Included into fifo.sv, so it has direct access to all internal signals.
// NO SVA sequences, NO |->, NO ##, NO disable iff - the Verific-less Yosys
// frontend does not support them. Temporal checks are written with $past.
//
// Sections are LEVEL 0..4. Work through them in order (see EXERCISE.md).
// ---------------------------------------------------------------------------

  // =========================================================================
  // LEVEL 0a - Infrastructure: reset and history validity
  // =========================================================================

  reg f_past_valid;
  initial f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;

  // One clean reset: rst high at t=0, low forever after.
  // (Delete the second line if you also want to exercise reset behaviour.)
  initial assume(rst);
  always @(posedge clk) if (f_past_valid) assume(!rst);

  // =========================================================================
  // LEVEL 0b - ASSUMPTIONS  (Tip 4.3: don't try to be exhaustive up front)
  // =========================================================================

  always @(posedge clk) if (!rst) begin
    assume(!(push && full));    // never write to a full FIFO
    assume(!(pop  && empty));   // never read from an empty FIFO
  end

  // =========================================================================
  // LEVEL 1 - COVER PROPERTIES   ->  sby -f fifo.sby cover
  //
  // Tip 4.2 / 4.4: run these FIRST. Don't look at assertions yet.
  // SBY produces a separate VCD per cover; inspect every one of them.
  // =========================================================================

  // Helper state for multi-cycle covers (stands in for SVA sequences)
  reg f_was_full;
  initial f_was_full = 1'b0;
  always @(posedge clk)
    if (rst)       f_was_full <= 1'b0;
    else if (full) f_was_full <= 1'b1;

  reg f_round_trip;
  initial f_round_trip = 1'b0;
  always @(posedge clk)
    if (rst)                      f_round_trip <= 1'b0;
    else if (f_was_full && empty) f_round_trip <= 1'b1;

  always @(posedge clk) if (f_past_valid && !rst) begin
    cover(empty);                    // FIFO can drain
    cover(full);                     // FIFO can fill
    cover(push);
    cover(pop);
    cover(pop && push);              // both in the same cycle
    cover(count == DEPTH);           // full capacity is actually usable
    cover(count == DEPTH-1);         // almost full
    cover(count == 0);
    cover(f_was_full && empty);      // filled, then drained
    cover(f_round_trip && full);     // filled, drained, then filled again
  end

  always @(posedge clk) if (f_past_valid && !rst && !$past(rst)) begin
    cover($past(rptr) == DEPTH-1 && rptr == 0);   // read pointer wraps
    cover($past(wptr) == DEPTH-1 && wptr == 0);   // write pointer wraps
  end

  // =========================================================================
  // LEVEL 2 - SAFETY ASSERTIONS   ->  sby -f fifo.sby bmc
  //
  // Tip 4.5: keep every check as simple and single-purpose as possible.
  // =========================================================================

  // --- A) Same-cycle invariants -------------------------------------------
  // Things that must hold at every point in time. No $past here.
  always @(posedge clk) if (f_past_valid && !rst) begin

    // A1: empty flag agrees with the count
    assert(empty == (count == 0));

    // A2: full flag agrees with the count
    assert(full == (count == DEPTH));

    // A3: full and empty can never both be asserted
    assert(!(full && empty));

    // A4: count stays within the specified bounds (no overflow/underflow)
    assert(count <= DEPTH);

    // A5: count agrees with the pointer distance.
    //     Widths differ, so slice count down to PTR_W bits.
    assert(count[PTR_W-1:0] == wptr - rptr);

  end

  // --- B) Cycle-to-cycle transition rules ---------------------------------
  // "If X happened last cycle, then Y must hold now." Written with $past.
  always @(posedge clk) if (f_past_valid && !rst && !$past(rst)) begin

    // B1: neither push nor pop last cycle -> count unchanged
    if (!$past(push) && !$past(pop))
      assert($past(count) == count);

    // B2: push only (and it actually took effect) -> count incremented
    if ($past(push) && !$past(pop) && !$past(full))
      assert(count == $past(count) + 1);

    // B3: pop only (and it actually took effect) -> count decremented
    if (!$past(push) && $past(pop) && !$past(empty))
      assert(count == $past(count) - 1);

    // B4: both push and pop took effect -> count unchanged
    if ($past(push) && $past(pop) && !$past(full) && !$past(empty))
      assert($past(count) == count);

    // B5: no effective push -> write pointer holds
    if (!$past(push) || ($past(push) && $past(full)))
      assert($past(wptr) == wptr);

    // B6: no effective pop -> read pointer holds
    if (!$past(pop) || ($past(pop) && $past(empty)))
      assert($past(rptr) == rptr);

  end

  // =========================================================================
  // LEVEL 3 - OVER-CONSTRAINT EXPERIMENT
  //
  // Uncomment the line below and run both tasks. Watch bmc come back clean
  // PASS while cover reports five unreachable statements - three quarters of
  // the FIFO never touched by verification. This is the single most important
  // lesson of the chapter: a green assertion table on its own means nothing.
  //
  // Comment it back out when you're done.
  // =========================================================================

  // always @(posedge clk) if (!rst) assume(count <= 2);
