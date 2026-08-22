`default_nettype none
`timescale 1ns/1ns

// ============================================================
// decoder_fv.sv — tiny-tpu instruction decoder formal wrapper
// ============================================================

`include "fv_macros.vh"

module decoder_fv (
    input wire        clk,
    input wire        reset,
    input wire [2:0]  core_state,
    input wire        decode_enable,
    input wire [31:0] instruction
);

    wire [7:0] decoded_opcode;
    wire [3:0] decoded_flags;
    wire [3:0] decoded_dst;
    wire [7:0] decoded_src1;
    wire [7:0] decoded_src2;

    wire flag_accumulate, flag_async, flag_broadcast, flag_transpose;

    wire       mem_read_enable, mem_write_enable;
    wire [1:0] mem_target;

    wire array_enable, array_weight_load, array_clear_acc;

    wire       activation_enable;
    wire [2:0] activation_func;

    wire matmul_start, softmax_start, layernorm_start;
    wire transpose_start, add_start, scale_start;

    wire sync_wait, loop_start, loop_end, halt;

    wire is_memory_op, is_compute_op, is_control_op;

    wire [31:0] debug_instruction;

    decoder dut (.*);

    // Opcodes (must match the localparams in the RTL)
    localparam OP_NOP       = 8'h00;
    localparam OP_LOAD_W    = 8'h01;
    localparam OP_LOAD_A    = 8'h02;
    localparam OP_MATMUL    = 8'h03;
    localparam OP_STORE     = 8'h04;
    localparam OP_ACT_RELU  = 8'h05;
    localparam OP_ACT_GELU  = 8'h06;
    localparam OP_ACT_SILU  = 8'h07;
    localparam OP_SOFTMAX   = 8'h08;
    localparam OP_ADD       = 8'h09;
    localparam OP_LAYERNORM = 8'h0A;
    localparam OP_TRANSPOSE = 8'h0B;
    localparam OP_SCALE     = 8'h0C;
    localparam OP_SYNC      = 8'h0D;
    localparam OP_LOOP      = 8'h0E;
    localparam OP_HALT      = 8'h0F;

    localparam STATE_DECODE = 3'b010;

    // ----------------------------------------------------------
    // $past guard
    // ----------------------------------------------------------
    reg f_past_valid = 1'b0;
    always @(posedge clk)
        f_past_valid <= 1'b1;

    always @(*)
      if (!f_past_valid)
          assume (reset);

    // ==========================================================
    // RTL BEHAVIOR SUMMARY
    // ==========================================================
    // reset -> all outputs cleared to 0
    // (decode_enable || core_state == STATE_DECODE) ->
    //     instruction fields are extracted
    //     every control signal is cleared first
    //     then the matching case branch sets the relevant ones
    // neither condition -> nothing changes (implicit hold)
    //
    // Note: array_clear_acc <= ~instruction[20]  (accumulate flag)

    // ==========================================================
    // SECTION 1 — INPUT ASSUMPTIONS
    // ==========================================================
    // Intentionally left empty. The decoder accepts anything on its
    // inputs by design — even an invalid opcode has defined behavior
    // (default branch, treated as NOP). There is no protocol to
    // constrain, so leaving the inputs free is both safe and complete.
    // Constraining core_state or decode_enable would close off the
    // hold branch checked in SECTION 6.


    // ==========================================================
    // SECTION 2 — FIELD EXTRACTION
    // ==========================================================
    // Are opcode / flags / dst / src1 / src2 taken from the right bits?
    always_ff @(posedge clk) begin : FIELD_EXTRACTION
        if (f_past_valid && !$past(reset)) begin
            if ($past(decode_enable || core_state == STATE_DECODE)) begin
                assert (decoded_opcode == $past(instruction[31:24]));
                assert (decoded_flags  == $past(instruction[23:20]));
                assert (decoded_dst    == $past(instruction[19:16]));
                assert (decoded_src1   == $past(instruction[15:8]));
                assert (decoded_src2   == $past(instruction[7:0]));
            end
        end
    end


    // ==========================================================
    // SECTION 3 — OPCODE -> CONTROL SIGNAL MAPPING
    // ==========================================================
    // Written as an equivalence (==) rather than an implication, so
    // each property constrains the signal in BOTH directions: it must
    // be set for the listed opcodes and clear for every other one.
    // This subsumes mutual exclusion (SECTION 4) and invalid-opcode
    // behavior (SECTION 5) for free.
    reg [7:0] f_op;
    always_ff @(posedge clk)
        f_op <= instruction[31:24];

    always_ff @(posedge clk) begin : OPCODE_MAPPING
        if (f_past_valid && !$past(reset) &&
            $past(decode_enable || core_state == STATE_DECODE)) begin

            // --- signals driven by a single opcode ---
            a_matmul_start     : assert (matmul_start      == (f_op == OP_MATMUL));
            a_array_enable     : assert (array_enable      == (f_op == OP_MATMUL));
            a_array_weight_load: assert (array_weight_load == (f_op == OP_LOAD_W));
            a_mem_write        : assert (mem_write_enable  == (f_op == OP_STORE));
            a_softmax_start    : assert (softmax_start     == (f_op == OP_SOFTMAX));
            a_add_start        : assert (add_start         == (f_op == OP_ADD));
            a_layernorm_start  : assert (layernorm_start   == (f_op == OP_LAYERNORM));
            a_transpose_start  : assert (transpose_start   == (f_op == OP_TRANSPOSE));
            a_scale_start      : assert (scale_start       == (f_op == OP_SCALE));
            a_sync_wait        : assert (sync_wait         == (f_op == OP_SYNC));
            a_loop_start       : assert (loop_start        == (f_op == OP_LOOP));
            a_halt             : assert (halt              == (f_op == OP_HALT));

            // --- signals driven by several opcodes ---
            a_mem_read : assert (mem_read_enable ==
                ((f_op == OP_LOAD_W) || (f_op == OP_LOAD_A)));

            a_act_enable : assert (activation_enable ==
                ((f_op == OP_ACT_RELU) || (f_op == OP_ACT_GELU) || (f_op == OP_ACT_SILU)));

            a_is_memory : assert (is_memory_op ==
                ((f_op == OP_LOAD_W) || (f_op == OP_LOAD_A) || (f_op == OP_STORE)));

            a_is_compute : assert (is_compute_op ==
                ((f_op == OP_MATMUL)    || (f_op == OP_ACT_RELU) ||
                 (f_op == OP_ACT_GELU)  || (f_op == OP_ACT_SILU) ||
                 (f_op == OP_SOFTMAX)   || (f_op == OP_ADD)      ||
                 (f_op == OP_LAYERNORM) || (f_op == OP_TRANSPOSE)||
                 (f_op == OP_SCALE)));

            // is_control_op: NOP, SYNC, LOOP, HALT + ALL invalid opcodes
            a_is_control : assert (is_control_op ==
                ((f_op == OP_NOP)  || (f_op == OP_SYNC) ||
                 (f_op == OP_LOOP) || (f_op == OP_HALT) ||
                 (f_op > OP_HALT)));

            // --- output that is never set by any branch (dead signal) ---
            a_loop_end_dead : assert (loop_end == 1'b0);

            // --- multi-bit valued signals ---
            a_mem_target : assert (mem_target ==
                ((f_op == OP_LOAD_A) ? 2'b01 :
                 (f_op == OP_STORE)  ? 2'b10 : 2'b00));

            a_act_func : assert (activation_func ==
                ((f_op == OP_ACT_GELU) ? 3'b001 :
                 (f_op == OP_ACT_SILU) ? 3'b010 : 3'b000));

            // accumulate flag lives at instruction[20]
            a_clear_acc : assert (array_clear_acc ==
                ((f_op == OP_MATMUL) ? ~$past(instruction[20]) : 1'b0));
        end
    end


    // ==========================================================
    // SECTION 4 — MUTUAL EXCLUSION
    // ==========================================================
    // Covered by SECTION 3. Because every start signal is pinned to an
    // exact opcode set with ==, two of them can never be high at once:
    // matmul_start requires f_op == OP_MATMUL while softmax_start
    // requires f_op == OP_SOFTMAX, and f_op holds one value.
    // The same argument covers is_memory_op / is_compute_op /
    // is_control_op, whose opcode sets are disjoint by construction.


    // ==========================================================
    // SECTION 5 — INVALID OPCODE
    // ==========================================================
    // Covered by SECTION 3. Every operation signal is asserted to be
    // low unless its own opcode is present, so for f_op > OP_HALT they
    // are all forced low. a_is_control explicitly includes the
    // (f_op > OP_HALT) term, pinning the default branch's behavior:
    // an unknown opcode is classified as a control op, like NOP.


    // ==========================================================
    // SECTION 6 — HOLD
    // ==========================================================
    // When decode_enable is low and core_state != DECODE, the RTL has
    // no assignment at all, so every output must hold its value.
    //
    // Worth noting what this proves about the design: the *_start
    // signals are NOT one-cycle pulses. They stay high until the next
    // decode. Any downstream module treating them as pulses would be
    // wrong — relevant when verifying sequencer.sv.
    always_ff @(posedge clk) begin : HOLD_ASSERTION
        if (f_past_valid && !$past(reset)) begin
            if ($past(!decode_enable && core_state != STATE_DECODE)) begin
                a_hold_opcode    : assert (`FV_STABLE(decoded_opcode));
                a_hold_flags     : assert (`FV_STABLE(decoded_flags));
                a_hold_dst       : assert (`FV_STABLE(decoded_dst));
                a_hold_src1      : assert (`FV_STABLE(decoded_src1));
                a_hold_src2      : assert (`FV_STABLE(decoded_src2));

                a_hold_mem_rd    : assert (`FV_STABLE(mem_read_enable));
                a_hold_mem_wr    : assert (`FV_STABLE(mem_write_enable));
                a_hold_mem_tgt   : assert (`FV_STABLE(mem_target));

                a_hold_arr_en    : assert (`FV_STABLE(array_enable));
                a_hold_arr_wl    : assert (`FV_STABLE(array_weight_load));
                a_hold_arr_clr   : assert (`FV_STABLE(array_clear_acc));

                a_hold_act_en    : assert (`FV_STABLE(activation_enable));
                a_hold_act_func  : assert (`FV_STABLE(activation_func));

                a_hold_matmul    : assert (`FV_STABLE(matmul_start));
                a_hold_softmax   : assert (`FV_STABLE(softmax_start));
                a_hold_layernorm : assert (`FV_STABLE(layernorm_start));
                a_hold_transpose : assert (`FV_STABLE(transpose_start));
                a_hold_add       : assert (`FV_STABLE(add_start));
                a_hold_scale     : assert (`FV_STABLE(scale_start));

                a_hold_sync      : assert (`FV_STABLE(sync_wait));
                a_hold_loop_st   : assert (`FV_STABLE(loop_start));
                a_hold_loop_end  : assert (`FV_STABLE(loop_end));
                a_hold_halt      : assert (`FV_STABLE(halt));

                a_hold_is_mem    : assert (`FV_STABLE(is_memory_op));
                a_hold_is_comp   : assert (`FV_STABLE(is_compute_op));
                a_hold_is_ctrl   : assert (`FV_STABLE(is_control_op));
            end
        end
    end


    // ==========================================================
    // SECTION 7 — RESET
    // ==========================================================
    // Synchronous, active high. reset sits outermost in the RTL, so it
    // overrides decode_enable — no extra guard term is needed here.
    always_ff @(posedge clk) begin : RESET_ASSERTION
        if (f_past_valid && $past(reset)) begin
            a_rst_opcode    : assert (decoded_opcode    == 8'h00);
            a_rst_flags     : assert (decoded_flags     == 4'h0);
            a_rst_dst       : assert (decoded_dst       == 4'h0);
            a_rst_src1      : assert (decoded_src1      == 8'h00);
            a_rst_src2      : assert (decoded_src2      == 8'h00);

            a_rst_mem_rd    : assert (mem_read_enable   == 1'b0);
            a_rst_mem_wr    : assert (mem_write_enable  == 1'b0);
            a_rst_mem_tgt   : assert (mem_target        == 2'b00);

            a_rst_arr_en    : assert (array_enable      == 1'b0);
            a_rst_arr_wl    : assert (array_weight_load == 1'b0);
            a_rst_arr_clr   : assert (array_clear_acc   == 1'b0);

            a_rst_act_en    : assert (activation_enable == 1'b0);
            a_rst_act_func  : assert (activation_func   == 3'b000);

            a_rst_matmul    : assert (matmul_start      == 1'b0);
            a_rst_softmax   : assert (softmax_start     == 1'b0);
            a_rst_layernorm : assert (layernorm_start   == 1'b0);
            a_rst_transpose : assert (transpose_start   == 1'b0);
            a_rst_add       : assert (add_start         == 1'b0);
            a_rst_scale     : assert (scale_start       == 1'b0);

            a_rst_sync      : assert (sync_wait         == 1'b0);
            a_rst_loop_st   : assert (loop_start        == 1'b0);
            a_rst_loop_end  : assert (loop_end          == 1'b0);
            a_rst_halt      : assert (halt              == 1'b0);

            a_rst_is_mem    : assert (is_memory_op      == 1'b0);
            a_rst_is_comp   : assert (is_compute_op     == 1'b0);
            a_rst_is_ctrl   : assert (is_control_op     == 1'b0);
        end
    end


    // ==========================================================
    // SECTION 8 — FLAG WIRING
    // ==========================================================
    // Are the flag_* wires bound to the right decoded_flags bits?
    // Purely combinational — no $past needed.
    always @(*) assert (flag_accumulate == decoded_flags[0]);
    always @(*) assert (flag_async      == decoded_flags[1]);
    always @(*) assert (flag_broadcast  == decoded_flags[2]);
    always @(*) assert (flag_transpose  == decoded_flags[3]);


    // ==========================================================
    // SECTION 9 — COVER
    // ==========================================================
    // One cover per opcode, plus the invalid-opcode case and both
    // sides of the accumulate flag. If any of these is unreachable,
    // the corresponding assertion in SECTION 3 never fires.
    always_ff @(posedge clk) begin : COVERS
        if (f_past_valid && !$past(reset) &&
            $past(decode_enable || core_state == STATE_DECODE)) begin

            c_nop       : cover (f_op == OP_NOP);
            c_load_w    : cover (f_op == OP_LOAD_W);
            c_load_a    : cover (f_op == OP_LOAD_A);
            c_matmul    : cover (f_op == OP_MATMUL);
            c_store     : cover (f_op == OP_STORE);
            c_act_relu  : cover (f_op == OP_ACT_RELU);
            c_act_gelu  : cover (f_op == OP_ACT_GELU);
            c_act_silu  : cover (f_op == OP_ACT_SILU);
            c_softmax   : cover (f_op == OP_SOFTMAX);
            c_add       : cover (f_op == OP_ADD);
            c_layernorm : cover (f_op == OP_LAYERNORM);
            c_transpose : cover (f_op == OP_TRANSPOSE);
            c_scale     : cover (f_op == OP_SCALE);
            c_sync      : cover (f_op == OP_SYNC);
            c_loop      : cover (f_op == OP_LOOP);
            c_halt      : cover (f_op == OP_HALT);

            c_invalid   : cover (f_op > OP_HALT);

            // matmul with and without the accumulate flag
            // (the two sides of array_clear_acc)
            c_matmul_acc   : cover (f_op == OP_MATMUL &&  $past(instruction[20]));
            c_matmul_noacc : cover (f_op == OP_MATMUL && !$past(instruction[20]));
        end
    end

    // A non-decoding cycle must be reachable too, otherwise the
    // 26 hold assertions in SECTION 6 never fire.
    always_ff @(posedge clk) begin : COVER_HOLD
        if (f_past_valid && !$past(reset)) begin
            c_no_decode : cover ($past(!decode_enable && core_state != STATE_DECODE));
        end
    end

endmodule