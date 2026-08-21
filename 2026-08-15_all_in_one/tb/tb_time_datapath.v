`timescale 1ns / 1ps

//=====================================================================
// tb_time_datapath  -  time_datapath 단독 무작위 테스트벤치
//
//  대상 : time_datapath.v  (stopwatch_datapath + watch_datapath + 표시 MUX)
//
//  두 데이터패스는 항상 같이 돌고, 밖으로는 mode_sel 로 고른 한 벌만
//  나간다. 스톱워치와 시계 각각의 동작은 tb_stopwatch_datapath /
//  tb_watch_datapath 에서 따로 본다. 여기서 볼 것은
//    "MUX 가 지금 모드에 맞는 쪽을 내보내는가"
//    "고르지 않은 쪽도 뒤에서 계속 제대로 돌고 있는가" 두 가지다.
//
//  [검사 방법]
//    같은 하위 모듈을 테스트벤치에 참조용으로 한 벌씩 더 인스턴스해서
//    똑같은 클럭/리셋/제어를 먹인다. 두 벌은 완전히 같은 클럭에 같은
//    동작을 하므로, DUT 출력은 매 클럭 참조 중 하나와 정확히 같아야 한다.
//      mode_sel == 1(시계)  -> 시계 쪽과 같아야 하고
//      그 외                -> 스톱워치 쪽과 같아야 한다
//    시간차 보정 없이 매 클럭 그대로 비교할 수 있다.
//
//  [무작위로 만드는 것]
//    mode_sel 을 무작위 시점에 무작위로 바꾸고 (모드를 바꿔도 뒤에서
//    돌던 값이 흐트러지면 안 된다), 스톱워치/시계 제어도 전부 무작위로.
//=====================================================================
module tb_time_datapath ();

    localparam integer TICK    = 8;
    localparam integer N_CYCLE = 40000;

    localparam [1:0] MODE_WATCH = 2'd1;

    reg clk = 1'b0;
    reg reset;
    reg [1:0] mode_sel;
    reg sw_run_stop, sw_clear, sw_count_mode;
    reg [1:0] wt_edit_sel;
    reg wt_clear, wt_up, wt_down;

    wire [6:0] msec;
    wire [5:0] sec, min;
    wire [4:0] hour;

    wire [6:0] r_sw_msec, r_wt_msec;
    wire [5:0] r_sw_sec, r_wt_sec;
    wire [5:0] r_sw_min, r_wt_min;
    wire [4:0] r_sw_hour, r_wt_hour;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on;
    reg [6:0] e_msec;
    reg [5:0] e_sec, e_min;
    reg [4:0] e_hour;

    always #5 clk = ~clk;

    time_datapath #(
        .TICK_100HZ(TICK)
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

    //---------------- 참조용으로 같은 하위 모듈을 한 벌 더 ----------------
    stopwatch_datapath #(
        .TICK_100HZ(TICK)
    ) REF_SW (
        .clk     (clk),
        .reset   (reset),
        .run_stop(sw_run_stop),
        .clear   (sw_clear),
        .mode    (sw_count_mode),
        .msec    (r_sw_msec),
        .sec     (r_sw_sec),
        .min     (r_sw_min),
        .hour    (r_sw_hour)
    );

    watch_datapath #(
        .TICK_100HZ(TICK)
    ) REF_WT (
        .clk     (clk),
        .reset   (reset),
        .edit_sel(wt_edit_sel),
        .clear   (wt_clear),
        .up      (wt_up),
        .down    (wt_down),
        .msec    (r_wt_msec),
        .sec     (r_wt_sec),
        .min     (r_wt_min),
        .hour    (r_wt_hour)
    );

    task chk(input cond, input [8*30:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  mode=%0d dut=%02d:%02d:%02d.%02d exp=%02d:%02d:%02d.%02d",
                             $time, tag, mode_sel, hour, min, sec, msec,
                             e_hour, e_min, e_sec, e_msec);
            end
        end
    endtask

    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            if (mode_sel == MODE_WATCH) begin
                e_msec = r_wt_msec; e_sec = r_wt_sec;
                e_min  = r_wt_min;  e_hour = r_wt_hour;
            end else begin
                e_msec = r_sw_msec; e_sec = r_sw_sec;
                e_min  = r_sw_min;  e_hour = r_sw_hour;
            end
            chk(msec === e_msec, "msec : wrong source selected");
            chk(sec  === e_sec,  "sec : wrong source selected");
            chk(min  === e_min,  "min : wrong source selected");
            chk(hour === e_hour, "hour : wrong source selected");
        end
    end

    initial begin
        seed0  = 32'h71_3D0A70;
        seed   = seed0;
        errors = 0;
        checks = 0;

        monitor_on    = 1'b0;
        reset         = 1'b1;
        mode_sel      = 2'd0;
        sw_run_stop   = 1'b0;
        sw_clear      = 1'b0;
        sw_count_mode = 1'b0;
        wt_edit_sel   = 2'd0;
        wt_clear      = 1'b0;
        wt_up         = 1'b0;
        wt_down       = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        // 리셋 직후 : 스톱워치는 0, 시계는 12시
        chk(hour === 5'd0, "stopwatch hour is not 0 after reset");
        mode_sel = MODE_WATCH;
        @(negedge clk);
        chk(hour === 5'd12, "watch hour is not 12 after reset");
        mode_sel = 2'd0;

        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            if (({$random(seed)} % 300) == 0) mode_sel = {$random(seed)} % 4;

            sw_run_stop   = (({$random(seed)} % 200) == 0) ? ~sw_run_stop : sw_run_stop;
            sw_count_mode = (({$random(seed)} % 900) == 0) ? ~sw_count_mode : sw_count_mode;
            sw_clear      = (({$random(seed)} % 1500) == 0);

            wt_edit_sel = (({$random(seed)} % 300) == 0) ? {$random(seed)} % 4
                                                        : wt_edit_sel;
            wt_up    = (({$random(seed)} % 400) == 0);
            wt_down  = (({$random(seed)} % 400) == 0);
            wt_clear = (({$random(seed)} % 1500) == 0);
        end
        @(negedge clk);
        sw_clear = 1'b0; wt_clear = 1'b0; wt_up = 1'b0; wt_down = 1'b0;
        repeat (5) @(negedge clk);

        $display("  stopwatch %02d:%02d:%02d.%02d   watch %02d:%02d:%02d.%02d",
                 r_sw_hour, r_sw_min, r_sw_sec, r_sw_msec,
                 r_wt_hour, r_wt_min, r_wt_sec, r_wt_msec);
        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_time_datapath : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_time_datapath : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #10_000_000;
        $display("  tb_time_datapath : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
