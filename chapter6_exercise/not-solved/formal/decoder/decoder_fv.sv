`default_nettype none
`timescale 1ns/1ns

// ============================================================
// decoder_fv.sv — tiny-tpu instruction decoder formal wrapper
//                 [EXERCISE]
// ============================================================
// Fill in each TODO.
//
// This module is a 16-way decode table rather than a datapath, so the
// property style differs from pe_fv.sv. Before writing 16 branches of
// assertions, read the note in section 3 — there is a much shorter
// formulation that also proves strictly more.
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

    // TODO: assume reset is active during the first cycle.
    //       This is an implication, not a conjunction.


    // ==========================================================
    // RTL BEHAVIOR SUMMARY
    // ==========================================================
    // reset -> all outputs cleared to 0
    // (decode_enable || core_state == STATE_DECODE) ->
    //     instruction fields are extracted
    //     every control signal is cleared first
    //     then the matching case branch sets the relevant ones
    // neither condition -> nothing is assigned (implicit hold)
    //
    // Note: array_clear_acc <= ~instruction[20]  (accumulate flag)
    //
    // Instruction layout:
    //   [31:24] opcode | [23:20] flags | [19:16] dst
    //   [15:8]  src1   | [7:0]   src2


    // ==========================================================
    // SECTION 1 — INPUT ASSUMPTIONS
    // ==========================================================
    // Does this module have an input protocol worth constraining?
    // Note that even an invalid opcode has defined behavior here.
    //
    // Be careful with core_state: pinning it to STATE_DECODE makes
    // the second disjunct of the decode condition permanently true,
    // which makes decode_enable irrelevant and silently disables
    // every hold property in section 5.
    //
    // TODO: (or justify leaving this empty)


    // ==========================================================
    // SECTION 2 — FIELD EXTRACTION
    // ==========================================================
    // Are opcode / flags / dst / src1 / src2 taken from the right bits?
    //
    // Watch the guard: the outputs were written based on the PREVIOUS
    // cycle's decision, so every term in the condition needs $past.
    // Checking the current decode_enable misaligns the property by one
    // cycle and produces failures that look like RTL bugs.
    //
    // TODO:


    // ==========================================================
    // SECTION 3 — OPCODE -> CONTROL SIGNAL MAPPING
    // ==========================================================
    // The obvious approach mirrors the RTL: for each of the 16
    // opcodes, assert the signals it sets. But that only proves half
    // of what matters — you also need every OTHER signal to be low,
    // which is roughly 16 x 20 assertions.
    //
    // Consider inverting the structure: iterate over output signals
    // instead of opcodes, and pin each one with == rather than an
    // implication. One line per signal then states "high for exactly
    // these opcodes, low for every other one."
    //
    // Done that way, two things follow without extra work:
    //   - mutual exclusion between the start signals
    //   - correct behavior for invalid opcodes
    // Think about why before writing separate sections for them.
    //
    // Two outputs resist this form: mem_target and activation_func
    // carry values whose default (0) coincides with a valid opcode's
    // result. Those need nested conditionals.
    //
    // A third, array_clear_acc, is the only output depending on an
    // instruction FLAG rather than the opcode alone.
    //
    // Hint: a registered copy of the opcode makes these readable.
    //   reg [7:0] f_op;
    //   always_ff @(posedge clk) f_op <= instruction[31:24];
    //
    // TODO:


    // ==========================================================
    // SECTION 4 — INVALID OPCODE
    // ==========================================================
    // 0x10 and above take the default branch and are treated as NOP.
    // Which outputs must be low, and which one is deliberately set?
    //
    // If section 3 was written with ==, check whether this section is
    // already covered before writing anything here.
    //
    // TODO: (or justify leaving this empty)


    // ==========================================================
    // SECTION 5 — HOLD
    // ==========================================================
    // When decode_enable is low and core_state != DECODE, the RTL
    // assigns nothing at all, so every output must hold.
    //
    // Note what this tells you about the design once proven: the
    // *_start outputs are not one-cycle pulses. Any downstream module
    // treating them as pulses would be wrong.
    //
    // TODO:


    // ==========================================================
    // SECTION 6 — RESET
    // ==========================================================
    // Synchronous, active high. reset sits outermost in the RTL, so it
    // overrides the decode condition — think about what the guard
    // needs, and what it does not.
    //
    // TODO:


    // ==========================================================
    // SECTION 7 — FLAG WIRING
    // ==========================================================
    // Are the flag_* wires bound to the right decoded_flags bits?
    // Purely combinational — no $past, no clocked block needed.
    //
    // TODO:


    // ==========================================================
    // SECTION 8 — COVER
    // ==========================================================
    // Can every opcode actually be decoded? What about the invalid
    // range, and both sides of the accumulate flag?
    //
    // One cover matters more than the rest: the hold assertions in
    // section 5 are all guarded by the non-decoding condition. If that
    // condition turns out to be unreachable, every one of them passes
    // without ever firing. Cover it explicitly.
    //
    // TODO:

endmodule
