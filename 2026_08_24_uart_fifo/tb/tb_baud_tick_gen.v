`timescale 1ns / 1ps

//=====================================================================
// tb_baud_tick_gen  -  baud_tick_gen 단독 무작위 테스트벤치
//
//  대상 : uart.v 의 baud_tick_gen
//
//  보드레이트의 16배(오버샘플)로 tick 을 낸다.
//    DIV = SYS_CLK / (BAUD * 16)
//    9600bps 라면 100M/(9600*16) = 651 클럭마다 한 번
//  이 tick 이 어긋나면 UART 가 통째로 깨지므로 간격을 정확히 본다.
//
//  [무작위로 만드는 것]
//    보드레이트가 다른 인스턴스 3개를 동시에 돌리고, 무작위 시각에
//    무작위 길이로 reset 을 때린다.
//
//  [검사]
//    - tick 간격이 정확히 DIV 클럭인가 (실제 9600bps 설정 포함)
//    - reset 중에는 tick 이 없고, 풀리면 위상이 처음부터인가
//=====================================================================
module tb_baud_tick_gen ();

    // DIV = 100M / (BAUD*16)
    localparam integer BAUD_A = 625_000;  // DIV = 10
    localparam integer BAUD_B = 250_000;  // DIV = 25
    localparam integer BAUD_C = 9_600;    // DIV = 651  (실보드 설정)

    localparam integer DIV_A = 100_000_000 / (BAUD_A * 16);
    localparam integer DIV_B = 100_000_000 / (BAUD_B * 16);
    localparam integer DIV_C = 100_000_000 / (BAUD_C * 16);

    localparam integer N_RESET = 12;

    reg  clk = 1'b0;
    reg  reset;
    wire ta, tb, tc;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    integer c_a, c_b, c_c;
    integer n_a, n_b, n_c;
    reg     arm_a, arm_b, arm_c;

    always #5 clk = ~clk;

    baud_tick_gen #(.SYS_CLK(100_000_000), .BAUD(BAUD_A))
        DUT_A (.clk(clk), .reset(reset), .o_baud_tick(ta));
    baud_tick_gen #(.SYS_CLK(100_000_000), .BAUD(BAUD_B))
        DUT_B (.clk(clk), .reset(reset), .o_baud_tick(tb));
    baud_tick_gen #(.SYS_CLK(100_000_000), .BAUD(BAUD_C))
        DUT_C (.clk(clk), .reset(reset), .o_baud_tick(tc));

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
            c_a = c_a + 1;
            if (ta) begin
                if (arm_a) chk(c_a == DIV_A, "gap != DIV (625k)");
                arm_a = 1'b1; n_a = n_a + 1; c_a = 0;
            end
            c_b = c_b + 1;
            if (tb) begin
                if (arm_b) chk(c_b == DIV_B, "gap != DIV (250k)");
                arm_b = 1'b1; n_b = n_b + 1; c_b = 0;
            end
            c_c = c_c + 1;
            if (tc) begin
                if (arm_c) chk(c_c == DIV_C, "gap != DIV (9600)");
                arm_c = 1'b1; n_c = n_c + 1; c_c = 0;
            end
        end
    end

    initial begin
        seed0  = 32'h9600_1600;
        seed   = seed0;
        errors = 0;
        checks = 0;
        n_a = 0; n_b = 0; n_c = 0;

        $display("  DIV : 625k=%0d  250k=%0d  9600=%0d", DIV_A, DIV_B, DIV_C);

        reset = 1'b1;
        repeat (3) @(negedge clk);
        reset = 1'b0;

        for (i = 0; i < N_RESET; i = i + 1) begin
            repeat (2000 + ({$random(seed)} % 4000)) @(negedge clk);
            reset = 1'b1;
            repeat (1 + ({$random(seed)} % 9)) @(negedge clk);
            reset = 1'b0;
        end
        repeat (4000) @(negedge clk);

        chk(n_a > 500, "no tick from 625k");
        chk(n_b > 200, "no tick from 250k");
        chk(n_c > 10,  "no tick from 9600");
        $display("  tick count : 625k=%0d  250k=%0d  9600=%0d", n_a, n_b, n_c);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_baud_tick_gen : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_baud_tick_gen : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #5_000_000;
        $display("  tb_baud_tick_gen : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
