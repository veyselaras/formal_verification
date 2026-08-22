`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  reg [7:0] PI_data_in_west;
  reg [0:0] PI_clear_acc;
  reg [31:0] PI_psum_in_north;
  reg [0:0] PI_weight_load;
  reg [0:0] PI_enable;
  reg [0:0] PI_reset;
  wire [0:0] PI_clk = clock;
  pe_fv UUT (
    .data_in_west(PI_data_in_west),
    .clear_acc(PI_clear_acc),
    .psum_in_north(PI_psum_in_north),
    .weight_load(PI_weight_load),
    .enable(PI_enable),
    .reset(PI_reset),
    .clk(PI_clk)
  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.$auto$async2sync.\cc:107:execute$471  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$445  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$451  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$457  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$463  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$469  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$475  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$481  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$487  = 1'b1;
    UUT._witness_.anyinit_procdff_307 = 1'b0;
    UUT._witness_.anyinit_procdff_308 = 1'b0;
    UUT._witness_.anyinit_procdff_312 = 8'b00000000;
    UUT._witness_.anyinit_procdff_313 = 8'b00000000;
    UUT._witness_.anyinit_procdff_314 = 8'b00000000;
    UUT._witness_.anyinit_procdff_315 = 8'b00000000;
    UUT._witness_.anyinit_procdff_316 = 1'b0;
    UUT.dut.accumulator = 32'b00000000000000000000000000000000;
    UUT.dut.data_out_east = 8'b00000000;
    UUT.dut.psum_out_south = 32'b00000000000000000000000000000000;
    UUT.dut.weight_reg = 8'b00000000;
    UUT.f_past_valid = 1'b0;

    // state 0
    PI_data_in_west = 8'b00000000;
    PI_clear_acc = 1'b0;
    PI_psum_in_north = 32'b00000000000000000000000000000000;
    PI_weight_load = 1'b1;
    PI_enable = 1'b1;
    PI_reset = 1'b1;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_data_in_west <= 8'b00000000;
      PI_clear_acc <= 1'b0;
      PI_psum_in_north <= 32'b00000000000000000000000000000000;
      PI_weight_load <= 1'b0;
      PI_enable <= 1'b0;
      PI_reset <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      PI_data_in_west <= 8'b00000000;
      PI_clear_acc <= 1'b0;
      PI_psum_in_north <= 32'b00000000000000000000000000000000;
      PI_weight_load <= 1'b0;
      PI_enable <= 1'b0;
      PI_reset <= 1'b0;
    end

    genclock <= cycle < 2;
    cycle <= cycle + 1;
  end
endmodule
