`timescale 1ns / 1ps

//=====================================================================
// tb_btn_debounce  -  btn_debounce 단독 무작위 테스트벤치
//
//  대상 : btn_debounce.v
//
//  이 모듈은 SAMPLE_COUNT 클럭마다 버튼을 한 번씩 샘플해서, 8번 연속
//  1 이어야 "눌렸다"고 인정하고 그 순간에만 1클럭 폭 펄스를 낸다.
//  시뮬에서는 SAMPLE_COUNT=10 으로 줄여 8샘플 = 80클럭이면 인정된다.
//
//  [무작위로 만드는 것]
//    "샘플 한 칸" 단위의 0/1 패턴을 무작위 길이의 런(run)으로 만든다.
//    런 길이가 1~12 샘플이라 8 을 넘기는 진짜 누름과 8 을 못 넘기는
//    채터링이 저절로 섞여 나온다. (아래는 예시)
//
//      패턴  0000 111 0 11111111111 0000 1 0 11111111 000...
//                  ^^^ 3샘플 채터   ^^^^^^^ 진짜 누름   ^^^^^^ 진짜 누름
//                  펄스 없음        펄스 1회            펄스 1회
//
//  [검사 방법]
//    패턴을 그대로 DUT 에 흘리면서, 같은 패턴에 대해 테스트벤치가
//    "8개 연속 1 이 되는 순간의 개수"를 세어 둔다. 그 개수와 실제로
//    나온 펄스 개수가 같아야 한다.
//    자극을 DUT 의 샘플 시점 한가운데에 걸리도록 반 칸 밀어서 준다.
//
//  [같이 보는 것]
//    - 펄스 폭은 항상 1클럭 (붙잡고 있어도 두 클럭 이상 안 뜬다)
//    - 계속 눌러도 추가 펄스가 안 나온다 (위 규칙에 이미 포함)
//=====================================================================
module tb_btn_debounce ();

    localparam integer SAMPLE = 10;   // 샘플 한 칸 = 10클럭
    localparam integer NBIT   = 600;  // 무작위 샘플 패턴 길이
    localparam integer TAIL   = 12;   // 끝에 붙이는 0 구간 (시프트 비우기)

    reg  clk = 1'b0;
    reg  reset;
    reg  i_btn;
    wire o_btn;

    reg pat[0:NBIT-1];

    integer seed, seed0;
    integer errors, checks;
    integer i, j, runlen, k;
    reg     b;

    reg [7:0] hist;
    reg       deb, prev_deb, prev_o;
    integer   exp_n, got_n;
    reg       monitor_on;

    always #5 clk = ~clk;

    btn_debounce #(
        .SAMPLE_COUNT(SAMPLE)
    ) DUT (
        .clk  (clk),
        .reset(reset),
        .i_btn(i_btn),
        .o_btn(o_btn)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20) $display("  FAIL [%0t] %0s", $time, tag);
            end
        end
    endtask

    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            if (o_btn) got_n = got_n + 1;
            chk(!(o_btn === 1'b1 && prev_o === 1'b1), "pulse wider than 1 clk");
            prev_o = o_btn;
        end
    end

    initial begin
        seed0  = 32'h00B7_0BEE;
        seed   = seed0;
        errors = 0;
        checks = 0;
        got_n  = 0;
        prev_o = 1'b0;

        //---------------- 무작위 패턴 만들기 ----------------
        k = 0;
        b = 1'b0;
        while (k < NBIT) begin
            runlen = 1 + ({$random(seed)} % 12);  // 런 길이 1~12 샘플
            for (j = 0; j < runlen && k < NBIT; j = j + 1) begin
                pat[k] = b;
                k = k + 1;
            end
            b = ~b;
        end
        for (i = NBIT - TAIL; i < NBIT; i = i + 1) pat[i] = 1'b0;  // 끝은 비운다

        //---------------- 같은 패턴으로 기대 펄스 수 계산 ----------------
        hist     = 8'h00;
        prev_deb = 1'b0;
        exp_n    = 0;
        for (i = 0; i < NBIT; i = i + 1) begin
            hist = {pat[i], hist[7:1]};
            deb  = &hist;
            if (deb && !prev_deb) exp_n = exp_n + 1;
            prev_deb = deb;
        end

        //---------------- 리셋 ----------------
        monitor_on = 1'b0;
        reset      = 1'b1;
        i_btn      = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        monitor_on = 1'b1;

        // DUT 의 샘플 시점은 리셋 해제 후 SAMPLE 클럭마다 온다.
        // 자극이 그 한가운데 걸리도록 반 칸 밀어 놓는다.
        repeat (SAMPLE / 2) @(negedge clk);

        //---------------- 패턴 흘리기 ----------------
        for (i = 0; i < NBIT; i = i + 1) begin
            i_btn = pat[i];
            repeat (SAMPLE) @(negedge clk);
        end
        i_btn = 1'b0;
        repeat (4 * SAMPLE) @(negedge clk);

        chk(exp_n > 5, "pattern produced too few presses");
        chk(got_n == exp_n, "pulse count mismatch");
        $display("  presses expected=%0d  pulses seen=%0d", exp_n, got_n);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_btn_debounce : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_btn_debounce : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_btn_debounce : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
