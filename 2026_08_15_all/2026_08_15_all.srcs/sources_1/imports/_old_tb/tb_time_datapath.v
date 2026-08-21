`timescale 1ns / 1ps

//=====================================================================
// tb_time_datapath  -  스톱워치 + 시계 데이터패스 묶음 검증
//
//  시뮬에서는 TICK_100HZ 를 4 로 줄여서 msec 이 4클럭마다 오른다.
//
//  검사 항목
//   1) 스톱워치 : run_stop / clear / 업다운 카운트
//   2) 시계     : 항상 동작, hour 초기값 12, 편집 자리별 up/down
//   3) mode_sel 로 출력이 스톱워치/시계로 바뀌는가
//=====================================================================
module tb_time_datapath ();

    localparam integer P_TICK = 4;  // msec 1칸 = 4클럭

    reg clk, reset;
    reg [1:0] mode_sel;
    reg sw_run_stop, sw_clear, sw_count_mode;
    reg [1:0] wt_edit_sel;
    reg wt_clear, wt_up, wt_down;

    wire [6:0] msec;
    wire [5:0] sec, min;
    wire [4:0] hour;

    integer err;
    reg [6:0] v_msec;
    reg [5:0] v_min;

    time_datapath #(
        .TICK_100HZ(P_TICK)
    ) DUT (
        .clk          (clk),
        .reset        (reset),
        .mode_sel     (mode_sel),
        .sw_run_stop  (sw_run_stop),
        .sw_clear     (sw_clear),
        .sw_count_mode(sw_count_mode),
        .wt_edit_sel  (wt_edit_sel),
        .wt_clear     (wt_clear),
        .wt_up        (wt_up),
        .wt_down      (wt_down),
        .msec         (msec),
        .sec          (sec),
        .min          (min),
        .hour         (hour)
    );

    always #5 clk = ~clk;

    task ok(input cond);
        begin
            if (cond) $write("  OK   : ");
            else begin
                $write("  FAIL : (%0d:%0d:%0d.%0d) ", hour, min, sec, msec);
                err = err + 1;
            end
        end
    endtask

    // 1클럭 폭 펄스. 자극은 항상 "엣지 + 1ns" 에 준다. 엣지와 같은 시각에
    // 값을 바꾸면 DUT 가 그 엣지에서 볼지 다음 엣지에서 볼지가 시뮬레이터
    // 실행 순서에 달려서, 한 번 준 펄스가 두 번 먹기도 한다.
    task pulse_clear;
        begin
            @(posedge clk);
            #1;
            sw_clear = 1'b1;
            wt_clear = 1'b1;
            @(posedge clk);
            #1;
            sw_clear = 1'b0;
            wt_clear = 1'b0;
            repeat (3) @(posedge clk);
        end
    endtask

    task pulse_up;
        begin
            @(posedge clk);
            #1;
            wt_up = 1'b1;
            @(posedge clk);
            #1;
            wt_up = 1'b0;
            repeat (3) @(posedge clk);
        end
    endtask

    task pulse_down;
        begin
            @(posedge clk);
            #1;
            wt_down = 1'b1;
            @(posedge clk);
            #1;
            wt_down = 1'b0;
            repeat (3) @(posedge clk);
        end
    endtask

    initial begin
        clk           = 1'b0;
        reset         = 1'b1;
        mode_sel      = 2'd0;
        sw_run_stop   = 1'b0;
        sw_clear      = 1'b0;
        sw_count_mode = 1'b0;
        wt_edit_sel   = 2'd0;
        wt_clear      = 1'b0;
        wt_up         = 1'b0;
        wt_down       = 1'b0;
        err           = 0;

        repeat (10) @(posedge clk);
        reset = 1'b0;
        repeat (10) @(posedge clk);

        $display("\n===== tb_time_datapath =====");

        //================= 스톱워치 =================
        $display("\n[1] 스톱워치 : run_stop=0 이면 멈춰 있는가");
        ok(msec === 7'd0); $display("리셋 직후 msec=0");
        repeat (200) @(posedge clk);
        ok(msec === 7'd0); $display("run_stop=0 이면 200클럭 지나도 그대로");

        $display("\n[2] 스톱워치 : run_stop=1 이면 올라가는가");
        sw_run_stop = 1'b1;
        repeat (40) @(posedge clk);  // 10 tick
        ok(msec > 7'd0); $display("run_stop=1 이면 msec 증가");

        $display("\n[3] 스톱워치 : 멈추면 값이 유지되는가");
        sw_run_stop = 1'b0;
        repeat (5) @(posedge clk);
        v_msec = msec;
        repeat (200) @(posedge clk);
        ok(msec === v_msec); $display("정지 중에는 값 유지");

        $display("\n[4] 스톱워치 : clear 로 0 이 되는가");
        pulse_clear;
        ok(msec === 7'd0 && sec === 6'd0); $display("clear -> msec/sec = 0");

        $display("\n[5] 스톱워치 : 다운카운트");
        sw_count_mode = 1'b1;
        sw_run_stop   = 1'b1;
        repeat (40) @(posedge clk);  // 0 에서 아래로 -> 큰 값으로 되감김
        ok(msec > 7'd50); $display("다운카운트면 0 에서 90 대로 내려감");
        sw_run_stop   = 1'b0;
        sw_count_mode = 1'b0;
        pulse_clear;

        //================= 시계 =================
        $display("\n[6] mode_sel=1 이면 출력이 시계로 바뀌는가");
        mode_sel = 2'd1;
        repeat (5) @(posedge clk);
        ok(hour === 5'd12); $display("시계 hour 초기값 12 가 보인다");

        $display("\n[7] 시계 : 편집 자리별 up/down");
        wt_edit_sel = 2'd1;  // min
        repeat (3) @(posedge clk);
        v_min = min;
        pulse_up;
        ok(min === (v_min + 6'd1)); $display("edit_sel=min 에서 up -> min +1");

        v_min = min;
        wt_edit_sel = 2'd2;  // hour
        repeat (3) @(posedge clk);
        pulse_up;
        ok(min === v_min); $display("edit_sel=hour 일 때 up 은 min 을 건드리지 않음");
        ok(hour === 5'd13); $display("hour 12 -> 13");
        pulse_down;
        pulse_down;
        ok(hour === 5'd11); $display("hour 13 -> 11 (down 2회)");

        $display("\n[8] 시계 : clear 로 초기값 복귀");
        pulse_clear;
        ok(hour === 5'd12 && min === 6'd0); $display("clear -> 12:00");

        //================= 선택 MUX =================
        $display("\n[9] mode_sel 로 두 데이터패스가 갈리는가");
        mode_sel = 2'd0;
        repeat (3) @(posedge clk);
        ok(hour === 5'd0); $display("mode_sel=0 -> 스톱워치 hour(0) 가 보인다");
        mode_sel = 2'd1;
        repeat (3) @(posedge clk);
        ok(hour === 5'd12); $display("mode_sel=1 -> 시계 hour(12) 가 보인다");
        mode_sel = 2'd2;
        repeat (3) @(posedge clk);
        ok(hour === 5'd0); $display("센서 모드(2) -> 스톱워치 쪽이 보인다");

        if (err == 0) $display("\n===== tb_time_datapath : ALL PASS =====\n");
        else $display("\n===== tb_time_datapath : %0d FAIL =====\n", err);
        $finish;
    end

endmodule
