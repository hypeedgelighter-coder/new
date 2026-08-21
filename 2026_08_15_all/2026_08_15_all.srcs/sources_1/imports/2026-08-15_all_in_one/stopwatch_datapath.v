`timescale 1ns / 1ps

//=====================================================================
// stopwatch_datapath
//   100Hz tick -> msec(0~99) -> sec(0~59) -> min(0~59) -> hour(0~23)
//   mode = 1 이면 다운카운트.
//   기존 stopwatch.v 의 stopwatch_datapath 그대로. tick_gen_100hz /
//   time_counter 는 tick_gen.v 로 옮겨서 시계와 공유한다.
//=====================================================================
module stopwatch_datapath #(
    parameter MSEC_WIDTH = 7,
    parameter SEC_WIDTH  = 6,
    parameter MIN_WIDTH  = 6,
    parameter HOUR_WIDTH = 5,
    parameter TICK_100HZ = 1_000_000  // 시뮬에서 줄여 쓰라고 파라미터로 뺌
) (
    input                   clk,
    input                   reset,
    input                   run_stop,
    input                   clear,
    input                   mode,
    output [MSEC_WIDTH-1:0] msec,
    output [ SEC_WIDTH-1:0] sec,
    output [ MIN_WIDTH-1:0] min,
    output [HOUR_WIDTH-1:0] hour
);
    wire w_tick_100hz;
    wire w_tick_sec, w_tick_min, w_tick_hour;

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
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
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
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
        .up        (1'b0),
        .down      (1'b0),
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
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
        .up        (1'b0),
        .down      (1'b0),
        .time_count(min),
        .o_tick    (w_tick_hour)
    );

    time_counter #(
        .BIT_WIDTH(HOUR_WIDTH),
        .TIMES(24)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_hour),
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
        .up        (1'b0),
        .down      (1'b0),
        .time_count(hour),
        .o_tick    ()
    );

endmodule
