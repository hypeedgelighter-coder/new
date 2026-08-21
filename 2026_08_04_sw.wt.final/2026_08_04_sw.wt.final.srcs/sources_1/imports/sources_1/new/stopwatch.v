`timescale 1ns / 1ps

module top_stopwatch (
    input clk,
    input reset,
    input btn_L,
    input btn_R,
    input btn_U,
    input btn_D,
    input btn_C,
    input [1:0] sw,
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output [1:0] led
);
    assign led = 2'b11;

    wire w_btn_runstop, w_btn_clear, w_btn_mode, w_btn_down, w_btn_C;
    wire w_run_stop, w_clear, w_mode;
    wire w_up, w_down;
    wire [1:0] w_edit_sel;
    wire w_watch_clear;

    wire [6:0] sw_msec, wt_msec;
    wire [5:0] sw_sec,  wt_sec;
    wire [5:0] sw_min,  wt_min;
    wire [4:0] sw_hour, wt_hour;

    wire [6:0] msec;
    wire [5:0] sec;
    wire [5:0] min;
    wire [4:0] hour;

    // sw[1]로 버튼을 stopwatch용/watch용으로 게이팅
    wire btn_L_sw = w_btn_runstop & ~sw[1];
    wire btn_R_sw = w_btn_clear   & ~sw[1];
    wire btn_U_sw = w_btn_mode    & ~sw[1];

    wire btn_L_wt = w_btn_runstop & sw[1];
    wire btn_R_wt = w_btn_clear   & sw[1];
    wire btn_U_wt = w_btn_mode    & sw[1];
    wire btn_D_wt = w_btn_down    & sw[1];
    wire btn_C_wt = w_btn_C       & sw[1];

    ////--------------------------------STOP_WATCH----------------------------
    control_unit_stopwatch U_CONTROL_UNIT_STOPWATCH (
        .clk(clk),
        .reset(reset),
        .i_run_stop(btn_L_sw),
        .i_clear(btn_R_sw),
        .i_mode(btn_U_sw),
        .o_run_stop(w_run_stop),
        .o_clear(w_clear),
        .o_mode(w_mode)
    );

    btn_debounce U_BD_RUNSTOP (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_L),
        .o_btn(w_btn_runstop)
    );
    btn_debounce U_BD_CLEAR (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_R),
        .o_btn(w_btn_clear)
    );
    btn_debounce U_BD_MODE (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_U),
        .o_btn(w_btn_mode)
    );
    btn_debounce U_BD_DOWN (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_D),
        .o_btn(w_btn_down)
    );
    btn_debounce U_BD_C (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_C),
        .o_btn(w_btn_C)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .run_stop(w_run_stop),
        .clear(w_clear),
        .mode(w_mode),
        .msec(sw_msec),
        .sec(sw_sec),
        .min(sw_min),
        .hour(sw_hour)
    );

    //------------------------WATCH-------------------------------------
    watch_datapath U_WATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .edit_sel(w_edit_sel),
        .clear(w_watch_clear),
        .up(w_up),
        .down(w_down),
        .msec(wt_msec),
        .sec(wt_sec),
        .min(wt_min),
        .hour(wt_hour)
    );
    control_unit_watch U_CONTROL_UNIT_WATCH (
        .clk(clk),
        .reset(reset),
        .btn_L(btn_L_wt),
        .btn_R(btn_R_wt),
        .btn_U(btn_U_wt),
        .btn_D(btn_D_wt),
        .btn_C(btn_C_wt),
        .edit_sel(w_edit_sel),
        .o_clear(w_watch_clear),
        .o_up(w_up),
        .o_down(w_down)
    );
    assign msec = sw[1] ? wt_msec : sw_msec;
    assign sec  = sw[1] ? wt_sec  : sw_sec;
    assign min  = sw[1] ? wt_min  : sw_min;
    assign hour = sw[1] ? wt_hour : sw_hour;

    fnd_controller U_FND_CONTROLLER (
        .clk(clk),
        .reset(reset),
        .msec(msec),
        .sec(sec),
        .min(min),
        .hour(hour),
        .display_mode(sw[0]),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

endmodule
//--------------------------------------------------------------------------------


module watch_datapath #(
    parameter MSEC_WIDTH = 7,
    parameter SEC_WIDTH  = 6,
    parameter MIN_WIDTH  = 6,
    parameter HOUR_WIDTH = 5
)(
    input clk,
    input reset,
    input [1:0] edit_sel,
    input clear,
    input up,
    input down,

    output [MSEC_WIDTH-1:0] msec,
    output [SEC_WIDTH-1:0]  sec,
    output [MIN_WIDTH-1:0]  min,
    output [HOUR_WIDTH-1:0] hour
);
    wire w_tick_100hz;
    wire sec_up = (up)&&(edit_sel == 2'b00);
    wire min_up = (up)&&(edit_sel == 2'b01);
    wire hour_up = (up)&&(edit_sel == 2'b10);
    wire sec_down = (down)&&(edit_sel == 2'b00);
    wire min_down = (down)&&(edit_sel == 2'b01);
    wire hour_down = (down)&&(edit_sel == 2'b10);

    tick_gen_100hz CLK_TICK_GEN100HZ (
        .clk   (clk),
        .reset (reset),
        .o_tick(w_tick_100hz)
    );

    time_counter #(
        .BIT_WIDTH(MSEC_WIDTH),
        .TIMES(100)
    ) U_MSEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .mode(1'b0),
        .clear(clear),
        .run_stop(1'b1),
        .time_count(msec),
        .o_tick(w_tick_sec),
        .up(1'b0),
        .down(1'b0)

    );

    time_counter #(
        .BIT_WIDTH(SEC_WIDTH),
        .TIMES(60)
    ) U_SEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_sec),
        .mode(1'b0),
        .clear(clear),
        .run_stop(1'b1),
        .time_count(sec),
        .o_tick(w_tick_min),
        .up(sec_up),
        .down(sec_down)
    );

    time_counter #(
        .BIT_WIDTH(MIN_WIDTH),
        .TIMES(60)
    ) U_MIN_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_min),
        .mode(1'b0),
        .clear(clear),
        .run_stop(1'b1),
        .time_count(min),
        .o_tick(w_tick_hour),
        .up(min_up),
        .down(min_down)
    );


    time_counter #(
        .BIT_WIDTH(HOUR_WIDTH),
        .TIMES(24),
        .INIT_VAL(12)
    ) U_HOUR_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_hour),
        .mode(1'b0),
        .clear(clear),
        .run_stop(1'b1),
        .time_count(hour),
        .up(hour_up),
        .down(hour_down),
        .o_tick()

    );



endmodule


module stopwatch_datapath #(
    parameter MSEC_WIDTH = 7,
    parameter SEC_WIDTH  = 6,
    parameter MIN_WIDTH  = 6,
    parameter HOUR_WIDTH = 5
) (
    input clk,
    input reset,
    input run_stop,
    input clear,
    input mode,
    // input option,
    output [MSEC_WIDTH-1:0] msec,
    output [SEC_WIDTH-1:0] sec,
    output [MIN_WIDTH-1:0] min,
    output [HOUR_WIDTH-1:0] hour

);
    wire w_tick_100hz;
    wire w_tick_sec, w_tick_min, w_tick_hour;

    tick_gen_100hz CLK_TICK_GEN100HZ (
        .clk   (clk),
        .reset (reset),
        .o_tick(w_tick_100hz)
    );

    time_counter #(
        .BIT_WIDTH(MSEC_WIDTH),
        .TIMES(100)
    ) U_MSEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .time_count(msec),
        .o_tick(w_tick_sec),
        .up(1'b0),
        .down(1'b0)
    );

    time_counter #(
        .BIT_WIDTH(SEC_WIDTH),
        .TIMES(60)
    ) U_SEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_sec),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .time_count(sec),
        .o_tick(w_tick_min),
        .up(1'b0),
        .down(1'b0)
    );

    time_counter #(
        .BIT_WIDTH(MIN_WIDTH),
        .TIMES(60)
    ) U_MIN_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_min),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .time_count(min),
        .o_tick(w_tick_hour),
        .up(1'b0),
        .down(1'b0)
    );


    time_counter #(
        .BIT_WIDTH(HOUR_WIDTH),
        .TIMES(24)
    ) U_HOUR_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_hour),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .time_count(hour),
        .up(1'b0),
        .down(1'b0),
        .o_tick()
    );

endmodule