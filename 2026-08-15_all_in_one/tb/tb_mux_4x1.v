`timescale 1ns / 1ps

//=====================================================================
// tb_mux_4x1  -  mux_4x1 단독 무작위 테스트벤치
//
//  대상 : fnd_controller.v 의 mux_4x1
//
//  FND 자리 선택에 따라 4개 digit 중 하나를 고른다.
//    sel=0 -> digit_1, 1 -> digit_10, 2 -> digit_100, 3 -> digit_1000
//
//  [무작위로 만드는 것]
//    digit 4개와 sel 을 전부 무작위로. 네 입력을 일부러 서로 다른 값으로
//    주기 때문에 자리를 하나라도 바꿔 연결하면 바로 갈린다.
//    (자리 순서를 뒤집어 연결하는 실수가 FND 에서 제일 흔하다)
//
//  [검사 방법]  배열에 담아 sel 로 인덱싱한 값과 비교
//=====================================================================
module tb_mux_4x1 ();

    localparam integer N_RAND = 800;

    reg  [1:0] sel;
    reg  [3:0] d[0:3];
    wire [3:0] mux_out;

    integer seed, seed0;
    integer errors, checks;
    integer i;

    mux_4x1 DUT (
        .sel       (sel),
        .digit_1   (d[0]),
        .digit_10  (d[1]),
        .digit_100 (d[2]),
        .digit_1000(d[3]),
        .mux_out   (mux_out)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  sel=%0d out=%h exp=%h  (%h %h %h %h)",
                             $time, tag, sel, mux_out, d[sel],
                             d[0], d[1], d[2], d[3]);
            end
        end
    endtask

    initial begin
        seed0  = 32'h4041_4241;
        seed   = seed0;
        errors = 0;
        checks = 0;

        // 자리마다 확실히 다른 값을 넣고 sel 을 전수로 돌려 본다
        d[0] = 4'h1; d[1] = 4'h2; d[2] = 4'h4; d[3] = 4'h8;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0];
            #1;
            chk(mux_out === d[sel], "wrong digit selected");
        end

        // 무작위
        for (i = 0; i < N_RAND; i = i + 1) begin
            d[0] = {$random(seed)} % 16;
            d[1] = {$random(seed)} % 16;
            d[2] = {$random(seed)} % 16;
            d[3] = {$random(seed)} % 16;
            sel  = {$random(seed)} % 4;
            #1;
            chk(mux_out === d[sel], "wrong digit selected");
        end

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_mux_4x1 : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_mux_4x1 : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #100_000;
        $display("  tb_mux_4x1 : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
