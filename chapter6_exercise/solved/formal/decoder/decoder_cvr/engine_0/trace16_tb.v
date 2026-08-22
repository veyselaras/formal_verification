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
  reg [31:0] PI_instruction;
  reg [0:0] PI_decode_enable;
  reg [2:0] PI_core_state;
  wire [0:0] PI_clk = clock;
  reg [0:0] PI_reset;
  decoder_fv UUT (
    .instruction(PI_instruction),
    .decode_enable(PI_decode_enable),
    .core_state(PI_core_state),
    .clk(PI_clk),
    .reset(PI_reset)
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
    // UUT.$auto$async2sync.\cc:107:execute$1565  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$1583  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$1491  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1497  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1503  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1509  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1515  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1521  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1527  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1533  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1539  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1545  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1551  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1557  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1563  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1569  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1575  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1581  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1587  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1593  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1599  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$1605  = 1'b1;
    UUT._witness_.anyinit_procdff_933 = 1'b0;
    UUT._witness_.anyinit_procdff_934 = 1'b0;
    UUT._witness_.anyinit_procdff_935 = 1'b0;
    UUT._witness_.anyinit_procdff_936 = 1'b0;
    UUT._witness_.anyinit_procdff_937 = 1'b0;
    UUT._witness_.anyinit_procdff_938 = 1'b0;
    UUT.dut.activation_enable = 1'b0;
    UUT.dut.activation_func = 3'b000;
    UUT.dut.add_start = 1'b0;
    UUT.dut.array_clear_acc = 1'b0;
    UUT.dut.array_enable = 1'b0;
    UUT.dut.array_weight_load = 1'b0;
    UUT.dut.decoded_dst = 4'b0000;
    UUT.dut.decoded_flags = 4'b0000;
    UUT.dut.decoded_opcode = 8'b00000000;
    UUT.dut.decoded_src1 = 8'b00000000;
    UUT.dut.decoded_src2 = 8'b00000000;
    UUT.dut.halt = 1'b0;
    UUT.dut.is_compute_op = 1'b0;
    UUT.dut.is_control_op = 1'b0;
    UUT.dut.is_memory_op = 1'b0;
    UUT.dut.layernorm_start = 1'b0;
    UUT.dut.loop_end = 1'b0;
    UUT.dut.loop_start = 1'b0;
    UUT.dut.matmul_start = 1'b0;
    UUT.dut.mem_read_enable = 1'b0;
    UUT.dut.mem_target = 2'b00;
    UUT.dut.mem_write_enable = 1'b0;
    UUT.dut.scale_start = 1'b0;
    UUT.dut.softmax_start = 1'b0;
    UUT.dut.sync_wait = 1'b0;
    UUT.dut.transpose_start = 1'b0;
    UUT.f_op = 8'b00000000;
    UUT.f_past_valid = 1'b0;

    // state 0
    PI_instruction = 32'b00000000000000000000000000000000;
    PI_decode_enable = 1'b0;
    PI_core_state = 3'b000;
    PI_reset = 1'b1;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_instruction <= 32'b00000110111111111111111111111111;
      PI_decode_enable <= 1'b1;
      PI_core_state <= 3'b011;
      PI_reset <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      PI_instruction <= 32'b00000000000000000000000000000000;
      PI_decode_enable <= 1'b0;
      PI_core_state <= 3'b000;
      PI_reset <= 1'b0;
    end

    // state 3
    if (cycle == 2) begin
      PI_instruction <= 32'b00000000000000000000000000000000;
      PI_decode_enable <= 1'b0;
      PI_core_state <= 3'b000;
      PI_reset <= 1'b0;
    end

    genclock <= cycle < 3;
    cycle <= cycle + 1;
  end
endmodule
