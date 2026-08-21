`timescale 1ns / 1ps

//=====================================================================
// tb_tick_gen_1us  -  tick_gen_1us 단독 무작위 테스트벤치
//
//  대상 : tick_gen.v 의 tick_gen_1us
//  사용 : 이 파일을 Set as Top -> Run Simulation (xsim 콘솔이면 run -all)
//
//  [무작위로 만드는 것]
//    매 클럭 run_stop / clear 를 무작위로 흔든다.
//
//  [검사 원리]
//    DUT 내부는 들여다보지 않는다. 밖에서 셀 수 있는 성질만 쓴다.
//      "clear 이후 run_stop=1 이었던 클럭 수"를 테스트벤치가 따로 세고,
//      그 수를 F_COUNT 로 나눈 몫이 그동안 나온 o_tick 개수와 같아야 한다.
//    이 등식을 매 클럭 확인한다.
//
//  [추가로 보는 것]
//    2) run_stop 을 계속 1 로 두면 tick 간격이 정확히 F_COUNT 클럭
//    3) clear 를 주면 세던 것이 0 으로 돌아가 다시 F_COUNT 부터 센다
//    4) run_stop=0 은 "멈춤"이지 "지움"이 아니다
//
//  [테스트벤치 규칙]  전 파일 공통
//    - 자극은 negedge 에서 준다 (posedge 에서 DUT 가 볼 때 이미 안정)
//    - 값을 읽는 것도 negedge, 스코어보드는 posedge 에서 직전값을 본다
//=====================================================================
module tb_tick_gen_1us ();

    localparam integer F       = 7;     // 시뮬용으로 줄인 분주비
    localparam integer N_CYCLE = 5000;  // 무작위로 흔들 클럭 수

    reg  clk = 1'b0;
    reg  reset;
    reg  run_stop, clear;
    wire o_tick;

    integer seed, seed0;
    integer errors, checks;

    integer run_cycles;  // clear 이후 run_stop=1 이었던 클럭 수
    integer exp_tick;    // 그때까지 나왔어야 하는 tick 총 개수
    integer got_tick;    // 실제로 본 tick 총 개수
    integer i, gap;
    reg     monitor_on;

    always #5 clk = ~clk;  // 100MHz

    tick_gen_1us #(
        .F_COUNT(F)
    ) DUT (
        .clk     (clk),
        .reset   (reset),
        .run_stop(run_stop),
        .clear   (clear),
        .o_tick  (o_tick)
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

    //-----------------------------------------------------------------
    //  매 클럭 감시 : got_tick == exp_tick 이 항상 성립해야 한다
    //   o_tick 은 "직전 엣지에 결정된" 값이라 먼저 세고,
    //   그 다음 이번 엣지에서 DUT 가 무엇을 할지 예측한다.
    //-----------------------------------------------------------------
    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            if (o_tick) got_tick = got_tick + 1;

            chk(got_tick == exp_tick, "tick count mismatch");

            if (clear) run_cycles = 0;
            else if (run_stop) begin
                run_cycles = run_cycles + 1;
                if (run_cycles == F) begin
                    run_cycles = 0;
                    exp_tick   = exp_tick + 1;
                end
            end
        end
    end

    task do_reset;
        begin
            monitor_on = 1'b0;
            reset      = 1'b1;
            run_stop   = 1'b0;
            clear      = 1'b0;
            repeat (3) @(negedge clk);
            reset      = 1'b0;
            run_cycles = 0;
            exp_tick   = 0;
            got_tick   = 0;
            @(negedge clk);
            monitor_on = 1'b1;
        end
    endtask

    // o_tick 이 뜰 때까지 negedge 를 세면서 기다린다. 반환값은 센 클럭 수.
    task wait_tick(output integer n);
        begin
            n = 0;
            @(negedge clk);
            n = 1;
            while (o_tick !== 1'b1 && n < 100 * F) begin
                @(negedge clk);
                n = n + 1;
            end
        end
    endtask

    initial begin
        seed0  = 32'h0BADC0DE;  // 씨앗. 바꾸면 다른 무작위 패턴이 나온다.
        seed   = seed0;
        errors = 0;
        checks = 0;

        //---------------- 1) 전 구간 무작위 ----------------
        do_reset;
        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            run_stop = (({$random(seed)} % 8) != 0);   // 7/8 확률로 1
            clear    = (({$random(seed)} % 32) == 0);  // 1/32 확률로 1
        end
        @(negedge clk);
        run_stop   = 1'b0;
        clear      = 1'b0;
        monitor_on = 1'b0;

        //---------------- 2) 연속 run 구간의 tick 간격 ----------------
        do_reset;
        monitor_on = 1'b0;
        run_stop   = 1'b1;
        clear      = 1'b0;
        wait_tick(gap);  // 첫 tick 은 리셋 위상이라 간격을 안 본다
        repeat (6) begin
            wait_tick(gap);
            chk(gap == F, "tick gap != F_COUNT");
        end

        //---------------- 3) clear 는 세던 것을 0 으로 되돌린다 ----------------
        do_reset;
        monitor_on = 1'b0;
        run_stop   = 1'b1;
        clear      = 1'b0;
        repeat (F - 2) @(negedge clk);  // tick 나기 직전까지 세워 두고
        clear = 1'b1;
        @(negedge clk);
        clear = 1'b0;
        wait_tick(gap);  // clear 했으니 다시 F 클럭을 꽉 채워야 한다
        chk(gap == F, "clear did not reset phase");

        //---------------- 4) run_stop=0 은 멈춤이지 지움이 아니다 ----------------
        do_reset;
        monitor_on = 1'b0;
        run_stop   = 1'b1;
        clear      = 1'b0;
        repeat (F - 1) @(negedge clk);  // tick 한 칸 전까지 세어 둔 상태
        run_stop = 1'b0;
        repeat (50) begin  // 한참 멈춰 있어도 tick 이 나오면 안 된다
            @(negedge clk);
            chk(o_tick === 1'b0, "tick while run_stop=0");
        end
        run_stop = 1'b1;  // 다시 켜면 남은 1클럭만에 나와야 한다
        wait_tick(gap);
        chk(gap == 1, "counter was cleared by run_stop=0");

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_tick_gen_1us : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_tick_gen_1us : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_tick_gen_1us : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
