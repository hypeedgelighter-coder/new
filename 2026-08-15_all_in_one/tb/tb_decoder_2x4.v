`timescale 1ns / 1ps

//=====================================================================
// tb_decoder_2x4  -  decoder_2x4 단독 무작위 테스트벤치
//
//  대상 : fnd_controller.v 의 decoder_2x4
//
//  FND 자리 선택 신호(액티브 로우) 를 만든다.
//    sel=0 -> 1110,  1 -> 1101,  2 -> 1011,  3 -> 0111
//
//  [무작위로 만드는 것]  sel 을 무작위로 계속 바꾼다 (전수 확인도 같이).
//
//  [검사 방법]
//    DUT 는 case 문 4줄이지만, 테스트벤치는 표를 베끼지 않고
//    ~(4'b0001 << sel) 이라는 식으로 따로 계산해서 비교한다.
//    한 자리라도 표를 잘못 적으면 갈린다. 그리고 "항상 정확히 한 자리만
//    0" 이라는 성질도 따로 본다 (두 자리가 동시에 켜지면 글자가 겹친다).
//=====================================================================
module tb_decoder_2x4 ();

    localparam integer N_RAND = 400;

    reg  [1:0] digit_sel;
    wire [3:0] fnd_com;
    reg  [3:0] exp;

    integer seed, seed0;
    integer errors, checks;
    integer i, j, n_low;

    decoder_2x4 DUT (
        .digit_sel(digit_sel),
        .fnd_com  (fnd_com)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  sel=%0d com=%b exp=%b",
                             $time, tag, digit_sel, fnd_com, exp);
            end
        end
    endtask

    task one_case(input [1:0] s);
        begin
            digit_sel = s;
            #1;
            exp = ~(4'b0001 << s);
            chk(fnd_com === exp, "fnd_com mismatch");

            n_low = 0;
            for (j = 0; j < 4; j = j + 1) if (fnd_com[j] === 1'b0) n_low = n_low + 1;
            chk(n_low == 1, "not exactly one digit enabled");
        end
    endtask

    initial begin
        seed0  = 32'h0DEC_2004;
        seed   = seed0;
        errors = 0;
        checks = 0;

        for (i = 0; i < 4; i = i + 1) one_case(i[1:0]);
        for (i = 0; i < N_RAND; i = i + 1) one_case({$random(seed)} % 4);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_decoder_2x4 : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_decoder_2x4 : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #100_000;
        $display("  tb_decoder_2x4 : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
