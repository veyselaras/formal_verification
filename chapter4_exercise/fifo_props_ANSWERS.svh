// ---------------------------------------------------------------------------
// fifo_props.svh - ANSWER KEY. Compare against your own version.
//
// The value of this file is not the code, it is the diff: which checks did
// you not think of? That gap is the actual lesson.
//
// Included into fifo.sv, so it has direct access to all internal signals.
// NO SVA sequences, NO |->, NO ##, NO disable iff - the Verific-less Yosys
// frontend does not support them. Temporal checks are written with $past.
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
  // LEVEL 0b - ASSUMPTIONS  (Tip 4.3)
  // =========================================================================

  always @(posedge clk) if (!rst) begin
    assume(!(push && full));    // never write to a full FIFO
    assume(!(pop  && empty));   // never read from an empty FIFO
  end

  // =========================================================================
  // LEVEL 1 - COVER PROPERTIES   ->  sby -f fifo.sby cover
  // =========================================================================

  // Helper state for multi-cycle covers (stands in for SVA sequences).
  reg f_was_full;
  initial f_was_full = 1'b0;
  always @(posedge clk)
    if (rst)       f_was_full <= 1'b0;
    else if (full) f_was_full <= 1'b1;

  // Note the trigger: the round trip completes when a FIFO that HAS been
  // full is now empty. Triggering on empty alone would be useless, because
  // the FIFO is empty right out of reset - the flag would carry no
  // information at all.
  reg f_round_trip;
  initial f_round_trip = 1'b0;
  always @(posedge clk)
    if (rst)                      f_round_trip <= 1'b0;
    else if (f_was_full && empty) f_round_trip <= 1'b1;

  always @(posedge clk) if (f_past_valid && !rst) begin
    cover(empty);                    // L1  the FIFO can drain
    cover(full);                     // L2  the FIFO can fill
    cover(push);                     // L3
    cover(pop);                      // L4
    cover(pop && push);              // L5  both in the same cycle
    cover(count == DEPTH);           // L6  full capacity is actually usable
    cover(count == DEPTH-1);         // L7  almost full
    cover(count == 0);               // L8
    cover(!full && !empty);          // L9  genuinely operating in between
    cover(f_was_full && empty);      // L10 filled, then drained
    cover(f_round_trip && full);     // L11 filled, drained, filled again
  end

  always @(posedge clk) if (f_past_valid && !rst && !$past(rst)) begin
    cover($past(rptr) == DEPTH-1 && rptr == 0);   // L12 read pointer wraps
    cover($past(wptr) == DEPTH-1 && wptr == 0);   // L13 write pointer wraps
  end

  // =========================================================================
  // LEVEL 2 - SAFETY ASSERTIONS   ->  sby -f fifo.sby bmc
  // =========================================================================

  // --- A) Same-cycle invariants -------------------------------------------
  always @(posedge clk) if (f_past_valid && !rst) begin

    // A1: empty flag agrees with the count.
    //     Equivalence, not conjunction: (empty && count == 0) would claim
    //     the FIFO is always empty and fail on the first push.
    assert(empty == (count == 0));

    // A2: full flag agrees with the count. DEPTH, never a literal 8.
    assert(full == (count == DEPTH));

    // A3: full and empty can never both be asserted
    assert(!(full && empty));

    // A4: count stays within the specified bounds (no overflow/underflow)
    assert(count <= DEPTH);

    // A5: count agrees with the pointer distance.
    //     count is [PTR_W:0], the pointers are [PTR_W-1:0]. Without the
    //     slice, a full FIFO (where wptr == rptr, so the difference is 0)
    //     would fail spuriously against count == DEPTH.
    assert(count[PTR_W-1:0] == wptr - rptr);

  end

  // --- B) Cycle-to-cycle transition rules ---------------------------------
  //
  // Every antecedent carries the "did it actually take effect" condition,
  // mirroring the guards in the RTL. $past(push) alone only means the signal
  // was high; a push into a full FIFO is discarded.
  always @(posedge clk) if (f_past_valid && !rst && !$past(rst)) begin

    // B1: neither push nor pop last cycle -> count unchanged
    if (!$past(push) && !$past(pop))
      assert($past(count) == count);

    // B2: effective push only -> count incremented
    if ($past(push) && !$past(pop) && !$past(full))
      assert(count == $past(count) + 1);

    // B3: effective pop only -> count decremented
    if (!$past(push) && $past(pop) && !$past(empty))
      assert(count == $past(count) - 1);

    // B4: both effective -> count unchanged.
    //     This is the one that catches the if/else-chain bug in the RTL.
    if ($past(push) && $past(pop) && !$past(full) && !$past(empty))
      assert($past(count) == count);

    // B5: no effective push -> write pointer holds.
    //     (!a || (a && b)) simplifies to (!a || b).
    if (!$past(push) || $past(full))
      assert($past(wptr) == wptr);

    // B6: no effective pop -> read pointer holds
    if (!$past(pop) || $past(empty))
      assert($past(rptr) == rptr);

  end

  // =========================================================================
  // LEVEL 3 - DATA INTEGRITY (symbolic tracking)
  //
  // Proves data comes out in order and unmodified, with no scoreboard.
  // f_magic is free but constant, so proving it for that one value proves it
  // for every value.
  // =========================================================================

  wire [WIDTH-1:0] f_magic = $anyconst;

  reg           f_tracking;   // are we currently tracking an element?
  reg [PTR_W:0] f_ahead;      // how many entries are ahead of it

  initial f_tracking = 1'b0;
  initial f_ahead    = 0;

  always @(posedge clk) begin
    if (rst) begin
      f_tracking <= 1'b0;
      f_ahead    <= 0;
    end
    else if (!f_tracking) begin
      // C1: start tracking on an effective push of the magic value.
      //     Our element joins the back of the queue, so the number ahead of
      //     it is the current count - minus one if a pop drains an entry in
      //     the very same cycle. Getting this term wrong is the classic way
      //     to end up debugging your own tracker instead of the design.
      if (push && !full && (wdata == f_magic)) begin
        f_tracking <= 1'b1;
        f_ahead    <= count - ((pop && !empty) ? 1'b1 : 1'b0);
      end
    end
    else if (pop && !empty) begin
      // C2/C3: an entry left the FIFO.
      if (f_ahead == 0) f_tracking <= 1'b0;   // it was ours
      else              f_ahead    <= f_ahead - 1'b1;
    end
  end

  // --- The actual claim ----------------------------------------------------
  always @(posedge clk) if (f_past_valid && !rst) begin
    // C4
    if (f_tracking && (f_ahead == 0) && pop && !empty)
      assert(rdata == f_magic);
  end

  // --- Vacuity checks (never skip these) -----------------------------------
  always @(posedge clk) if (f_past_valid && !rst) begin
    // C5: the tracked element can actually leave the FIFO. Without this,
    //     C4 could be passing purely because its antecedent never holds.
    cover(f_tracking && (f_ahead == 0) && pop && !empty);

    // C6: tracking can start with entries ahead of us. Without this you may
    //     only ever be pushing into an empty FIFO and popping immediately,
    //     in which case ordering was never actually exercised.
    cover(f_tracking && (f_ahead >= 2));
  end

  // =========================================================================
  // LEVEL 4 - OVER-CONSTRAINT EXPERIMENT
  //
  // Uncomment and run both tasks:
  //   bmc   -> clean PASS, every assertion proven
  //   cover -> FAIL, five covers unreachable
  //
  // Three quarters of the FIFO untouched, and a fully green assertion table
  // to show for it. Comment it back out when you have seen it.
  // =========================================================================

  // always @(posedge clk) if (!rst) assume(count <= 2);
