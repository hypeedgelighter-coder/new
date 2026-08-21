`timescale 1ns / 1ps

//=====================================================================
// tb_btn_unit  -  btn_unit 단독 무작위 테스트벤치
//
//  대상 : btn_unit.v  (btn_debounce 4개 묶음)
//
//  btn_debounce 하나의 동작은 tb_btn_debounce 에서 따로 본다. 여기서는
//  "4채널이 서로 간섭하지 않는가" 를 본다. 그래서 네 채널에 서로 다른
//  무작위 패턴을 동시에 흘린다.
//
//  [무작위로 만드는 것]
//    채널마다 독립적으로 "샘플 한 칸" 단위 0/1 패턴을 만든다.
//    런 길이가 1~12 샘플이라 8샘플을 넘기는 진짜 누름과 못 넘기는
//    채터링이 채널마다 다른 시점에 섞여 들어간다.
//
//  [검사 방법]
//    채널별로 "8개 연속 1 이 되는 순간의 개수"를 미리 세어 두고,
//    실제로 그 채널에서 나온 펄스 개수와 비교한다.
//    한 채널의 입력이 다른 채널 출력에 영향을 주면 개수가 어긋난다.
//=====================================================================
module tb_btn_unit ();

    localparam integer SAMPLE = 10;
    localparam integer NBIT   = 600;
    localparam integer TAIL   = 12;

    reg  clk = 1'b0;
    reg  reset;
    reg  i_l, i_r, i_u, i_d;
    wire o_l, o_r, o_u, o_d;

    reg [3:0] pat[0:NBIT-1];  // 비트 0=L, 1=R, 2=U, 3=D

    integer seed, seed0;
    integer errors, checks;
    integer i, j, k, c, runlen;
    reg     b;
    reg [3:0] tmp;

    reg [7:0] hist;
    reg       deb, prev_deb;
    integer   exp_n[0:3];
    integer   got_n[0:3];
    reg       monitor_on;

    always #5 clk = ~clk;

    btn_unit #(
        .SAMPLE_COUNT(SAMPLE)
    ) DUT (
        .clk    (clk),
        .reset  (reset),
        .i_btn_l(i_l),
        .i_btn_r(i_r),
        .i_btn_u(i_u),
        .i_btn_d(i_d),
        .o_btn_l(o_l),
        .o_btn_r(o_r),
        .o_btn_u(o_u),
        .o_btn_d(o_d)
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
            if (o_l) got_n[0] = got_n[0] + 1;
            if (o_r) got_n[1] = got_n[1] + 1;
            if (o_u) got_n[2] = got_n[2] + 1;
            if (o_d) got_n[3] = got_n[3] + 1;
        end
    end

    initial begin
        seed0  = 32'h4B70_0007;
        seed   = seed0;
        errors = 0;
        checks = 0;

        //---------------- 채널별 무작위 패턴 ----------------
        for (c = 0; c < 4; c = c + 1) begin
            k = 0;
            b = 1'b0;
            while (k < NBIT) begin
                runlen = 1 + ({$random(seed)} % 12);
                for (j = 0; j < runlen && k < NBIT; j = j + 1) begin
                    tmp    = pat[k];
                    tmp[c] = b;
                    pat[k] = tmp;
                    k      = k + 1;
                end
                b = ~b;
            end
        end
        for (i = NBIT - TAIL; i < NBIT; i = i + 1) pat[i] = 4'b0000;

        //---------------- 채널별 기대 펄스 수 ----------------
        for (c = 0; c < 4; c = c + 1) begin
            hist     = 8'h00;
            prev_deb = 1'b0;
            exp_n[c] = 0;
            got_n[c] = 0;
            for (i = 0; i < NBIT; i = i + 1) begin
                tmp  = pat[i];
                hist = {tmp[c], hist[7:1]};
                deb  = &hist;
                if (deb && !prev_deb) exp_n[c] = exp_n[c] + 1;
                prev_deb = deb;
            end
        end

        //---------------- 리셋 ----------------
        monitor_on = 1'b0;
        reset      = 1'b1;
        {i_d, i_u, i_r, i_l} = 4'b0000;
        repeat (3) @(negedge clk);
        reset      = 1'b0;
        monitor_on = 1'b1;
        repeat (SAMPLE / 2) @(negedge clk);  // 샘플 시점 한가운데로

        //---------------- 네 채널 동시에 흘리기 ----------------
        for (i = 0; i < NBIT; i = i + 1) begin
            {i_d, i_u, i_r, i_l} = pat[i];
            repeat (SAMPLE) @(negedge clk);
        end
        {i_d, i_u, i_r, i_l} = 4'b0000;
        repeat (4 * SAMPLE) @(negedge clk);

        for (c = 0; c < 4; c = c + 1) begin
            chk(exp_n[c] > 5,          "too few presses in pattern");
            chk(got_n[c] == exp_n[c],  "channel pulse count mismatch");
        end
        $display("  L exp=%0d got=%0d | R exp=%0d got=%0d | U exp=%0d got=%0d | D exp=%0d got=%0d",
                 exp_n[0], got_n[0], exp_n[1], got_n[1],
                 exp_n[2], got_n[2], exp_n[3], got_n[3]);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_btn_unit : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_btn_unit : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_btn_unit : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
