`timescale 1ns / 1ps

//=====================================================================
// tb_sr04_controller  -  sr04_controller 단독 무작위 테스트벤치
//
//  대상 : sr04_controller.v
//
//  start 를 받으면 11us trigger 를 내고, echo 가 High 였던 시간을 재서
//  거리로 바꾼다. 거리 = 시간(us) / 58 을, 100MHz 에서 나눗셈을 피하려고
//  (us * 1130 + 32768) >> 16 곱셈+반올림으로 계산한다.
//
//  유효 판정
//    echo 폭이 100us ~ 23200us 안이면 valid=1
//    그보다 짧거나 길면 / 아예 응답이 없으면 valid=0, distance=0
//    (400cm 로 클램프하지 않는다. 안 들어온 것과 400cm 는 다른 얘기다)
//
//  시뮬에서는 "1us" 를 4클럭으로 줄여 쓴다.
//
//  [무작위로 만드는 것]
//    1) echo 폭 (유효 범위 안에서 무작위)
//    2) trigger 가 끝나고 echo 가 올라오기까지의 지연 (무작위)
//    3) 경계 밖 케이스도 섞는다 (너무 짧음 / 너무 김 / 무응답 / 계속 High)
//
//  [검사]
//    - distance 가 계산식과 맞는가 (틱 위상 때문에 측정이 ±1us 흔들릴 수
//      있어서 폭 w-1 ~ w+1 로 계산한 범위 안이면 통과로 본다)
//    - 유효 범위 밖이면 valid=0 이고 distance=0 인가
//    - trigger 폭이 10us 이상인가 (데이터시트 최소 10us)
//    - start 를 안 줬는데 trigger 가 나가지 않는가
//=====================================================================
module tb_sr04_controller ();

    localparam integer TICK = 4;  // "1us" = 4클럭

    reg clk = 1'b0;
    reg reset;
    reg start;
    reg echo;
    wire done, valid, trigger;
    wire [8:0] distance;

    integer seed, seed0;
    integer errors, checks;
    integer i, w, dly, guard;
    integer exp_lo, exp_hi;
    integer trig_clks;

    // done 은 1클럭만 뜨고, echo 폭이 최대치를 넘으면 우리가 echo 를 내리기
    // 전에 먼저 끝나 버린다. 그래서 폴링하지 않고 따로 잡아 둔다.
    reg       done_seen;
    reg       cap_valid;
    reg [8:0] cap_dist;

    always @(posedge clk) begin
        if (done) begin
            done_seen = 1'b1;
            cap_valid = valid;      // done 이 뜬 시점엔 이미 확정된 값
            cap_dist  = distance;
        end
    end

    always #5 clk = ~clk;

    sr04_controller #(
        .TICK_1US(TICK)
    ) DUT (
        .clk     (clk),
        .reset   (reset),
        .start   (start),
        .echo    (echo),
        .done    (done),
        .valid   (valid),
        .trigger (trigger),
        .distance(distance)
    );

    task chk(input cond, input [8*30:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  w=%0dus dist=%0d valid=%b (exp %0d~%0d)",
                             $time, tag, w, distance, valid, exp_lo, exp_hi);
            end
        end
    endtask

    task wait_us(input integer n);
        begin
            repeat (n * TICK) @(negedge clk);
        end
    endtask

    function integer calc_cm(input integer us);
        begin
            calc_cm = (us * 1130 + 32768) / 65536;
        end
    endfunction

    // start 를 주고 trigger 가 끝날 때까지. trigger 폭도 같이 잰다.
    task kick;
        begin
            @(negedge clk);
            done_seen = 1'b0;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            guard = 0;
            while (trigger !== 1'b1 && guard < 100) begin
                @(negedge clk);
                guard = guard + 1;
            end
            chk(trigger === 1'b1, "no trigger after start");

            trig_clks = 0;
            while (trigger === 1'b1 && trig_clks < 100 * TICK) begin
                @(negedge clk);
                trig_clks = trig_clks + 1;
            end
            chk(trig_clks >= 10 * TICK, "trigger shorter than 10us");
            chk(trig_clks <= 13 * TICK, "trigger longer than 13us");
        end
    endtask

    // done 이 잡힐 때까지 기다린다
    task wait_done(input integer max_us);
        begin
            guard = 0;
            while (done_seen !== 1'b1 && guard < max_us * TICK) begin
                @(negedge clk);
                guard = guard + 1;
            end
            chk(done_seen === 1'b1, "done never came");
            @(negedge clk);
        end
    endtask

    // 한 번 측정 : echo 를 w us 동안 올린다
    task one_shot(input integer width_us, input integer delay_us);
        begin
            w = width_us;
            kick;
            wait_us(delay_us);
            echo = 1'b1;
            wait_us(width_us);
            echo = 1'b0;
            wait_done(2000 + width_us);

            if (width_us >= 100 && width_us <= 23200) begin
                exp_lo = calc_cm(width_us - 1);
                exp_hi = calc_cm(width_us + 1);
                chk(cap_valid === 1'b1, "valid echo reported invalid");
                chk(cap_dist >= exp_lo && cap_dist <= exp_hi, "distance out of range");
            end else begin
                exp_lo = 0;
                exp_hi = 0;
                chk(cap_valid === 1'b0, "out-of-range echo reported valid");
                chk(cap_dist === 9'd0,  "distance not cleared on invalid");
            end
            repeat (20) @(negedge clk);
        end
    endtask

    initial begin
        seed0  = 32'h5204_0001;
        seed   = seed0;
        errors = 0;
        checks = 0;

        reset = 1'b1;
        start = 1'b0;
        echo  = 1'b0;
        repeat (5) @(negedge clk);
        reset = 1'b0;
        repeat (20) @(negedge clk);

        //---------------- start 없으면 trigger 도 없다 ----------------
        repeat (200) begin
            @(negedge clk);
            chk(trigger === 1'b0, "trigger without start");
        end

        //---------------- 대표 거리 몇 개 (눈으로도 보이게) ----------------
        w = 580;  one_shot(580, 40);   // 약 10cm
        $display("   580us -> %0d cm (valid=%b)", distance, valid);
        w = 1740; one_shot(1740, 40);  // 약 30cm
        $display("  1740us -> %0d cm (valid=%b)", distance, valid);
        w = 5800; one_shot(5800, 40);  // 약 100cm
        $display("  5800us -> %0d cm (valid=%b)", distance, valid);

        //---------------- 무작위 폭 ----------------
        for (i = 0; i < 12; i = i + 1) begin
            w   = 100 + ({$random(seed)} % 3000);
            dly = 5 + ({$random(seed)} % 200);
            one_shot(w, dly);
        end

        //---------------- 경계 밖 ----------------
        one_shot(95, 30);      // 최소(100us) 미만 -> invalid
        one_shot(40, 30);      // 훨씬 짧음        -> invalid
        one_shot(23000, 30);   // 최대 근처        -> valid
        one_shot(23400, 30);   // 최대(23200us) 초과 -> invalid

        //---------------- 무응답 (센서를 안 꽂았을 때) ----------------
        //  echo 가 계속 Low -> WAIT_RISE 가 30000us 에서 끊고 나온다
        //  (타임아웃이 없으면 여기서 영영 갇힌다)
        w = 0;
        kick;
        wait_done(33000);
        chk(cap_valid === 1'b0, "no-echo reported valid");
        chk(cap_dist === 9'd0,  "no-echo distance not 0");
        repeat (20) @(negedge clk);

        //---------------- echo 가 올라간 뒤 안 내려올 때 ----------------
        //  MEASURE 가 23200us 에서 끊고 나온다. 400cm 로 찍히면 안 된다.
        w = 0;
        kick;
        wait_us(30);
        echo = 1'b1;
        wait_done(25000);
        chk(cap_valid === 1'b0, "never-falling echo reported valid");
        chk(cap_dist === 9'd0,  "never-falling echo distance not 0");
        echo = 1'b0;
        repeat (20) @(negedge clk);

        //---------------- start 전부터 echo 가 High 로 붙어 있을 때 ----------------
        //  상승엣지가 아예 없으므로 WAIT_RISE 타임아웃으로 빠져나와야 한다
        w    = 0;
        echo = 1'b1;
        kick;
        wait_done(33000);
        chk(cap_valid === 1'b0, "stuck-high echo reported valid");
        chk(cap_dist === 9'd0,  "stuck-high distance not 0");
        echo = 1'b0;
        repeat (20) @(negedge clk);

        //---------------- 붙어 있던 뒤에도 다시 정상 동작 ----------------
        one_shot(1740, 40);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_sr04_controller : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_sr04_controller : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #30_000_000;
        $display("  tb_sr04_controller : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
