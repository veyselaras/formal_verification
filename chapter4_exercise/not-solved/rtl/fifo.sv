// ---------------------------------------------------------------------------
// fifo.sv - Synchronous FIFO (SymbiYosys + Yosys FPV exercise)
//
// WARNING: This RTL is intentionally BROKEN. There are three bugs.
// Work through EXERCISE.md before looking at the answer key.
//
// Deliberately written in plain Verilog-2001 + light SV for Yosys
// compatibility:
//   - plain "parameter" instead of "parameter int"
//   - always @(posedge clk) instead of always_ff
//   - 0 instead of '0
//   - classic mem [0:DEPTH-1] array syntax
// ---------------------------------------------------------------------------
`ifndef FIFO_SV
`define FIFO_SV

module fifo #(
  parameter DEPTH = 8,        // must be a power of two
  parameter WIDTH = 8
)(
  input  wire             clk,
  input  wire             rst,    // synchronous, active-high
  input  wire             push,
  input  wire [WIDTH-1:0] wdata,
  input  wire             pop,
  output wire [WIDTH-1:0] rdata,
  output wire             full,
  output wire             empty
);

  localparam PTR_W = $clog2(DEPTH);

  reg [WIDTH-1:0] mem [0:DEPTH-1];
  reg [PTR_W-1:0] wptr, rptr;
  reg [PTR_W:0]   count;

  assign empty = (count == 0);
  assign full  = (count == DEPTH-1);     // (A)
  assign rdata = mem[rptr];

  always @(posedge clk) begin
    if (rst) begin
      wptr  <= 0;
      count <= 0;
      // (C)
    end else begin
      if (push && !full) begin
        mem[wptr] <= wdata;
        wptr      <= wptr + 1'b1;
      end

      if (pop && !empty) begin
        rptr <= rptr + 1'b1;
      end

      if      (push && !full)  count <= count + 1'b1;   // (B)
      else if (pop  && !empty) count <= count - 1'b1;
    end
  end

  // -------------------------------------------------------------------------
  // Verification code lives in a separate file (spirit of Tip 4.1). Yosys has
  // no bind support, so it is pulled in with `include; it disappears entirely
  // during synthesis because FORMAL is not defined there.
  // -------------------------------------------------------------------------
`ifdef FORMAL
`include "fifo_props.svh"
`endif

endmodule

`endif
