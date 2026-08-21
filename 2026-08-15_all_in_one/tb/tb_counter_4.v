`timescale 1ns / 1ps

//=====================================================================
// tb_counter_4  -  counter_4 단독 무작위 테스트벤치
//
//  대상 : fnd_controller.v 의 counter_4
//
//  tick 이 들어올 때만 0->1->2->3->0 으로 도는 2비트 카운터.
//  FND 자리 스캔 순서를 만든다.
//
//  [무작위로 만드는 것]
//    매 클럭 tick 을 무작위로. (연속으로 들어오는 경우, 한참 안 들어오는
//    경우가 다 섞인다) 중간에 무작위로 reset 도 때린다.
//
//  [검사 방법]  참조 모델과 매 클럭 비교
//    - tick 이 없으면 값이 그대로 유지되는가 (클럭마다 세면 안 된다)
//    - 3 다음이 0 으로 랩하는가
//    - reset 이면 0 인가
//=====================================================================
module tb_counter_4 ();

    localparam integer N_CYCLE = 4000;

    reg        clk = 1'b0;
    reg        reset;
    reg        tick;
    wire [1:0] digit_sel;

    reg [1:0] model;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on;

    always #5 clk = ~clk;

    counter_4 DUT (
        .clk      (clk),
        .reset    (reset),
        .tick     (tick),
        .digit_sel(digit_sel)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  dut=%0d model=%0d",
                             $time, tag, digit_sel, model);
            end
        end
    endtask

    // 참조 모델
    always @(posedge clk, posedge reset) begin
        if (reset) model <= 2'd0;
        else if (tick) model <= (model == 2'd3) ? 2'd0 : model + 2'd1;
    end

    always @(posedge clk) begin
        if (monitor_on) chk(digit_sel === model, "digit_sel mismatch");
    end

    initial begin
        seed0  = 32'h0C04_0404;
        seed   = seed0;
        errors = 0;
        checks = 0;

        monitor_on = 1'b0;
        reset      = 1'b1;
        tick       = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;
        chk(digit_sel === 2'd0, "not 0 after reset");

        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            tick  = (({$random(seed)} % 4) == 0);   // 1/4
            reset = (({$random(seed)} % 500) == 0); // 가끔 리셋
        end
        @(negedge clk);
        tick = 1'b0; reset = 1'b0;
        @(negedge clk);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_counter_4 : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_counter_4 : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #2_000_000;
        $display("  tb_counter_4 : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
