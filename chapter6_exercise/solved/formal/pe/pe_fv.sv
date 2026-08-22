`default_nettype none
`timescale 1ns/1ns

// ============================================================
// pe_fv.sv — tiny-tpu PE formal verification wrapper
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
    // mult_result  -> dut.mult_result  (the only hierarchical access)
    //
    // ALL datapaths are SIGNED. Comparisons may require $signed().

    // ----------------------------------------------------------
    // $past guard
    // ----------------------------------------------------------
    reg f_past_valid = 1'b0;
    always @(posedge clk)
        f_past_valid <= 1'b1;

    // Force reset to be active during the first cycle (reset is ACTIVE HIGH)
    always @(*)
      if (!f_past_valid)
          assume (reset);

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
    //                     weight_reg and accumulator are absent from this branch
    //
    // mult_result = data_in_west * weight_reg   (combinational, inline)
    // Note: during weight_load, data_in_west carries a WEIGHT, not an activation.
    //       mult_result holds a meaningless value on that cycle.


    // ==========================================================
    // SECTION 1 — INPUT ASSUMPTIONS (assume)
    // ==========================================================
    // Master rule: assume inputs, assert outputs.
    // Consider: can weight_load and clear_acc be asserted together?
    //           What constraints exist in real usage?
    // Over-constraining leads to a vacuous proof.
    //
    // Intentionally left empty. There is no justification for constraining
    // inputs at the PE level; all control signals originate from the array
    // level. Leaving them free ensures the !enable branch and the
    // weight_load / clear_acc collision are also exercised.


    // ==========================================================
    // SECTION 2 — WEIGHT STATIONARY (most critical)
    // ==========================================================
    // Checked through weight_debug.
    // Two separate things:
    //   (a) under which conditions must weight_reg NOT change?
    //       NOTE: it must not change when !enable either — the RTL has no
    //       such branch.
    //   (b) which value must be written when a load occurs?
    //
    // The `FV_STABLE(x) macro may be useful here.
    always_ff @( posedge clk ) begin : WEIGHT_STATIONARY_ASSERTION
        if (f_past_valid && !$past(reset)) begin
            if ($past(enable && weight_load)) begin
                a_weight_load: assert (weight_debug == $past(data_in_west));
            end
            else begin
                a_weight_stable: assert (`FV_STABLE(weight_debug));
            end
        end
    end



    // ==========================================================
    // SECTION 3 — ACTIVATION PASS-THROUGH
    // ==========================================================
    // data_out_east must reflect data_in_west with a one-cycle delay.
    // But under which condition? Remember that 0 is written during
    // weight_load.
    always_ff @( posedge clk ) begin : ACTIVATION_PASS_THROUGH_ASSERTION
        if (f_past_valid && !$past(reset)) begin
            if ($past(enable && weight_load)) begin
                a_east_zero_on_load: assert(data_out_east == '0);
            end 
            else if ($past(enable && !weight_load)) begin
                a_east_forward     : assert(data_out_east == $past(data_in_west));
            end
            else begin
                a_east_hold        : assert(`FV_STABLE(data_out_east));
            end
        end
    end



    // ==========================================================
    // SECTION 4 — PSUM PATH
    // ==========================================================
    // Two distinct behaviors, both must be proven separately:
    //   - during weight_load: bypass
    //   - during normal compute: psum_in_north + mult_result
    //
    // Since the multiplier is inline (not blackboxed), mult_result can be
    // read via dut.mult_result, or the product can be written directly.
    // Consider the difference between:
    //   assert (psum_out_south == $past(psum_in_north + dut.mult_result))
    //   assert (psum_out_south == $past(psum_in_north + data_in_west*weight_debug))
    // The first is structural, the second functional. Which one is stronger?
    always_ff @( posedge clk ) begin : PSUM_ASSERTION
        if (f_past_valid && !$past(reset)) begin
            if ($past(enable && weight_load)) begin
                a_psum_bypass : assert(psum_out_south == $past(psum_in_north));
            end 
            else if ($past(enable && !weight_load)) begin
                a_psum_mac    : assert(
                    psum_out_south == $past(psum_in_north) + $signed($past(data_in_west)) * $signed($past(weight_debug))
                );
            end
            else begin
                a_psum_hold   : assert(`FV_STABLE(psum_out_south));
            end
        end
    end



    // ==========================================================
    // SECTION 5 — ACCUMULATOR
    // ==========================================================
    // Checked through acc_debug. A path SEPARATE from the psum path.
    // clear_acc behavior + normal accumulation + when it holds.
    always_ff @( posedge clk ) begin : ACCUMULATOR_ASSERTION
        if (f_past_valid && !$past(reset)) begin
            if ($past(enable && !weight_load)) begin
                if ($past(clear_acc)) begin
                    a_acc_clear_load : assert (
                        acc_debug == $signed($past(data_in_west)) * $signed($past(weight_debug))
                    );
                end
                else begin
                    a_acc_accumulate : assert (
                        acc_debug == $past(acc_debug)
                                    + $signed($past(data_in_west)) * $signed($past(weight_debug))
                    );
                end
            end
            else begin
                a_acc_hold : assert(`FV_STABLE(acc_debug));
            end
        end
    end



    // ==========================================================
    // SECTION 6 — HOLD (!enable)
    // ==========================================================
    // According to the RTL, which signals are held and which are simply
    // "not touched"? Are those the same thing?
    //
    // TODO:




    // ==========================================================
    // SECTION 7 — RESET
    // ==========================================================
    // Synchronous reset. Which registers are cleared?
    // (weight_reg included — does that matter for weight-stationary?)
    always_ff @( posedge clk ) begin : RESET_ASSERTION
        if (f_past_valid && $past(reset)) begin
            a_reset_weight : assert (weight_debug == '0);
            a_reset_acc    : assert (acc_debug == '0);
            a_reset_east   : assert (data_out_east == '0);
            a_reset_south  : assert (psum_out_south == '0);
        end
    end



    // ==========================================================
    // SECTION 8 — COVER (vacuity — DO NOT SKIP)
    // ==========================================================
    // If every assertion passes, suspect this first.
    // Questions to ask:
    //   - Can a weight be loaded and then a compute performed?
    //   - Can a non-zero psum be produced?
    //   - Can the accumulator actually accumulate?
    //   - Can a negative result be produced? (signed!)
    always_ff @( posedge clk ) begin : COVERS
        c_load_then_compute : cover(
            f_past_valid &&
            $past(enable && weight_load) &&
            (enable && !weight_load)
        );

        c_psum_non_zero : cover(
            f_past_valid &&
            !reset &&
            (psum_out_south != '0)
        );

        c_acc_positive : cover(
            f_past_valid &&
            !reset &&
            ($signed(acc_debug) > 100)
        );

        c_negative_psum : cover(
            f_past_valid &&
            !reset &&
            ($signed(psum_out_south) < 0)
        );

        c_enable_active   : cover (f_past_valid && !reset && enable);

        c_enable_inactive : cover (f_past_valid && !reset && !enable);
    end



    // ==========================================================
    // SECTION 9 — SIGNED / OVERFLOW (optional, interesting)
    // ==========================================================
    // INT8 signed: -128..127. mult_result is 16 bits.
    // Worst case: (-128)*(-128) = 16384 — does it fit in 16 bits?
    // With ACC_WIDTH=32 and N=8, can the accumulation overflow?
    always_ff @(posedge clk) begin : SIGNED_CORNER_CASES
        if (f_past_valid && !$past(reset) && $past(enable && !weight_load)) begin
            
            if ($past(data_in_west == -8'sd128) && $past(weight_debug == -8'sd128)) begin
                a_extreme_neg_mult : assert (
                    psum_out_south == $past(psum_in_north + 32'sd16384)
                );
            end

            c_max_pos_mult : cover (
                !reset &&
                ($past(data_in_west) == -8'sd128) &&
                ($past(weight_debug) == -8'sd128)
            );

            c_max_neg_mult : cover (
                !reset &&
                ($past(data_in_west) == -8'sd128) &&
                ($past(weight_debug) == 8'sd127)
            );
        end
    end

endmodule