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
  reg [0:0] PI_pop;
  reg [0:0] PI_push;
  reg [0:0] PI_rst;
  wire [0:0] PI_clk = clock;
  reg [7:0] PI_wdata;
  fifo UUT (
    .pop(PI_pop),
    .push(PI_push),
    .rst(PI_rst),
    .clk(PI_clk),
    .wdata(PI_wdata)
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
    // UUT.$auto$async2sync.\cc:107:execute$457  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$505  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$443  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$449  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$455  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$461  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$467  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$479  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$491  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$497  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$503  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$509  = 1'b1;
    UUT._witness_.anyinit_procdff_337 = 1'b1;
    UUT._witness_.anyinit_procdff_338 = 3'b000;
    UUT._witness_.anyinit_procdff_339 = 3'b000;
    UUT.count = 4'b0001;
    UUT.f_past_valid = 1'b0;
    UUT.f_round_trip = 1'b0;
    UUT.f_was_full = 1'b0;
    UUT.rptr = 3'b000;
    UUT.wptr = 3'b000;
    UUT.mem[3'b000] = 8'b00000001;

    // state 0
    PI_pop = 1'b0;
    PI_push = 1'b0;
    PI_rst = 1'b1;
    PI_wdata = 8'b00000000;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 2
    if (cycle == 1) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    genclock <= cycle < 2;
    cycle <= cycle + 1;
  end
endmodule
