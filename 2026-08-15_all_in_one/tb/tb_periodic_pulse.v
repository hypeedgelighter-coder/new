`timescale 1ns / 1ps

//=====================================================================
// tb_periodic_pulse  -  periodic_pulse 단독 무작위 테스트벤치
//
//  대상 : tick_gen.v 의 periodic_pulse
//
//  en 이 1 인 동안만 세고, COUNT 클럭마다 1클럭 폭 o_pulse 를 낸다.
//  en 이 0 이 되면 세던 것을 "멈추는" 게 아니라 0 으로 "지운다".
//  (tick_gen_1us 의 run_stop 과 다른 점이다. 여기가 헷갈리기 쉬워서
//   그 차이를 정면으로 확인한다)
//
//  [무작위로 만드는 것]  매 클럭 en 을 무작위로 흔든다.
//
//  [검사 원리]
//    "en 이 끊기지 않고 1 이었던 클럭 수"를 테스트벤치가 따로 세고,
//    그 수가 COUNT 에 닿을 때마다 pulse 가 하나 나와야 한다.
//    이 누적 개수를 매 클럭 비교한다.
//=====================================================================
module tb_periodic_pulse ();

    localparam integer COUNT   = 6;
    localparam integer N_CYCLE = 6000;

    reg  clk = 1'b0;
    reg  reset;
    reg  en;
    wire o_pulse;

    integer seed, seed0;
    integer errors, checks;
    integer win;       // en 이 연속으로 1 이었던 클럭 수
    integer exp_pulse; // 그때까지 나왔어야 하는 pulse 총 개수
    integer got_pulse;
    integer i, gap;
    reg     monitor_on;

    always #5 clk = ~clk;

    periodic_pulse #(
        .COUNT(COUNT)
    ) DUT (
        .clk    (clk),
        .reset  (reset),
        .en     (en),
        .o_pulse(o_pulse)
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
            if (o_pulse) got_pulse = got_pulse + 1;

            chk(got_pulse == exp_pulse, "pulse count mismatch");

            if (!en) win = 0;  // en=0 은 "지움"
            else begin
                win = win + 1;
                if (win == COUNT) begin
                    win       = 0;
                    exp_pulse = exp_pulse + 1;
                end
            end
        end
    end

    task do_reset;
        begin
            monitor_on = 1'b0;
            reset      = 1'b1;
            en         = 1'b0;
            repeat (3) @(negedge clk);
            reset      = 1'b0;
            win        = 0;
            exp_pulse  = 0;
            got_pulse  = 0;
            @(negedge clk);
            monitor_on = 1'b1;
        end
    endtask

    initial begin
        seed0  = 32'h1234_ABCD;
        seed   = seed0;
        errors = 0;
        checks = 0;

        //---------------- 1) en 을 매 클럭 무작위로 ----------------
        do_reset;
        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            // 그냥 반반으로 흔들면 COUNT 까지 못 채워서 pulse 가 거의 안 나온다.
            // 15/16 확률로 1 을 줘서 긴 en 구간이 자주 생기게 한다.
            en = (({$random(seed)} % 16) != 0);
        end
        @(negedge clk);
        en = 1'b0;
        repeat (4) @(negedge clk);
        chk(got_pulse > 100, "almost no pulse was produced");
        monitor_on = 1'b0;

        //---------------- 2) en 을 계속 켜두면 간격이 COUNT ----------------
        do_reset;
        monitor_on = 1'b0;
        en = 1'b1;
        // 첫 pulse
        gap = 0;
        @(negedge clk);
        while (o_pulse !== 1'b1 && gap < 20 * COUNT) begin
            @(negedge clk);
            gap = gap + 1;
        end
        repeat (8) begin
            gap = 0;
            @(negedge clk);
            gap = 1;
            while (o_pulse !== 1'b1 && gap < 20 * COUNT) begin
                @(negedge clk);
                gap = gap + 1;
            end
            chk(gap == COUNT, "pulse gap != COUNT");
        end

        //---------------- 3) en=0 은 멈춤이 아니라 지움 ----------------
        do_reset;
        monitor_on = 1'b0;
        en = 1'b1;
        repeat (COUNT - 1) @(negedge clk);  // pulse 한 칸 전까지 세어 두고
        en = 1'b0;                          // 여기서 지워져야 한다
        repeat (20) begin
            @(negedge clk);
            chk(o_pulse === 1'b0, "pulse while en=0");
        end
        en  = 1'b1;
        gap = 0;
        @(negedge clk);
        gap = 1;
        while (o_pulse !== 1'b1 && gap < 20 * COUNT) begin
            @(negedge clk);
            gap = gap + 1;
        end
        // 멈춤이었다면 1클럭만에 나왔을 것이고, 지움이면 COUNT 를 다시 채운다
        chk(gap == COUNT, "en=0 did not clear the counter");

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_periodic_pulse : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_periodic_pulse : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_periodic_pulse : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
