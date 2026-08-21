`timescale 1ns / 1ps

module top_watch (
    input clk,
    input reset,
    input [1:0] sw,
    input btn_L,
    input btn_R,
    input btn_U,
    input btn_D,
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output [1:0] led
);
    assign led = 2'b11;

    wire [6:0] w_msec;
    wire [5:0] w_sec;
    wire [5:0] w_min;
    wire [4:0] w_hour;
    wire w_btn_L, w_btn_R, w_btn_U;
    wire w_run_stop, w_clear, w_mode;

    btn_debounce U_BTN_DEBOUNCE_L (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_L),
        .o_btn(w_btn_L)
    );
    btn_debounce U_BTN_DEBOUNCE_R (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_R),
        .o_btn(w_btn_R)
    );
    btn_debounce U_BTN_DEBOUNCE_U (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_U),
        .o_btn(w_btn_U)
    );
    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .reset(reset),
        .i_run_stop(w_btn_L),
        .i_clear(w_btn_R),
        .i_mode(w_btn_U),
        .o_run_stop(w_run_stop),
        .o_clear(w_clear),
        .o_mode(w_mode)
    );
    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .run_stop(w_run_stop),
        .clear(w_clear),
        .mode(w_mode),
        .msec(w_msec),
        .sec(w_sec),
        .min(w_min),
        .hour(w_hour)
    );
    fnd_controller U_fnd_controller (
        .clk(clk),  // from external
        .reset(reset),
        .msec(w_msec),
        .sec(w_sec),
        .min(w_min),
        .hour(w_hour),
        .display_mode(sw[0]),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );
endmodule




module stopwatch_datapath #(

    parameter MSEC_WIDTH = 7,
    SEC_WIDTH = 6,
    MIN_WIDTH = 6,
    HOUR_WIDTH = 5
) (
    input clk,
    input reset,
    input up,
    input down,
    input left,
    input right,
    output [MSEC_WIDTH-1:0] msec,
    output [SEC_WIDTH-1:0] sec,
    output [MIN_WIDTH-1:0] min,
    output [HOUR_WIDTH-1:0] hour
);

    wire w_tick_100hz, w_tick_hour, w_tick_min, w_tick_sec;

    // time_counter #(
    //     .BIT_WIDTH(HOUR_WIDTH),
    //     .TIMES(24)
    // ) U_HOUR_COUNTER (
    //     .clk(clk),
    //     .reset(reset),
    //     .i_tick(w_tick_hour),
    //     .mode(mode),
    //     .run_stop(run_stop),
    //     .clear(clear),
    //     .time_count(hour),
    //     .o_tick()
    // );
    // time_counter #(
    //     .BIT_WIDTH(MIN_WIDTH),
    //     .TIMES(60)
    // ) U_MIN_COUNTER (
    //     .clk(clk),
    //     .reset(reset),
    //     .i_tick(w_tick_min),
    //     .mode(mode),
    //     .run_stop(run_stop),
    //     .clear(clear),
    //     .time_count(min),
    //     .o_tick(w_tick_hour)
    // );

    // time_counter #(
    //     .BIT_WIDTH(SEC_WIDTH),
    //     .TIMES(60)
    // ) U_SEC_COUNTER (
    //     .clk(clk),
    //     .reset(reset),
    //     .i_tick(w_tick_sec),
    //     .mode(mode),
    //     .run_stop(run_stop),
    //     .clear(clear),
    //     .time_count(sec),
    //     .o_tick(w_tick_min)
    // );

    // time_counter #(
    //     .BIT_WIDTH(MSEC_WIDTH),
    //     .TIMES(100)
    // ) U_MSEC_COUNTER (
    //     .clk(clk),
    //     .reset(reset),
    //     .i_tick(w_tick_100hz),
    //     .mode(mode),
    //     .run_stop(run_stop),
    //     .clear(clear),
    //     .time_count(msec),
    //     .o_tick(w_tick_sec)
    // );

    // tick_gen_100hz U_TICK_GEN_100HZ (
    //     .clk(clk),
    //     .reset(reset),
    //     .o_tick(w_tick_100hz)
    // );

endmodule

module tick_gen_100hz (
    input      clk,
    input      reset,
    output reg o_tick
);

    parameter F_COUNT = 1_000_000;  //1_000_000
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                o_tick      <= 1'b1;
            end else begin
                o_tick <= 1'b0;
            end
        end
    end

endmodule


module time_counter #(
    parameter BIT_WIDTH = 7,
    TIMES = 100
) (
    input                      clk,
    input                      reset,
    input                      i_tick,
    input                      mode,
    input                      run_stop,
    input                      clear,
    output     [BIT_WIDTH-1:0] time_count,
    output reg                 o_tick
);

    reg [$clog2(TIMES)-1:0] counter_reg;

    assign time_count = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (i_tick & run_stop) begin
                if (!mode) begin
                    counter_reg <= counter_reg + 1;
                    if (counter_reg == (TIMES - 1)) begin
                        counter_reg <= 0;
                        o_tick <= 1'b1;
                    end
                end else begin
                    counter_reg <= counter_reg - 1;
                    if (counter_reg == 0) begin
                        counter_reg <= (TIMES - 1);
                        o_tick <= 1'b1;
                    end
                end
            end else begin
                o_tick <= 1'b0;
            end
        end
    end

endmodule






// reg[$clog2(1_000_000)-1 : 0]counter_reg;
// reg tick_reg;
// assign o_tick = tick_reg;

// always @ (posedge clk, posedge reset) begin
//     if(reset)begin
//         tick_reg<= 1'b0
//         counter_reg <= 1'b0
//     end else begin
//         if (counter_reg == ($clog2(1_000_000)))
//             counter_reg <= 1'b1
//             o_tick <= tick_gen
//         end else begin 
//             counter_reg <= counter_reg + 1;
//     end 
// end


