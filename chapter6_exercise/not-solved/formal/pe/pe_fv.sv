`default_nettype none
`timescale 1ns/1ns

// ============================================================
// pe_fv.sv — tiny-tpu PE formal wrapper  [EXERCISE]
// ============================================================
// Fill in each TODO. Suggested order: 7 -> 3 -> 2 -> 4 -> 5 -> 6 -> 8.
// Start with reset (section 7): it is the simplest property and doubles
// as a smoke test that the toolchain and port bindings are correct.
// Do not enable every section at once — five assertions failing
// simultaneously tells you nothing about where to start.
// ============================================================

`include "fv_macros.vh"

module pe_fv #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input wire                             clk,
    input wire                             reset,          // ACTIVE HIGH, synchronous
    input wire                             enable,
    input wire                             weight_load,
    input wire                             clear_acc,
    input wire signed [DATA_WIDTH-1:0]     data_in_west,   // activation OR weight
    input wire signed [ACC_WIDTH-1:0]      psum_in_north
);

    wire signed [DATA_WIDTH-1:0] data_out_east;
    wire signed [ACC_WIDTH-1:0]  psum_out_south;
    wire signed [DATA_WIDTH-1:0] weight_debug;    // = weight_reg
    wire signed [ACC_WIDTH-1:0]  acc_debug;       // = accumulator

    // ----------------------------------------------------------
    // DUT
    // ----------------------------------------------------------
    pe #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) dut (
        .clk            (clk),
        .reset          (reset),
        .enable         (enable),
        .weight_load    (weight_load),
        .clear_acc      (clear_acc),
        .data_in_west   (data_in_west),
        .psum_in_north  (psum_in_north),
        .data_out_east  (data_out_east),
        .psum_out_south (psum_out_south),
        .weight_debug   (weight_debug),
        .acc_debug      (acc_debug)
    );

    // ----------------------------------------------------------
    // Access notes
    // ----------------------------------------------------------
    // weight_reg   -> weight_debug  (port, no hierarchical access needed)
    // accumulator  -> acc_debug     (port, no hierarchical access needed)
    // mult_result  -> dut.mult_result
    //
    // ALL datapaths are SIGNED. Relational comparisons need $signed():
    // a single unsigned operand makes the whole comparison unsigned.

    // ----------------------------------------------------------
    // $past guard
    // ----------------------------------------------------------
    reg f_past_valid = 1'b0;
    always @(posedge clk)
        f_past_valid <= 1'b1;

    // TODO: assume reset is active during the first cycle.
    //       reset is ACTIVE HIGH here.
    //       Careful: this is an implication, not a conjunction.
    //       Writing assume(!f_past_valid && reset) makes every
    //       assertion pass vacuously.


    // If deeper $past is needed:
    // reg [2:0] f_pv = 0;
    // always @(posedge clk) f_pv <= {f_pv[1:0], 1'b1};
    // wire f_past_valid_3 = f_pv[2];


    // ==========================================================
    // RTL BEHAVIOR SUMMARY (reference while writing properties)
    // ==========================================================
    // Priority order (nested if):
    //   reset          -> everything 0
    //   enable & wl    -> weight_reg <= data_in_west
    //                     data_out_east  <= 0          (!)
    //                     psum_out_south <= psum_in_north   (BYPASS, !)
    //                     accumulator UNCHANGED
    //   enable & !wl   -> data_out_east  <= data_in_west
    //                     psum_out_south <= psum_in_north + mult_result
    //                     accumulator <= clear_acc ? mult_result
    //                                              : accumulator + mult_result
    //   !enable        -> data_out_east / psum_out_south HELD
    //                     weight_reg and accumulator absent from this branch
    //
    // mult_result = data_in_west * weight_reg   (combinational, inline)
    // Note: during weight_load, data_in_west carries a WEIGHT, not an
    //       activation. mult_result is meaningless on that cycle.


    // ==========================================================
    // SECTION 1 — INPUT ASSUMPTIONS (assume)
    // ==========================================================
    // Master rule: assume inputs, assert outputs. Writing assume on an
    // output declares the design correct by fiat.
    //
    // Consider: can weight_load and clear_acc be asserted together?
    // Is it meaningful to compute before any weight has been loaded?
    // What constraints actually exist at this level of the hierarchy?
    //
    // Note that over-constraining produces a vacuous proof. If you
    // assume enable, the !enable branch is never exercised and the
    // hold properties in section 6 prove nothing.
    //
    // TODO: (or justify leaving this empty)


    // ==========================================================
    // SECTION 2 — WEIGHT STATIONARY (most critical)
    // ==========================================================
    // Check through weight_debug. Two separate things:
    //   (a) under which conditions must the weight NOT change?
    //       NOTE: it must also hold when !enable — the RTL has no
    //       weight_reg assignment in that branch at all.
    //   (b) which value must be written when a load occurs?
    //
    // This is the heart of weight-stationary dataflow. A bug here
    // silently corrupts every result the array produces.
    //
    // `FV_STABLE(x) may be useful.
    //
    // TODO:


    // ==========================================================
    // SECTION 3 — ACTIVATION PASS-THROUGH
    // ==========================================================
    // data_out_east must reflect data_in_west one cycle later.
    // But under which condition? Remember that 0 is written during
    // weight_load, and that the output is held when disabled.
    // Three cases, not one.
    //
    // TODO:


    // ==========================================================
    // SECTION 4 — PARTIAL SUM PATH
    // ==========================================================
    // Two distinct behaviors, both must be proven:
    //   - during weight_load: bypass (psum passes through untouched)
    //   - during compute:     psum_in_north + (activation x weight)
    //
    // Since the multiplier is inline rather than blackboxed, you can
    // either read dut.mult_result or recompute the product yourself.
    // These prove different things — one is structural, the other
    // functional. Which one still catches a broken multiplier?
    //
    // Watch the width: putting arithmetic inside $past evaluates it
    // self-determined, i.e. at operand width, and truncates. Apply
    // $past to the signals and do the arithmetic outside.
    //
    // TODO:


    // ==========================================================
    // SECTION 5 — ACCUMULATOR
    // ==========================================================
    // Check through acc_debug. A path SEPARATE from the psum chain —
    // this one is local accumulation for output-stationary mode.
    //
    // clear_acc behavior, normal accumulation, and the cases where it
    // holds. Note that the RTL only reads clear_acc inside the
    // enable && !weight_load branch.
    //
    // TODO:


    // ==========================================================
    // SECTION 6 — HOLD (!enable)
    // ==========================================================
    // Which signals are explicitly held, and which are simply never
    // assigned? Are those the same thing as far as the property is
    // concerned?
    //
    // TODO:


    // ==========================================================
    // SECTION 7 — RESET
    // ==========================================================
    // Synchronous, active high. Which registers are cleared?
    // (weight_reg included — does that matter for weight-stationary?)
    //
    // Write this one first.
    //
    // TODO:


    // ==========================================================
    // SECTION 8 — COVER (vacuity — DO NOT SKIP)
    // ==========================================================
    // If every assertion passes, suspect this first. An
    // over-constrained design passes everything trivially.
    //
    // Questions worth covering:
    //   - Can a weight be loaded and then a compute performed?
    //   - Can a non-zero psum be produced?
    //   - Can the accumulator actually accumulate?
    //   - Can a negative result be produced?
    //   - Is the !enable branch reachable at all?
    //
    // Careful with signed comparisons: '0 is an unsigned literal, so
    // (x < '0) is unsatisfiable no matter how x is declared.
    //
    // TODO:


    // ==========================================================
    // SECTION 9 — SIGNED / OVERFLOW (optional)
    // ==========================================================
    // INT8 signed range: -128..127.
    // The extreme product is (-128) * (-128) = 16384. Does it fit in
    // the 16-bit mult_result as a signed value? Note the asymmetry:
    // 127 * 127 = 16129 is smaller.
    //
    // With ACC_WIDTH = 32 and N = 8, can the accumulation overflow?
    //
    // TODO:


    // ==========================================================
    // SECTION 10 — $anyconst FUNCTIONAL CONSISTENCY (optional)
    // ==========================================================
    // Only relevant if you blackbox the multiplier. A blackbox output
    // is a free variable every cycle — the same inputs may produce
    // different outputs, because the solver plays against you.
    //
    // $anyconst gives an arbitrary but time-constant value. Pick a
    // symbolic operand pair, assume the product is fixed for it, and
    // prove the accumulator adds the same amount whenever that pair
    // recurs. This is the RTL equivalent of an uninterpreted function
    // in a theorem prover.
    //
    // The .sby anyconst task defines FV_ANYCONST.
`ifdef FV_ANYCONST
    // TODO:

`endif

endmodule
