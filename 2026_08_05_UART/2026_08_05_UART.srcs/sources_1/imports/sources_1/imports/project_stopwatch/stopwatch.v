`timescale 1ns / 1ps


module stopwatch_datapath #(

    parameter MSEC_WIDTH = 7,
    SEC_WIDTH = 6,
    MIN_WIDTH = 6,
    HOUR_WIDTH = 5
) (
    input                   clk,
    input                   reset,
    input                   btnl,             // run_stop & start
    input                   btnr,             // clear & beside
    input                   btnu,             // mode & up
    input                   btnd,             // store & down
    input                   display_mode_ta,  // sw[3] == 1 
    input                   display_mode_ts,  // sw[2] == 1
    input  [           1:0] cho_time,
    output                  o_zero,
    output [           3:0] cho_reg,
    output [MSEC_WIDTH-1:0] msec,
    output [ SEC_WIDTH-1:0] sec,
    output [ MIN_WIDTH-1:0] min,
    output [HOUR_WIDTH-1:0] hour
);

    wire w_tick_100hz, w_tick_hour, w_tick_min, w_tick_sec;
    wire w_cho_hour, w_cho_min, w_cho_sec, w_cho_msec;
    // wire [3:0] cho_reg;
    assign o_zero = (msec == 0) && (sec == 0) && (min == 0) && (hour == 0);
    assign w_cho_msec = cho_reg[0];
    assign w_cho_sec = cho_reg[1];
    assign w_cho_min = cho_reg[2];
    assign w_cho_hour = cho_reg[3];


    time_counter #(
        .BIT_WIDTH(HOUR_WIDTH),
        .TIMES(24)
    ) U_HOUR_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_hour),
        .btnr(btnr),
        .btnl(btnl),
        .btnu(btnu),
        .btnd(btnd),
        .display_mode_ta(display_mode_ta),
        .display_mode_ts(display_mode_ts),
        .sel_time(w_cho_hour),
        .time_count(hour),
        .o_tick()
    );
    time_counter #(
        .BIT_WIDTH(MIN_WIDTH),
        .TIMES(60)
    ) U_MIN_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_min),
        .btnr(btnr),
        .btnl(btnl),
        .btnu(btnu),
        .btnd(btnd),
        .display_mode_ta(display_mode_ta),
        .display_mode_ts(display_mode_ts),
        .sel_time(w_cho_min),
        .time_count(min),
        .o_tick(w_tick_hour)
    );

    time_counter #(
        .BIT_WIDTH(SEC_WIDTH),
        .TIMES(60)
    ) U_SEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_sec),
        .btnr(btnr),
        .btnl(btnl),
        .btnu(btnu),
        .btnd(btnd),
        .display_mode_ta(display_mode_ta),
        .display_mode_ts(display_mode_ts),
        .sel_time(w_cho_sec),
        .time_count(sec),
        .o_tick(w_tick_min)
    );

    time_counter #(
        .BIT_WIDTH(MSEC_WIDTH),
        .TIMES(100)
    ) U_MSEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .btnr(btnr),
        .btnl(btnl),
        .btnu(btnu),
        .btnd(btnd),
        .display_mode_ta(display_mode_ta),
        .display_mode_ts(display_mode_ts),
        .sel_time(w_cho_msec),
        .time_count(msec),
        .o_tick(w_tick_sec)
    );

    decoder_2x4x1 U_DECORDER_2x4x1 (
        .cho_time(cho_time),
        .cho_reg (cho_reg)
    );

    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk(clk),
        .reset(reset),
        .o_tick(w_tick_100hz)
    );

endmodule

module decoder_2x4x1 (
    input [1:0] cho_time,
    output reg [3:0] cho_reg
);
    always @(cho_time) begin
        case (cho_time)
            2'b00:   cho_reg = 4'b0001;
            2'b01:   cho_reg = 4'b0010;
            2'b10:   cho_reg = 4'b0100;
            2'b11:   cho_reg = 4'b1000;
            default: cho_reg = 4'b0000;
        endcase
    end
    // wire w_cho_msec = cho_reg[0];
    // wire w_cho_sec = cho_reg[1];
    // wire w_cho_min = cho_reg[2];
    // wire w_cho_hour = cho_reg[3];

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
    input                      btnl,             // run_stop & start 
    input                      btnr,             // clear & beside
    input                      btnu,             // mode & up
    input                      btnd,             // store & down
    input                      display_mode_ta,  // sw[3] == 1 
    input                      display_mode_ts,  // sw[2] == 1
    input                      sel_time,
    output     [BIT_WIDTH-1:0] time_count,
    output reg                 o_tick
);

    reg [$clog2(TIMES)-1:0] counter_reg;
    reg [  BIT_WIDTH-1 : 0] next_store_reg;

    assign time_count = display_mode_ts ? next_store_reg : counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
            next_store_reg <= 1'b0;
        end else begin
            o_tick <= 1'b0;

            if (!display_mode_ta) begin  //자동일반모드
                if (btnr) begin
                    counter_reg <= 0;
                    o_tick <= 1'b0;
                    next_store_reg <= 1'b0;
                end else begin
                    o_tick <= 1'b0;
                    if (btnd) begin
                        next_store_reg <= counter_reg;
                    end

                    if (i_tick & btnl) begin
                        if (!btnu) begin
                            if (counter_reg == (TIMES - 1)) begin
                                counter_reg <= 0;
                                o_tick <= 1'b1;
                            end else begin
                                counter_reg <= counter_reg + 1;
                            end
                        end else begin
                            if (counter_reg == 0) begin
                                counter_reg <= (TIMES - 1);
                                o_tick <= 1'b1;
                            end else begin
                                counter_reg <= counter_reg - 1;

                            end
                        end
                    end
                end
            end else begin  // 수동타임어택모드
                if (i_tick & btnl) begin
                    if (counter_reg == 0) begin
                        counter_reg <= (TIMES - 1);
                        o_tick <= 1'b1;
                    end else begin
                        counter_reg <= counter_reg - 1;
                    end
                end
                if (sel_time) begin
                    if (btnu) begin
                        counter_reg <= (counter_reg == (TIMES - 1)) ? 0 : counter_reg + 1;

                    end else if (btnd) begin
                        counter_reg <= (counter_reg == 0) ? TIMES - 1 : counter_reg - 1;
                    end
                end
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


