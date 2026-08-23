`timescale 1ns / 1ps

//=====================================================================
// watch_datapath
//   항상 돌아가는 시계. edit_sel 로 고른 자리를 up/down 펄스로 조정한다.
//   hour 는 INIT_VAL=12 로 시작.
//
//  [기존 대비 바뀐 점]
//   1) w_tick_sec / w_tick_min / w_tick_hour 가 선언 없이 쓰여서 암시적
//      1비트 wire 로 만들어지고 있었다. 명시적으로 선언했다.
//      (동작은 같지만 Vivado 가 경고를 뿜고, 오타가 나도 안 잡힌다)
//   2) tick_gen_100hz / time_counter 를 tick_gen.v 에서 스톱워치와 공유
//      했었다. 이제 이 파일 안에 직접 둔다. 모듈 이름은 전역이라 스톱워치
//      쪽 사본과 겹치면 안 되므로 wt_ 접두를 붙였다.
//      시계는 항상 돌고(run_stop 고정 1) 업카운트만 하므로(mode 고정 0)
//      그 두 포트는 뺐다. 대신 편집용 up/down 은 유지.
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

    wt_tick_100hz #(
        .F_COUNT(TICK_100HZ)
    ) U_TICK_GEN_100HZ (
        .clk   (clk),
        .reset (reset),
        .o_tick(w_tick_100hz)
    );

    wt_time_counter #(
        .BIT_WIDTH(MSEC_WIDTH),
        .TIMES(100)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_100hz),
        .clear     (clear),
        .up        (1'b0),
        .down      (1'b0),
        .time_count(msec),
        .o_tick    (w_tick_sec)
    );

    wt_time_counter #(
        .BIT_WIDTH(SEC_WIDTH),
        .TIMES(60)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_sec),
        .clear     (clear),
        .up        (sec_up),
        .down      (sec_down),
        .time_count(sec),
        .o_tick    (w_tick_min)
    );

    wt_time_counter #(
        .BIT_WIDTH(MIN_WIDTH),
        .TIMES(60)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_min),
        .clear     (clear),
        .up        (min_up),
        .down      (min_down),
        .time_count(min),
        .o_tick    (w_tick_hour)
    );

    wt_time_counter #(
        .BIT_WIDTH(HOUR_WIDTH),
        .TIMES(24),
        .INIT_VAL(12)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_hour),
        .clear     (clear),
        .up        (hour_up),
        .down      (hour_down),
        .time_count(hour),
        .o_tick    ()
    );

endmodule


//---------------------------------------------------------------------
// watch_datapath 전용 100Hz(10ms) tick.
//---------------------------------------------------------------------
module wt_tick_100hz #(
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
// watch_datapath 전용 자리 카운터.
//   항상 업카운트로 돌아간다 (스톱워치와 달리 mode / run_stop 없음).
//   up/down : 편집용 1클럭 펄스. i_tick 과 무관하게 즉시 +1 / -1 하고,
//             자리올림(o_tick)은 내지 않는다.
//   INIT_VAL : reset/clear 시 복귀값. 시(hour)를 12 로 시작시킬 때 쓴다.
//---------------------------------------------------------------------
module wt_time_counter #(
    parameter BIT_WIDTH = 7,
    parameter TIMES     = 100,
    parameter INIT_VAL  = 0
) (
    input                  clk,
    input                  reset,
    input                  i_tick,
    input                  clear,
    input                  up,
    input                  down,
    output [BIT_WIDTH-1:0] time_count,
    output reg             o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;
    assign time_count = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= INIT_VAL;
            o_tick      <= 1'b0;
        end else if (clear) begin
            counter_reg <= INIT_VAL;
            o_tick      <= 1'b0;
        end else if (up | down) begin
            if (up) counter_reg <= (counter_reg == (TIMES - 1)) ? 0 : counter_reg + 1;
            else counter_reg <= (counter_reg == 0) ? (TIMES - 1) : counter_reg - 1;
            o_tick <= 1'b0;
        end else if (i_tick) begin
            if (counter_reg == (TIMES - 1)) begin
                counter_reg <= 0;
                o_tick      <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                o_tick      <= 1'b0;
            end
        end else begin
            o_tick <= 1'b0;
        end
    end
endmodule
