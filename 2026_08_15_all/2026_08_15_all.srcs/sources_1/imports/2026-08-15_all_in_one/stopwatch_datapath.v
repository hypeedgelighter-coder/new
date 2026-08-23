`timescale 1ns / 1ps

//=====================================================================
// stopwatch_datapath
//   100Hz tick -> msec(0~99) -> sec(0~59) -> min(0~59) -> hour(0~23)
//   mode = 1 이면 다운카운트.
//   [기존 대비 바뀐 점]
//   tick_gen_100hz / time_counter 를 tick_gen.v 에 몰아넣고 시계와 공유
//   했었다. 파일 하나가 무관한 모듈 4개를 들고 있어서, 그 파일을 프로젝트
//   에서 빼면 시계가 통째로 무너졌다.
//   -> 이 파일에 필요한 tick 과 카운터를 이 파일 안에 직접 둔다.
//      모듈 이름은 전역이라 시계 쪽 사본과 겹치면 안 된다. sw_ 접두.
//      스톱워치는 up/down 편집을 안 쓰므로 그 포트는 뺐다.
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

    sw_tick_100hz #(
        .F_COUNT(TICK_100HZ)
    ) U_TICK_GEN_100HZ (
        .clk   (clk),
        .reset (reset),
        .o_tick(w_tick_100hz)
    );

    sw_time_counter #(
        .BIT_WIDTH(MSEC_WIDTH),
        .TIMES(100)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_100hz),
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
        .time_count(msec),
        .o_tick    (w_tick_sec)
    );

    sw_time_counter #(
        .BIT_WIDTH(SEC_WIDTH),
        .TIMES(60)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_sec),
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
        .time_count(sec),
        .o_tick    (w_tick_min)
    );

    sw_time_counter #(
        .BIT_WIDTH(MIN_WIDTH),
        .TIMES(60)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_min),
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
        .time_count(min),
        .o_tick    (w_tick_hour)
    );

    sw_time_counter #(
        .BIT_WIDTH(HOUR_WIDTH),
        .TIMES(24)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_hour),
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
        .time_count(hour),
        .o_tick    ()
    );

endmodule


//---------------------------------------------------------------------
// stopwatch_datapath 전용 100Hz(10ms) tick.
//---------------------------------------------------------------------
module sw_tick_100hz #(
    parameter F_COUNT = 1_000_000  // 100MHz -> 100Hz
) (
    input      clk,
    input      reset,
    output reg o_tick
);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else begin
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                o_tick      <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                o_tick      <= 1'b0;
            end
        end
    end
endmodule


//---------------------------------------------------------------------
// stopwatch_datapath 전용 자리 카운터.
//   mode   : 0 = 업카운트, 1 = 다운카운트
//   o_tick : 자리올림(넘침) 펄스 -> 상위 자리의 i_tick 으로 연결
//   시계용 사본(wt_time_counter)과 달리 up/down 편집 포트가 없다.
//---------------------------------------------------------------------
module sw_time_counter #(
    parameter BIT_WIDTH = 7,
    parameter TIMES     = 100
) (
    input                  clk,
    input                  reset,
    input                  i_tick,
    input                  mode,
    input                  clear,
    input                  run_stop,
    output [BIT_WIDTH-1:0] time_count,
    output reg             o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;
    assign time_count = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else if (clear) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else if (run_stop && i_tick) begin
            if (!mode) begin
                if (counter_reg == (TIMES - 1)) begin
                    counter_reg <= 0;
                    o_tick      <= 1'b1;
                end else begin
                    counter_reg <= counter_reg + 1;
                    o_tick      <= 1'b0;
                end
            end else begin
                if (counter_reg == 0) begin
                    counter_reg <= (TIMES - 1);
                    o_tick      <= 1'b1;
                end else begin
                    counter_reg <= counter_reg - 1;
                    o_tick      <= 1'b0;
                end
            end
        end else begin
            o_tick <= 1'b0;
        end
    end
endmodule
