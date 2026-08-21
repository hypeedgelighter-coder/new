`timescale 1ns / 1ps

//=====================================================================
// tb_tick_gen_100hz  -  tick_gen_100hz 단독 무작위 테스트벤치
//
//  대상 : tick_gen.v 의 tick_gen_100hz
//
//  이 모듈은 입력이 clk/reset 뿐인 자유 분주기라 "입력을 무작위로" 줄 것이
//  없다. 대신 두 가지를 무작위로 만든다.
//    1) 분주비 F_COUNT 가 서로 다른 인스턴스 3개를 동시에 돌린다
//    2) 무작위 시각에 무작위 길이로 reset 을 때린다
//
//  [검사]
//    - tick 과 tick 사이가 정확히 F_COUNT 클럭인가 (3개 전부)
//    - reset 을 맞으면 위상이 처음부터 다시 시작하는가
//    - reset 중에는 tick 이 안 나오는가
//=====================================================================
module tb_tick_gen_100hz ();

    localparam integer FA = 5;
    localparam integer FB = 13;
    localparam integer FC = 64;

    localparam integer N_RESET = 25;  // 무작위 reset 을 때리는 횟수

    reg  clk = 1'b0;
    reg  reset;
    wire tick_a, tick_b, tick_c;

    integer seed, seed0;
    integer errors, checks;
    integer i;

    // 마지막 tick 이후 흐른 클럭 수 / 본 tick 개수 / 첫 tick 통과 여부
    integer c_a, c_b, c_c;
    integer n_a, n_b, n_c;
    reg     arm_a, arm_b, arm_c;

    always #5 clk = ~clk;

    tick_gen_100hz #(.F_COUNT(FA)) DUT_A (.clk(clk), .reset(reset), .o_tick(tick_a));
    tick_gen_100hz #(.F_COUNT(FB)) DUT_B (.clk(clk), .reset(reset), .o_tick(tick_b));
    tick_gen_100hz #(.F_COUNT(FC)) DUT_C (.clk(clk), .reset(reset), .o_tick(tick_c));

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20) $display("  FAIL [%0t] %0s", $time, tag);
            end
        end
    endtask

    //-----------------------------------------------------------------
    //  tick 간격 감시. reset 을 맞으면 처음부터 다시 센다.
    //  (리셋 직후 첫 tick 은 위상 정렬분이라 간격을 보지 않는다)
    //-----------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            c_a = 0; arm_a = 1'b0;
            c_b = 0; arm_b = 1'b0;
            c_c = 0; arm_c = 1'b0;
            chk(tick_a === 1'b0 && tick_b === 1'b0 && tick_c === 1'b0,
                "tick during reset");
        end else begin
            c_a = c_a + 1;
            if (tick_a) begin
                if (arm_a) chk(c_a == FA, "gap != F_COUNT (A)");
                arm_a = 1'b1;
                n_a   = n_a + 1;
                c_a   = 0;
            end

            c_b = c_b + 1;
            if (tick_b) begin
                if (arm_b) chk(c_b == FB, "gap != F_COUNT (B)");
                arm_b = 1'b1;
                n_b   = n_b + 1;
                c_b   = 0;
            end

            c_c = c_c + 1;
            if (tick_c) begin
                if (arm_c) chk(c_c == FC, "gap != F_COUNT (C)");
                arm_c = 1'b1;
                n_c   = n_c + 1;
                c_c   = 0;
            end
        end
    end

    initial begin
        seed0  = 32'h5EED_0100;
        seed   = seed0;
        errors = 0;
        checks = 0;
        n_a = 0; n_b = 0; n_c = 0;

        reset = 1'b1;
        repeat (3) @(negedge clk);
        reset = 1'b0;

        for (i = 0; i < N_RESET; i = i + 1) begin
            // 무작위 길이만큼 자유 주행시킨 뒤
            repeat (30 + ({$random(seed)} % 400)) @(negedge clk);
            // 무작위 길이만큼 reset 을 때린다
            reset = 1'b1;
            repeat (1 + ({$random(seed)} % 9)) @(negedge clk);
            reset = 1'b0;
        end
        repeat (400) @(negedge clk);

        // tick 이 실제로 나왔는지 (감시만 하고 아무것도 안 나온 경우 방지)
        chk(n_a > 50, "no tick from A");
        chk(n_b > 20, "no tick from B");
        chk(n_c > 5,  "no tick from C");

        $display("  tick count : A=%0d  B=%0d  C=%0d", n_a, n_b, n_c);
        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_tick_gen_100hz : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_tick_gen_100hz : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_tick_gen_100hz : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
