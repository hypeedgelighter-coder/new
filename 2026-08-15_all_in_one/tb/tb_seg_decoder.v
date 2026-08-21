`timescale 1ns / 1ps

//=====================================================================
// tb_seg_decoder  -  seg_decoder 단독 무작위 테스트벤치
//
//  대상 : fnd_controller.v 의 seg_decoder
//
//  조합회로라 클럭이 없다. 4비트 입력 -> 8비트 세그먼트 코드.
//  공통애노드라 비트가 0 인 곳이 켜진다.
//    4'h0~9 숫자, 4'ha~d 는 A~d, 4'he 는 전소등(BLANK), 4'hf 는 dp 만
//
//  [무작위로 만드는 것]
//    입력 16가지를 무작위 순서로 계속 때린다. (전수 확인도 같이 한다)
//
//  [검사 방법]
//    테스트벤치가 세그먼트 표를 따로 들고 비교한다.
//    표가 바뀌면(오타/수정) 바로 잡히라고 일부러 값을 따로 적어 둔다.
//=====================================================================
module tb_seg_decoder ();

    localparam integer N_RAND = 500;

    reg  [3:0] bcd_in;
    wire [7:0] seg_out;

    reg [7:0] tbl[0:15];

    integer seed, seed0;
    integer errors, checks;
    integer i;

    seg_decoder DUT (
        .bcd_in (bcd_in),
        .seg_out(seg_out)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  in=%h out=%h exp=%h",
                             $time, tag, bcd_in, seg_out, tbl[bcd_in]);
            end
        end
    endtask

    initial begin
        seed0  = 32'h5E60_DEC0;
        seed   = seed0;
        errors = 0;
        checks = 0;

        tbl[0]  = 8'hc0; tbl[1]  = 8'hf9; tbl[2]  = 8'ha4; tbl[3]  = 8'hb0;
        tbl[4]  = 8'h99; tbl[5]  = 8'h92; tbl[6]  = 8'h82; tbl[7]  = 8'hf8;
        tbl[8]  = 8'h80; tbl[9]  = 8'h90; tbl[10] = 8'h88; tbl[11] = 8'h83;
        tbl[12] = 8'hc6; tbl[13] = 8'ha1;
        tbl[14] = 8'hff;  // BLANK : 전부 소등
        tbl[15] = 8'h7f;  // dp only

        //---------------- 전수 확인 ----------------
        for (i = 0; i < 16; i = i + 1) begin
            bcd_in = i[3:0];
            #1;
            chk(seg_out === tbl[i], "segment code mismatch");
        end

        //---------------- 무작위 확인 ----------------
        for (i = 0; i < N_RAND; i = i + 1) begin
            bcd_in = {$random(seed)} % 16;
            #1;
            chk(seg_out === tbl[bcd_in], "segment code mismatch");
        end

        // 숫자 자리에서 dp(비트7)가 켜지면 안 된다 (dot 은 상위에서 따로 붙인다)
        for (i = 0; i < 10; i = i + 1) begin
            bcd_in = i[3:0];
            #1;
            chk(seg_out[7] === 1'b1, "dp is on for a digit");
        end

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_seg_decoder : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_seg_decoder : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #100_000;
        $display("  tb_seg_decoder : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
