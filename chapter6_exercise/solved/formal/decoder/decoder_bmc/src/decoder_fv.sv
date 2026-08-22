`default_nettype none
`timescale 1ns/1ns

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

    // opcode'lar (RTL'deki localparam'larla ayni)
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

    reg f_past_valid = 1'b0;
    always @(posedge clk)
        f_past_valid <= 1'b1;

    always @(*)
      if (!f_past_valid)
          assume (reset);

    // ==========================================================
    // RTL DAVRANIS OZETI
    // ==========================================================
    // reset -> tum cikislar 0
    // (decode_enable || core_state == STATE_DECODE) ->
    //     alanlar instruction'dan cikarilir
    //     tum kontrol sinyalleri once sifirlanir
    //     sonra case ile ilgili olanlar set edilir
    // ikisi de yoksa -> hicbir sey degismez (implicit hold)
    //
    // Dikkat: array_clear_acc <= ~instruction[20]  (accumulate flag)

    // ==========================================================
    // BOLUM 1 — GIRIS VARSAYIMLARI
    // ==========================================================
    // TODO:
    



    // ==========================================================
    // BOLUM 2 — ALAN CIKARMA (field extraction)
    // ==========================================================
    // opcode/flags/dst/src1/src2 dogru bitlerden mi aliniyor?
    // TODO:
    always_ff @(posedge clk) begin
        if(f_past_valid && !$past(reset)) begin
            if ($past(decode_enable || core_state == STATE_DECODE)) begin
                assert(decoded_opcode == $past(instruction[31:24]));
                assert(decoded_flags  == $past(instruction[23:20]));
                assert(decoded_dst    == $past(instruction[19:16]));
                assert(decoded_src1   == $past(instruction[15:8]));
                assert(decoded_src2   == $past(instruction[7:0]));
            end
        end
    end




    // ==========================================================
    // BOLUM 3 — OPCODE -> KONTROL SINYALI ESLEMESI
    // ==========================================================
    // Her opcode icin dogru sinyaller set, digerleri temiz olmali.
    // Ornek: OP_MATMUL -> array_enable, matmul_start, is_compute_op
    // TODO:
        // ==========================================================
    // BOLUM 3 — OPCODE -> KONTROL SINYALI ESLEMESI
    // ==========================================================
    reg [7:0] f_op;
    always_ff @(posedge clk)
        f_op <= instruction[31:24];

    always_ff @(posedge clk) begin : OPCODE_MAPPING
        if (f_past_valid && !$past(reset) &&
            $past(decode_enable || core_state == STATE_DECODE)) begin

            // --- tek opcode'a bagli sinyaller ---
            a_matmul_start     : assert (matmul_start     == (f_op == OP_MATMUL));
            a_array_enable     : assert (array_enable     == (f_op == OP_MATMUL));
            a_array_weight_load: assert (array_weight_load== (f_op == OP_LOAD_W));
            a_mem_write        : assert (mem_write_enable == (f_op == OP_STORE));
            a_softmax_start    : assert (softmax_start    == (f_op == OP_SOFTMAX));
            a_add_start        : assert (add_start        == (f_op == OP_ADD));
            a_layernorm_start  : assert (layernorm_start  == (f_op == OP_LAYERNORM));
            a_transpose_start  : assert (transpose_start  == (f_op == OP_TRANSPOSE));
            a_scale_start      : assert (scale_start      == (f_op == OP_SCALE));
            a_sync_wait        : assert (sync_wait        == (f_op == OP_SYNC));
            a_loop_start       : assert (loop_start       == (f_op == OP_LOOP));
            a_halt             : assert (halt             == (f_op == OP_HALT));

            // --- birden fazla opcode ---
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

            // is_control_op: NOP, SYNC, LOOP, HALT + TUM gecersiz opcode'lar
            a_is_control : assert (is_control_op ==
                ((f_op == OP_NOP)  || (f_op == OP_SYNC) ||
                 (f_op == OP_LOOP) || (f_op == OP_HALT) ||
                 (f_op > OP_HALT)));

            // --- hic set edilmeyen cikis (olu sinyal) ---
            a_loop_end_dead : assert (loop_end == 1'b0);

            // --- deger tasiyan sinyaller ---
            a_mem_target : assert (mem_target ==
                ((f_op == OP_LOAD_A) ? 2'b01 :
                 (f_op == OP_STORE)  ? 2'b10 : 2'b00));

            a_act_func : assert (activation_func ==
                ((f_op == OP_ACT_GELU) ? 3'b001 :
                 (f_op == OP_ACT_SILU) ? 3'b010 : 3'b000));

            // accumulate flag: instruction[20]
            a_clear_acc : assert (array_clear_acc ==
                ((f_op == OP_MATMUL) ? ~$past(instruction[20]) : 1'b0));
        end
    end




    // ==========================================================
    // BOLUM 4 — MUTUAL EXCLUSION
    // ==========================================================
    // is_memory_op / is_compute_op / is_control_op ayni anda
    // birden fazla olabilir mi? RTL bunu garanti etmiyor,
    // her case dalinda elle set ediliyor.
    // Ayni soru start sinyalleri icin de gecerli.
    // TODO:


    // ==========================================================
    // BOLUM 5 — GECERSIZ OPCODE
    // ==========================================================
    // 0x10 ve uzeri -> default dal, NOP gibi davranmali.
    // Hicbir islem sinyali set olmamali.
    // TODO:


    // ==========================================================
    // BOLUM 6 — HOLD
    // ==========================================================
    // decode_enable yokken ve core_state != DECODE iken
    // cikislar degismemeli.
    // TODO:
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
    // BOLUM 8 — FLAG BAGLANTILARI
    // ==========================================================
    // flag_* wire'lari decoded_flags bitlerine dogru bagli mi?
    // Kombinasyonel, $past gerekmez.
    // TODO:
    always @(*) assert(flag_accumulate == decoded_flags[0]);
    always @(*) assert(flag_async      == decoded_flags[1]);
    always @(*) assert(flag_broadcast  == decoded_flags[2]);
    always @(*) assert(flag_transpose  == decoded_flags[3]);




    // ==========================================================
    // BOLUM 9 — COVER
    // ==========================================================
    // Her opcode decode edilebiliyor mu? 16 cover.
    // TODO:
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

            // accumulate flag ile matmul (array_clear_acc'in iki hali)
            c_matmul_acc   : cover (f_op == OP_MATMUL &&  $past(instruction[20]));
            c_matmul_noacc : cover (f_op == OP_MATMUL && !$past(instruction[20]));
        end
    end

    // decode edilmeyen cevrim de ulasilabilir olmali (hold dali)
    always_ff @(posedge clk) begin : COVER_HOLD
        if (f_past_valid && !$past(reset)) begin
            c_no_decode : cover ($past(!decode_enable && core_state != STATE_DECODE));
        end
    end

    always @(*) assert (debug_instruction == instruction);


endmodule