`timescale 1ns / 1ps
module clock_datapath #(

    parameter MSEC_WIDTH = 7,
    SEC_WIDTH = 6,
    MIN_WIDTH = 6,
    HOUR_WIDTH = 5
) (
    input clk,
    input reset,
    input set_mode,     // 1: 설정모드 (자동 tick 정지, up/down으로 편집 가능)
    input display_mode,  // fnd_controller와 동일 : 0=msec/sec 표시중, 1=min/hour 표시중
    input [1:0] digit_pos,  // 0~3 : 현재 보이는 4자리 중 선택된 자리 (0=오른쪽 끝)
    input up,
    input down,
    output [MSEC_WIDTH-1:0] msec,
    output [SEC_WIDTH-1:0] sec,
    output [MIN_WIDTH-1:0] min,
    output [HOUR_WIDTH-1:0] hour
);

    wire w_tick_100hz_raw, w_tick_100hz, w_tick_hour, w_tick_min, w_tick_sec;

    // 설정모드일 땐 자동 tick 전체를 정지 (MSEC 입력단에서 끊으면 체인 전체가 멈춤)
    assign w_tick_100hz = w_tick_100hz_raw & ~set_mode;

    // digit_pos[0] : 0=1의자리(step 1), 1=10의자리(step 10)
    // digit_pos[1] : 0=하위필드(msec/min), 1=상위필드(sec/hour)
    wire [3:0] w_step = digit_pos[0] ? 4'd10 : 4'd1;
    wire       w_sel_lower = ~digit_pos[1];
    wire       w_sel_upper = digit_pos[1];


    wire       w_sec_up = up & ~display_mode & w_sel_upper;
    wire       w_sec_down = down & ~display_mode & w_sel_upper;
    wire       w_min_up = up & display_mode & w_sel_lower;
    wire       w_min_down = down & display_mode & w_sel_lower;
    wire       w_hour_up = up & display_mode & w_sel_upper;
    wire       w_hour_down = down & display_mode & w_sel_upper;

    clock_time_counter #(
        .BIT_WIDTH(HOUR_WIDTH),
        .TIMES(24),
        .INIT_COUNT(12)
    ) U_HOUR_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_hour),
        .i_up(w_hour_up),
        .i_down(w_hour_down),
        .i_step(w_step),
        .time_count(hour),
        .o_tick()
    );
    clock_time_counter #(
        .BIT_WIDTH(MIN_WIDTH),
        .TIMES(60)
    ) U_MIN_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_min),
        .i_up(w_min_up),
        .i_down(w_min_down),
        .i_step(w_step),
        .time_count(min),
        .o_tick(w_tick_hour)
    );

    clock_time_counter #(
        .BIT_WIDTH(SEC_WIDTH),
        .TIMES(60)
    ) U_SEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_sec),
        .i_up(w_sec_up),
        .i_down(w_sec_down),
        .i_step(w_step),
        .time_count(sec),
        .o_tick(w_tick_min)
    );

    clock_time_counter #(
        .BIT_WIDTH(MSEC_WIDTH),
        .TIMES(100)
    ) U_MSEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .i_up(),
        .i_down(),
        .i_step(w_step),
        .time_count(msec),
        .o_tick(w_tick_sec)
    );

    clock_tick_gen_100hz U_TICK_GEN_100HZ (
        .clk(clk),
        .reset(reset),
        .o_tick(w_tick_100hz_raw)
    );

endmodule


module clock_tick_gen_100hz (
    input      clk,
    input      reset,
    output reg o_tick
);

    parameter F_COUNT = 1_000_000;
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


module clock_time_counter #(
    parameter BIT_WIDTH = 7,
    TIMES = 100,
    INIT_COUNT = 0
) (
    input clk,
    input reset,
    input i_tick,  
    input i_up,  
    input i_down, 
    input [3:0] i_step,  
    output [BIT_WIDTH-1:0] time_count,
    output reg                 o_tick   
);

    reg [BIT_WIDTH-1:0] counter_reg;

    wire [7:0] w_up_sum = counter_reg + i_step;
    wire [7:0] w_down_sum = counter_reg + TIMES - i_step;

    assign time_count = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= INIT_COUNT;
            o_tick <= 1'b0;
        end else begin
            o_tick <= 1'b0;
            if (i_up) begin
               
                counter_reg <= (w_up_sum >= TIMES) ? (w_up_sum - TIMES) : w_up_sum[BIT_WIDTH-1:0];
            end else if (i_down) begin
                counter_reg <= (w_down_sum >= TIMES) ? (w_down_sum - TIMES) : w_down_sum[BIT_WIDTH-1:0];
            end else if (i_tick) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == (TIMES - 1)) begin
                    counter_reg <= 0;
                    o_tick <= 1'b1;
                end
            end
        end
    end
endmodule
