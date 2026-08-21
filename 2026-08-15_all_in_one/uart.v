`timescale 1ns / 1ps

//=====================================================================
// UART 송/수신기 + baud tick 생성기
//  16배 오버샘플링 방식 (baud_tick 이 보드레이트의 16배로 나온다)
//  기존 2026_08_05_UART 코드 그대로. baud_tick_rx -> baud_tick_gen 으로
//  이름만 바꾸고 보드레이트/시스템클럭을 파라미터로 뺐다.
//=====================================================================

module baud_tick_gen #(
    parameter SYS_CLK = 100_000_000,
    parameter BAUD    = 9600,
    parameter OVERSAMPLE = 16
) (
    input  clk,
    input  reset,
    output o_baud_tick
);
    localparam DIV = SYS_CLK / (BAUD * OVERSAMPLE);  // 100M/(9600*16) = 651

    reg o_baud_tick_reg;
    reg [$clog2(DIV)-1:0] clk_counter;

    assign o_baud_tick = o_baud_tick_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            clk_counter     <= 0;
            o_baud_tick_reg <= 1'b0;
        end else begin
            o_baud_tick_reg <= 1'b0;
            if (clk_counter == (DIV - 1)) begin
                clk_counter     <= 0;
                o_baud_tick_reg <= 1'b1;
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
    end
endmodule


module uart_rx (
    input        clk,
    input        reset,
    input        rx,
    input        i_baud_tick,
    output [7:0] rx_data,
    output       rx_done
);
    localparam IDLE = 2'h0, START = 2'h1, DATA = 2'h2, STOP = 2'h3;

    reg [1:0] c_state, n_state;
    reg [3:0] tick_count_reg, tick_count_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [7:0] data_reg, data_next;
    reg rx_done_reg, rx_done_next;

    // rx 는 비동기 입력이라 2단 동기화 후 사용 (메타스테이블 방지)
    reg [1:0] rx_sync;
    wire rx_in = rx_sync[1];

    assign rx_done = rx_done_reg;
    assign rx_data = data_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state        <= IDLE;
            tick_count_reg <= 0;
            bit_count_reg  <= 0;
            data_reg       <= 0;
            rx_done_reg    <= 0;
            rx_sync        <= 2'b11;
        end else begin
            c_state        <= n_state;
            tick_count_reg <= tick_count_next;
            bit_count_reg  <= bit_count_next;
            data_reg       <= data_next;
            rx_done_reg    <= rx_done_next;
            rx_sync        <= {rx_sync[0], rx};
        end
    end

    always @(*) begin
        n_state         = c_state;
        tick_count_next = tick_count_reg;
        bit_count_next  = bit_count_reg;
        data_next       = data_reg;
        rx_done_next    = 1'b0;
        case (c_state)
            IDLE: begin
                bit_count_next  = 0;
                tick_count_next = 0;
                if (!rx_in) n_state = START;
            end
            START: begin
                // 스타트비트 한가운데(8틱)에서 다시 확인 -> 노이즈면 IDLE 복귀
                if (i_baud_tick) begin
                    if (tick_count_reg == 7) begin
                        if (!rx_in) begin
                            tick_count_next = 0;
                            n_state         = DATA;
                        end else begin
                            n_state = IDLE;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        data_next       = {rx_in, data_reg[7:1]};  // LSB first
                        if (bit_count_reg == 7) n_state = STOP;
                        else bit_count_next = bit_count_reg + 1;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                if (i_baud_tick) begin
                    rx_done_next = 1'b1;
                    n_state      = IDLE;
                end
            end
        endcase
    end
endmodule


module uart_tx (
    input        clk,
    input        reset,
    input        i_baud_tick,
    input        tx_start,
    input  [7:0] tx_data,
    output reg   tx_busy,
    output       tx_done,
    output       tx
);
    localparam [1:0] IDLE = 2'h0, START = 2'h1, DATA = 2'h2, STOP = 2'h3;

    reg [1:0] c_state, n_state;
    reg [2:0] bit_count_reg, bit_count_next;
    reg tx_reg, tx_next;
    reg [7:0] data_reg, data_next;
    reg tx_done_reg, tx_done_next;
    reg [3:0] tick_count_reg, tick_count_next;

    assign tx_done = tx_done_reg;
    assign tx      = tx_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state        <= IDLE;
            bit_count_reg  <= 3'b0;
            tx_reg         <= 1'b1;
            data_reg       <= 8'b0;
            tx_done_reg    <= 1'b0;
            tick_count_reg <= 0;
        end else begin
            c_state        <= n_state;
            bit_count_reg  <= bit_count_next;
            tx_reg         <= tx_next;
            data_reg       <= data_next;
            tx_done_reg    <= tx_done_next;
            tick_count_reg <= tick_count_next;
        end
    end

    always @(*) begin
        n_state         = c_state;
        bit_count_next  = bit_count_reg;
        tx_next         = tx_reg;
        data_next       = data_reg;
        tx_done_next    = tx_done_reg;
        tx_busy         = 1'b1;
        tick_count_next = tick_count_reg;
        case (c_state)
            IDLE: begin
                tick_count_next = 0;
                tx_next         = 1'b1;
                tx_busy         = 1'b0;
                tx_done_next    = 1'b0;
                if (tx_start) begin
                    n_state   = START;
                    data_next = tx_data;
                end
            end
            START: begin
                tx_next        = 1'b0;
                bit_count_next = 3'b0;
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        n_state         = DATA;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_reg[0];
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        data_next       = {1'b0, data_reg[7:1]};
                        if (bit_count_reg == 7) n_state = STOP;
                        else bit_count_next = bit_count_reg + 1;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tx_done_next = 1'b1;
                        n_state      = IDLE;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule
