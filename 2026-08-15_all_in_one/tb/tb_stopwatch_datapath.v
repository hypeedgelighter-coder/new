`timescale 1ns / 1ps

//=====================================================================
// tb_stopwatch_datapath  -  stopwatch_datapath 단독 무작위 테스트벤치
//
//  대상 : stopwatch_datapath.v
//         100Hz tick -> msec(0~99) -> sec(0~59) -> min(0~59) -> hour(0~23)
//         mode=1 이면 다운카운트
//
//  시뮬에서는 TICK_100HZ 를 12 로 줄여 12클럭마다 한 칸 오른다.
//
//  [자리올림에 시간차가 있다]
//    RTL 은 time_counter 를 4단으로 이어 붙였고, 각 단의 자리올림
//    (o_tick) 이 레지스터를 한 번 거친다. 그래서 msec 이 99->0 이 된
//    클럭과 sec 이 오르는 클럭이 한 클럭 차이난다 (hour 까지면 3클럭).
//    그래서 tick 이 지나고 6클럭 뒤, 즉 전파가 다 끝난 시점에만 비교한다.
//    제어 입력도 그 시점에만 바꾼다.
//
//  [무작위로 만드는 것]
//    tick 한 칸마다 run_stop / clear / mode 를 무작위로 바꾼다.
//
//  [검사]
//    1) 참조 모델(자리올림을 한 번에 처리하는 4단 카운터)과 비교
//    2) 자리올림 전수 : 0 에서 다운카운트 한 번 -> 23:59:59.99 로 한 번에
//       내려가야 하고, 거기서 업카운트 한 번 -> 00:00:00.00 으로 돌아와야
//       한다. 네 자리 자리올림/빌림이 한 번에 다 걸린다.
//=====================================================================
module tb_stopwatch_datapath ();

    localparam integer TICK    = 12;   // "10ms" = 12클럭
    localparam integer SETTLE  = 6;    // 자리올림 전파를 기다리는 클럭
    localparam integer N_STEP  = 3000; // 무작위 구간의 tick 수
    localparam integer N_LONG  = 6400; // sec -> min 자리올림까지 가는 연속 구간

    reg clk = 1'b0;
    reg reset;
    reg run_stop, clear, mode;

    wire [6:0] msec;
    wire [5:0] sec, min;
    wire [4:0] hour;

    wire ref_tick;

    integer m_ms, m_s, m_mi, m_h;  // 참조 모델

    integer seed, seed0;
    integer errors, checks;
    integer i;

    always #5 clk = ~clk;

    stopwatch_datapath #(
        .TICK_100HZ(TICK)
    ) DUT (
        .clk     (clk),
        .reset   (reset),
        .run_stop(run_stop),
        .clear   (clear),
        .mode    (mode),
        .msec    (msec),
        .sec     (sec),
        .min     (min),
        .hour    (hour)
    );

    // DUT 안의 것과 똑같은 조건에서 도는 참조 tick (같은 클럭/리셋/분주비)
    tick_gen_100hz #(
        .F_COUNT(TICK)
    ) REF_TICK (
        .clk   (clk),
        .reset (reset),
        .o_tick(ref_tick)
    );

    task chk(input cond, input [8*30:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  dut=%02d:%02d:%02d.%02d  ref=%02d:%02d:%02d.%02d",
                             $time, tag, hour, min, sec, msec, m_h, m_mi, m_s, m_ms);
            end
        end
    endtask

    //---------------- 참조 모델 (자리올림을 한 클럭에 처리) ----------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            m_ms <= 0; m_s <= 0; m_mi <= 0; m_h <= 0;
        end else if (clear) begin
            m_ms <= 0; m_s <= 0; m_mi <= 0; m_h <= 0;
        end else if (run_stop && ref_tick) begin
            if (!mode) begin  // 업카운트
                if (m_ms == 99) begin
                    m_ms <= 0;
                    if (m_s == 59) begin
                        m_s <= 0;
                        if (m_mi == 59) begin
                            m_mi <= 0;
                            m_h  <= (m_h == 23) ? 0 : m_h + 1;
                        end else m_mi <= m_mi + 1;
                    end else m_s <= m_s + 1;
                end else m_ms <= m_ms + 1;
            end else begin    // 다운카운트
                if (m_ms == 0) begin
                    m_ms <= 99;
                    if (m_s == 0) begin
                        m_s <= 59;
                        if (m_mi == 0) begin
                            m_mi <= 59;
                            m_h  <= (m_h == 0) ? 23 : m_h - 1;
                        end else m_mi <= m_mi - 1;
                    end else m_s <= m_s - 1;
                end else m_ms <= m_ms - 1;
            end
        end
    end

    // tick 한 칸을 넘긴 뒤 자리올림 전파가 끝날 때까지 기다린다
    task step;
        begin
            @(negedge clk);
            while (ref_tick !== 1'b1) @(negedge clk);
            repeat (SETTLE) @(negedge clk);
        end
    endtask

    task compare;
        begin
            chk(msec === m_ms[6:0], "msec mismatch");
            chk(sec  === m_s[5:0],  "sec mismatch");
            chk(min  === m_mi[5:0], "min mismatch");
            chk(hour === m_h[4:0],  "hour mismatch");
        end
    endtask

    task do_clear;  // 1클럭 폭 clear (전파가 끝난 시점에만 준다)
        begin
            clear = 1'b1;
            @(negedge clk);
            clear = 1'b0;
        end
    endtask

    initial begin
        seed0  = 32'h57_0FA711;
        seed   = seed0;
        errors = 0;
        checks = 0;

        reset    = 1'b1;
        run_stop = 1'b0;
        clear    = 1'b0;
        mode     = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);

        compare;
        chk(msec === 7'd0 && sec === 6'd0 && min === 6'd0 && hour === 5'd0,
            "not zero after reset");

        //---------------- 1) 자리올림 전수 (다운 -> 업) ----------------
        run_stop = 1'b1;
        mode     = 1'b1;   // 다운카운트
        step;              // 0 에서 한 칸 내리면 23:59:59.99
        compare;
        chk(hour === 5'd23 && min === 6'd59 && sec === 6'd59 && msec === 7'd99,
            "borrow chain from zero failed");

        mode = 1'b0;       // 업카운트
        step;              // 다시 한 칸 올리면 00:00:00.00
        compare;
        chk(hour === 5'd0 && min === 6'd0 && sec === 6'd0 && msec === 7'd0,
            "carry chain to zero failed");

        //---------------- 2) 무작위 run/stop/clear/mode ----------------
        for (i = 0; i < N_STEP; i = i + 1) begin
            step;
            compare;
            // tick 사이 (전파가 끝난 뒤) 에만 제어를 바꾼다
            run_stop = (({$random(seed)} % 4) != 0);   // 3/4 확률로 동작
            if (({$random(seed)} % 30) == 0) mode = ~mode;
            if (({$random(seed)} % 60) == 0) do_clear;
        end

        //---------------- 3) 길게 연속으로 돌려 sec -> min 넘기기 ----------------
        do_clear;
        run_stop = 1'b1;
        mode     = 1'b0;
        for (i = 0; i < N_LONG; i = i + 1) begin
            step;
            compare;
        end
        chk(min > 0, "min never advanced in the long run");
        $display("  long run reached %02d:%02d:%02d.%02d", hour, min, sec, msec);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_stopwatch_datapath : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_stopwatch_datapath : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #20_000_000;
        $display("  tb_stopwatch_datapath : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
