`timescale 1ns / 1ps

//=====================================================================
// tb_fnd_scan_tick  -  fnd_scan_tick 단독 무작위 테스트벤치
//
//  대상 : fnd_controller.v 의 fnd_scan_tick
//
//  FND 자리 스캔용 분주기. COUNT 클럭마다 1클럭 폭 tick.
//  (실보드는 100_000 = 1kHz. 자리 4개라 화면 갱신 250Hz)
//
//  [무작위로 만드는 것]
//    분주비가 다른 인스턴스 3개를 동시에 돌리고, 무작위 시각에
//    무작위 길이로 reset 을 때린다.
//
//  [검사]
//    - tick 간격이 정확히 COUNT 클럭인가
//    - reset 중에는 tick 이 안 나오고, 풀리면 위상이 처음부터인가
//    - tick 폭이 1클럭인가 (넓으면 자리가 두 칸씩 넘어간다)
//=====================================================================
module tb_fnd_scan_tick ();

    localparam integer CA = 4;
    localparam integer CB = 17;
    localparam integer CC = 100;

    localparam integer N_RESET = 20;

    reg  clk = 1'b0;
    reg  reset;
    wire ta, tb, tc;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    integer c_a, c_b, c_c;
    integer n_a, n_b, n_c;
    reg     arm_a, arm_b, arm_c;
    reg     p_a, p_b, p_c;

    always #5 clk = ~clk;

    fnd_scan_tick #(.COUNT(CA)) DUT_A (.clk(clk), .reset(reset), .o_tick(ta));
    fnd_scan_tick #(.COUNT(CB)) DUT_B (.clk(clk), .reset(reset), .o_tick(tb));
    fnd_scan_tick #(.COUNT(CC)) DUT_C (.clk(clk), .reset(reset), .o_tick(tc));

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
        if (reset) begin
            c_a = 0; arm_a = 1'b0;
            c_b = 0; arm_b = 1'b0;
            c_c = 0; arm_c = 1'b0;
            chk(ta === 1'b0 && tb === 1'b0 && tc === 1'b0, "tick during reset");
        end else begin
            chk(!(ta && p_a), "tick A wider than 1 clk");
            chk(!(tb && p_b), "tick B wider than 1 clk");
            chk(!(tc && p_c), "tick C wider than 1 clk");

            c_a = c_a + 1;
            if (ta) begin
                if (arm_a) chk(c_a == CA, "gap != COUNT (A)");
                arm_a = 1'b1; n_a = n_a + 1; c_a = 0;
            end
            c_b = c_b + 1;
            if (tb) begin
                if (arm_b) chk(c_b == CB, "gap != COUNT (B)");
                arm_b = 1'b1; n_b = n_b + 1; c_b = 0;
            end
            c_c = c_c + 1;
            if (tc) begin
                if (arm_c) chk(c_c == CC, "gap != COUNT (C)");
                arm_c = 1'b1; n_c = n_c + 1; c_c = 0;
            end
        end
        p_a = ta; p_b = tb; p_c = tc;
    end

    initial begin
        seed0  = 32'h5CA4_7104;
        seed   = seed0;
        errors = 0;
        checks = 0;
        n_a = 0; n_b = 0; n_c = 0;
        p_a = 1'b0; p_b = 1'b0; p_c = 1'b0;

        reset = 1'b1;
        repeat (3) @(negedge clk);
        reset = 1'b0;

        for (i = 0; i < N_RESET; i = i + 1) begin
            repeat (50 + ({$random(seed)} % 500)) @(negedge clk);
            reset = 1'b1;
            repeat (1 + ({$random(seed)} % 7)) @(negedge clk);
            reset = 1'b0;
        end
        repeat (600) @(negedge clk);

        chk(n_a > 50, "no tick from A");
        chk(n_b > 20, "no tick from B");
        chk(n_c > 3,  "no tick from C");
        $display("  tick count : A=%0d  B=%0d  C=%0d", n_a, n_b, n_c);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_fnd_scan_tick : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_fnd_scan_tick : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_fnd_scan_tick : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
