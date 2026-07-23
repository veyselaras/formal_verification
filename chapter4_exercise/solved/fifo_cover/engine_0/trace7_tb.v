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
    UUT._witness_.anyinit_procdff_337 = 1'b0;
    UUT._witness_.anyinit_procdff_338 = 3'b000;
    UUT._witness_.anyinit_procdff_339 = 3'b000;
    UUT.count = 4'b0000;
    UUT.f_past_valid = 1'b0;
    UUT.f_round_trip = 1'b0;
    UUT.f_was_full = 1'b0;
    UUT.rptr = 3'b000;
    UUT.wptr = 3'b000;
    UUT.mem[3'b000] = 8'b00000100;
    UUT.mem[3'b001] = 8'b00000000;
    UUT.mem[3'b010] = 8'b00000000;
    UUT.mem[3'b011] = 8'b00000100;
    UUT.mem[3'b100] = 8'b00101100;
    UUT.mem[3'b101] = 8'b00000000;
    UUT.mem[3'b110] = 8'b00010100;
    UUT.mem[3'b111] = 8'b00000000;

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
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 3
    if (cycle == 2) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 4
    if (cycle == 3) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000100;
    end

    // state 5
    if (cycle == 4) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00101100;
    end

    // state 6
    if (cycle == 5) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 7
    if (cycle == 6) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00010100;
    end

    // state 8
    if (cycle == 7) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 9
    if (cycle == 8) begin
      PI_pop <= 1'b1;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 10
    if (cycle == 9) begin
      PI_pop <= 1'b1;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b01000100;
    end

    // state 11
    if (cycle == 10) begin
      PI_pop <= 1'b1;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 12
    if (cycle == 11) begin
      PI_pop <= 1'b1;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00001000;
    end

    // state 13
    if (cycle == 12) begin
      PI_pop <= 1'b1;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000100;
    end

    // state 14
    if (cycle == 13) begin
      PI_pop <= 1'b1;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 15
    if (cycle == 14) begin
      PI_pop <= 1'b1;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 16
    if (cycle == 15) begin
      PI_pop <= 1'b1;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b10000000;
    end

    // state 17
    if (cycle == 16) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000010;
    end

    // state 18
    if (cycle == 17) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00100000;
    end

    // state 19
    if (cycle == 18) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000100;
    end

    // state 20
    if (cycle == 19) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 21
    if (cycle == 20) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    // state 22
    if (cycle == 21) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b01010000;
    end

    // state 23
    if (cycle == 22) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b10100001;
    end

    // state 24
    if (cycle == 23) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b1;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00100000;
    end

    // state 25
    if (cycle == 24) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00100000;
    end

    // state 26
    if (cycle == 25) begin
      PI_pop <= 1'b0;
      PI_push <= 1'b0;
      PI_rst <= 1'b0;
      PI_wdata <= 8'b00000000;
    end

    genclock <= cycle < 26;
    cycle <= cycle + 1;
  end
endmodule
