`default_nettype none
`timescale 1ns/1ns

// ============================================================
// pe_fv.sv — tiny-tpu PE formal wrapper
// ============================================================

`include "fv_macros.vh"

module pe_fv #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input wire                             clk,
    input wire                             reset,          // ACTIVE HIGH, senkron
    input wire                             enable,
    input wire                             weight_load,
    input wire                             clear_acc,
    input wire signed [DATA_WIDTH-1:0]     data_in_west,   // aktivasyon VEYA agirlik
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
    // Erisim notlari
    // ----------------------------------------------------------
    // weight_reg   -> weight_debug  (port, hiyerarsi gerekmez)
    // accumulator  -> acc_debug     (port, hiyerarsi gerekmez)
    // mult_result  -> dut.mult_result  (tek hiyerarsik erisim)
    //
    // TUM veri yollari SIGNED. Karsilastirmalarda $signed() gerekebilir.

    // ----------------------------------------------------------
    // $past guard
    // ----------------------------------------------------------
    reg f_past_valid = 1'b0;
    always @(posedge clk)
        f_past_valid <= 1'b1;

    // TODO: ilk cevrimde reset aktif olsun (reset ACTIVE HIGH — assume(reset))
    always @(*)
      if (!f_past_valid)
          assume (reset);

    // n-derinlikli $past gerekirse:
    // reg [2:0] f_pv = 0;
    // always @(posedge clk) f_pv <= {f_pv[1:0], 1'b1};
    // wire f_past_valid_3 = f_pv[2];


    // ==========================================================
    // RTL DAVRANIS OZETI (property yazarken referans)
    // ==========================================================
    // Oncelik sirasi (ic ice if):
    //   reset          -> hepsi 0
    //   enable & wl    -> weight_reg <= data_in_west
    //                     data_out_east  <= 0          (!)
    //                     psum_out_south <= psum_in_north   (BYPASS, !)
    //                     accumulator DEGISMEZ
    //   enable & !wl   -> data_out_east  <= data_in_west
    //                     psum_out_south <= psum_in_north + mult_result
    //                     accumulator <= clear_acc ? mult_result
    //                                              : accumulator + mult_result
    //   !enable        -> data_out_east / psum_out_south TUTULUR
    //                     weight_reg ve accumulator bu dalda YOK
    //
    // mult_result = data_in_west * weight_reg   (kombinasyonel, inline)
    // Dikkat: weight_load sirasinda data_in_west AGIRLIK, aktivasyon degil.
    //         mult_result o cevrimde anlamsiz bir deger tasir.


    // ==========================================================
    // BOLUM 1 — GIRIS VARSAYIMLARI (assume)
    // ==========================================================
    // Master rule: girisleri assume, cikislari assert.
    // Dusun: weight_load ve clear_acc ayni anda gelebilir mi?
    //        Gercek kullanimda hangi kisitlar var?
    // Cok siki kisitlarsan vacuous proof alirsin.
    //
    // TODO:

    // BOLUM 1 — GIRIS VARSAYIMLARI
    // Bilincli olarak bos. PE seviyesinde kisit yazmak icin dayanak yok;
    // tum kontrol sinyalleri dizi seviyesinden geliyor. Serbest birakmak
    // !enable dalinin ve wl/clear_acc cakismasinin da sinanmasini sagliyor.


    // ==========================================================
    // BOLUM 2 — AGIRLIK STATIONARY (en kritik)
    // ==========================================================
    // weight_debug uzerinden kontrol et.
    // Iki ayri sey:
    //   (a) weight_reg hangi kosullarda degismemeli?
    //       DIKKAT: !enable durumunda da degismemeli — RTL'de o dal yok.
    //   (b) yukleme oldugunda hangi deger yazilmali?
    //
    // `FV_STABLE(x) makrosu isini gorebilir.
    //
    // TODO:
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
    // BOLUM 3 — AKTIVASYON PASS-THROUGH
    // ==========================================================
    // data_out_east bir cevrim gecikmeyle data_in_west'i yansitmali.
    // AMA hangi kosulda? weight_load sirasinda 0 yazildigini unutma.
    //
    // TODO:
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
    // BOLUM 4 — PSUM YOLU
    // ==========================================================
    // Iki farkli davranis var, ikisini de ayri ayri ispatla:
    //   - weight_load sirasinda: bypass
    //   - normal hesapta: psum_in_north + mult_result
    //
    // Carpici inline oldugu icin (blackbox degil) mult_result'i
    // dut.mult_result ile okuyabilir, hatta dogrudan carpimi
    // yazabilirsin. Ikisi arasindaki farki dusun:
    //   assert (psum_out_south == $past(psum_in_north + dut.mult_result))
    //   assert (psum_out_south == $past(psum_in_north + data_in_west*weight_debug))
    // Ilki yapisal, ikincisi fonksiyonel. Hangisi daha guclu?
    //
    // TODO:
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
    // BOLUM 5 — AKUMULATOR
    // ==========================================================
    // acc_debug uzerinden. psum yolundan AYRI bir yol.
    // clear_acc davranisi + normal birikim + hangi durumlarda donuyor.
    //
    // TODO:
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
    // BOLUM 6 — HOLD (!enable)
    // ==========================================================
    // RTL'e gore hangi sinyaller tutuluyor, hangileri "dokunulmuyor"?
    // Ikisi ayni sey mi?
    //
    // TODO:




    // ==========================================================
    // BOLUM 7 — RESET
    // ==========================================================
    // Senkron reset. Hangi register'lar sifirlaniyor?
    // (weight_reg dahil — bu weight-stationary icin onemli mi?)
    //
    // TODO:
    always_ff @( posedge clk ) begin : RESET_ASSERTION
        if (f_past_valid && $past(reset)) begin
            a_reset_weight : assert (weight_debug == '0);
            a_reset_acc    : assert (acc_debug == '0);
            a_reset_east   : assert (data_out_east == '0);
            a_reset_south  : assert (psum_out_south == '0);
        end
    end



    // ==========================================================
    // BOLUM 8 — COVER (vacuity — ATLAMA)
    // ==========================================================
    // Assertion'larin hepsi geciyorsa once bundan suphelen.
    // Sorman gerekenler:
    //   - Agirlik yuklenip sonra hesap yapilabiliyor mu?
    //   - Sifirdan farkli bir psum uretilebiliyor mu?
    //   - Akumulator birikebiliyor mu?
    //   - Negatif sonuc uretilebiliyor mu? (signed!)
    //
    // TODO:
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
            (acc_debug > 100)
        );

        c_negative_psum : cover(
            f_past_valid &&
            !reset &&
            (psum_out_south < '0)
        );

        c_enable_active   : cover (f_past_valid && !reset && enable);

        c_enable_inactive : cover (f_past_valid && !reset && !enable);
    end



    // ==========================================================
    // BOLUM 9 — SIGNED / OVERFLOW (opsiyonel, ilginc)
    // ==========================================================
    // INT8 signed: -128..127. mult_result 16 bit.
    // En kotu durum: (-128)*(-128) = 16384 — 16 bit'e sigar mi?
    // ACC_WIDTH=32'de N=8 birikim tasar mi?
    //
    // TODO:
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