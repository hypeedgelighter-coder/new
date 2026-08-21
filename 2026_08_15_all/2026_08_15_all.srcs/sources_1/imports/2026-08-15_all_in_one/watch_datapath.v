`timescale 1ns / 1ps

//=====================================================================
// watch_datapath
//   항상 돌아가는 시계. edit_sel 로 고른 자리를 up/down 펄스로 조정한다.
//   hour 는 INIT_VAL=12 로 시작.
//
//  [기존 대비 바뀐 점]
//   w_tick_sec / w_tick_min / w_tick_hour 가 선언 없이 쓰여서 암시적
//   1비트 wire 로 만들어지고 있었다. 명시적으로 선언했다.
//   (동작은 같지만 Vivado 가 경고를 뿜고, 오타가 나도 안 잡힌다)
//=====================================================================
module watch_datapath #(
    parameter MSEC_WIDTH = 7,
    parameter SEC_WIDTH  = 6,
    parameter MIN_WIDTH  = 6,
    parameter HOUR_WIDTH = 5,
    parameter TICK_100HZ = 1_000_000  // 시뮬에서 줄여 쓰라고 파라미터로 뺌
) (
    input                   clk,
    input                   reset,
    input       [      1:0] edit_sel,  // 0=sec, 1=min, 2=hour
    input                   clear,
    input                   up,
    input                   down,
    output [MSEC_WIDTH-1:0] msec,
    output [ SEC_WIDTH-1:0] sec,
    output [ MIN_WIDTH-1:0] min,
    output [HOUR_WIDTH-1:0] hour
);
    wire w_tick_100hz;
    wire w_tick_sec, w_tick_min, w_tick_hour;

    wire sec_up    = up   && (edit_sel == 2'b00);
    wire min_up    = up   && (edit_sel == 2'b01);
    wire hour_up   = up   && (edit_sel == 2'b10);
    wire sec_down  = down && (edit_sel == 2'b00);
    wire min_down  = down && (edit_sel == 2'b01);
    wire hour_down = down && (edit_sel == 2'b10);

    tick_gen_100hz #(
        .F_COUNT(TICK_100HZ)
    ) U_TICK_GEN_100HZ (
        .clk   (clk),
        .reset (reset),
        .o_tick(w_tick_100hz)
    );

    time_counter #(
        .BIT_WIDTH(MSEC_WIDTH),
        .TIMES(100)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_100hz),
        .mode      (1'b0),
        .clear     (clear),
        .run_stop  (1'b1),
        .up        (1'b0),
        .down      (1'b0),
        .time_count(msec),
        .o_tick    (w_tick_sec)
    );

    time_counter #(
        .BIT_WIDTH(SEC_WIDTH),
        .TIMES(60)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_sec),
        .mode      (1'b0),
        .clear     (clear),
        .run_stop  (1'b1),
        .up        (sec_up),
        .down      (sec_down),
        .time_count(sec),
        .o_tick    (w_tick_min)
    );

    time_counter #(
        .BIT_WIDTH(MIN_WIDTH),
        .TIMES(60)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_min),
        .mode      (1'b0),
        .clear     (clear),
        .run_stop  (1'b1),
        .up        (min_up),
        .down      (min_down),
        .time_count(min),
        .o_tick    (w_tick_hour)
    );

    time_counter #(
        .BIT_WIDTH(HOUR_WIDTH),
        .TIMES(24),
        .INIT_VAL(12)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_hour),
        .mode      (1'b0),
        .clear     (clear),
        .run_stop  (1'b1),
        .up        (hour_up),
        .down      (hour_down),
        .time_count(hour),
        .o_tick    ()
    );

endmodule
