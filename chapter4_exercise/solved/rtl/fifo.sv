// ---------------------------------------------------------------------------
// fifo.sv - Synchronous FIFO (SymbiYosys + Yosys FPV exercise)
//
// STATUS: All three intentional bugs have been fixed:
//   (A) full flag off-by-one          -> full = (count == DEPTH)
//   (B) simultaneous push+pop count   -> case statement handles 2'b11
//   (C) rptr missing from reset       -> rptr <= 0 added
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
  assign full  = (count == DEPTH);
  assign rdata = mem[rptr];

  always @(posedge clk) begin
    if (rst) begin
      wptr  <= 0;
      rptr  <= 0;
      count <= 0;
    end else begin
      if (push && !full) begin
        mem[wptr] <= wdata;
        wptr      <= wptr + 1'b1;
      end

      if (pop && !empty) begin
        rptr <= rptr + 1'b1;
      end

      // Both operations in the same cycle must leave count unchanged.
      case ({push && !full, pop && !empty})
        2'b10  : count <= count + 1'b1;
        2'b01  : count <= count - 1'b1;
        default: count <= count;          // 2'b00 and 2'b11
      endcase
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