`timescale 1ns / 1ps

//=====================================================================
// time_datapath  -  스톱워치 + 시계 데이터패스 한 덩어리
//
//   [stopwatch_datapath] --+
//                          +--> (mode_sel 로 선택) --> msec/sec/min/hour
//   [watch_datapath]     --+
//
//  두 데이터패스는 항상 같이 돌고, 밖에서는 "지금 표시할 시간" 하나만
//  쓴다. (FND 와 UART 송신이 같은 값을 본다) 그래서 선택 MUX 까지
//  여기 넣어서 출력 한 벌만 내보낸다. top 에 sw_*/wt_* 두 벌이
//  늘어져 있던 것이 사라진다.
//
//  두 하위 모듈의 동작은 건드리지 않았다.
//=====================================================================
module time_datapath #(
    parameter TICK_100HZ = 1_000_000   // 10ms (100MHz 기준)
) (
    input clk,
    input reset,

    input [1:0] mode_sel,        // MODE_WATCH 면 시계, 그 외는 스톱워치 값

    // 스톱워치 제어 (Control Unit 에서)
    input sw_run_stop,
    input sw_clear,
    input sw_count_mode,

    // 시계 제어 (Control Unit 에서)
    input [1:0] wt_edit_sel,
    input       wt_clear,
    input       wt_up,
    input       wt_down,

    // 선택된 표시값
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    localparam MODE_WATCH = 2'd1;

    wire [6:0] sw_msec, wt_msec;
    wire [5:0] sw_sec, wt_sec;
    wire [5:0] sw_min, wt_min;
    wire [4:0] sw_hour, wt_hour;

    stopwatch_datapath #(
        .TICK_100HZ(TICK_100HZ)
    ) U_STOPWATCH_DATAPATH (
        .clk     (clk),
        .reset   (reset),
        .run_stop(sw_run_stop),
        .clear   (sw_clear),
        .mode    (sw_count_mode),
        .msec    (sw_msec),
        .sec     (sw_sec),
        .min     (sw_min),
        .hour    (sw_hour)
    );

    watch_datapath #(
        .TICK_100HZ(TICK_100HZ)
    ) U_WATCH_DATAPATH (
        .clk     (clk),
        .reset   (reset),
        .edit_sel(wt_edit_sel),
        .clear   (wt_clear),
        .up      (wt_up),
        .down    (wt_down),
        .msec    (wt_msec),
        .sec     (wt_sec),
        .min     (wt_min),
        .hour    (wt_hour)
    );

    // 표시할 쪽 선택. 센서 모드(SR04/DHT11)일 때는 어차피 FND 가 센서값을
    // 띄우므로 스톱워치 쪽을 그냥 내보낸다 (기존과 동일).
    assign msec = (mode_sel == MODE_WATCH) ? wt_msec : sw_msec;
    assign sec  = (mode_sel == MODE_WATCH) ? wt_sec  : sw_sec;
    assign min  = (mode_sel == MODE_WATCH) ? wt_min  : sw_min;
    assign hour = (mode_sel == MODE_WATCH) ? wt_hour : sw_hour;

endmodule
