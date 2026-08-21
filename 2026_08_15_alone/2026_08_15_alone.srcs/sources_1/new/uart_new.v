`timescale 1ns / 1ps

// [신규 파일] uart.v는 원본 보존. 아래는 수정/추가한 동작을 반영한 버전.
module uart_rx_new (
    input clk,
    input reset,
    input start,
    input rx,
    output [7:0] rx_data,
    output rx_done,
    output rx_busy,
    output rx_error
);
    // [수정] 기존 parameter를 FSM 내부 상수로 변경
    localparam [1:0] IDLE = 2'h0, START = 2'h1, DATA = 2'h2, STOP = 2'h3;
    wire baud_tick;
    reg [1:0] c_state, n_state;
    reg [3:0] counter_reg, counter_next;
    reg [3:0] bit_cnt_reg, bit_cnt_next;
    reg [7:0] data_reg, data_next;
    reg rx_done_reg, rx_done_next, rx_busy_reg, rx_busy_next;
    reg rx_error_reg, rx_error_next;

    baud_tick_new U_BAUD_TICK (
        .clk(clk),
        .reset(reset),
        .o_baud_tick(baud_tick)
    );
    assign rx_data  = data_reg;
    // [추가] 원본에는 누락된 출력 연결
    assign rx_done  = rx_done_reg;
    assign rx_busy  = rx_busy_reg;
    assign rx_error = rx_error_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            counter_reg <= 0;
            bit_cnt_reg <= 0;
            data_reg <= 0;
            rx_done_reg <= 0;
            rx_busy_reg <= 0;
            rx_error_reg <= 0;
        end else begin
            c_state <= n_state;
            counter_reg <= counter_next;
            bit_cnt_reg <= bit_cnt_next;
            data_reg <= data_next;
            rx_done_reg <= rx_done_next;
            rx_busy_reg <= rx_busy_next;
            rx_error_reg <= rx_error_next;
        end
    end

    always @(*) begin
        // [추가] 원본에서 누락된 next 기본값. 조합논리 래치 방지.
        n_state = c_state;
        counter_next = counter_reg;
        bit_cnt_next = bit_cnt_reg;
        data_next = data_reg;
        rx_done_next = 1'b0;
        rx_busy_next = rx_busy_reg;
        rx_error_next = rx_error_reg;
        case (c_state)
            IDLE: begin
                rx_busy_next  = 1'b0;
                rx_error_next = 1'b0;
                if (start) begin
                    n_state = START;
                    rx_busy_next = 1'b1;
                    counter_next = 0;
                end
            end
            START: begin
                // [수정] 기존의 counter_reg 직접 대입 제거, counter_next만 변경
                rx_busy_next = 1'b1;
                if (baud_tick) begin
                    if (counter_reg == 7) begin
                        n_state = (rx == 1'b0) ? DATA : IDLE;
                        counter_next = 0;
                    end else counter_next = counter_reg + 1'b1;
                end
            end
            DATA: begin
                // [추가] 원본에 없던 8비트 데이터 수신 상태
                rx_busy_next = 1'b1;
                if (baud_tick) begin
                    if (counter_reg == 15) begin
                        data_next = {rx, data_reg[7:1]};
                        counter_next = 0;
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                            bit_cnt_next = 0;
                        end else bit_cnt_next = bit_cnt_reg + 1'b1;
                    end else counter_next = counter_reg + 1'b1;
                end
            end
            STOP: begin
                // [추가] 수신 완료 done 펄스 및 STOP bit 오류 검사
                n_state = IDLE;
                rx_done_next = 1'b1;
                rx_busy_next = 1'b0;
                rx_error_next = (rx != 1'b1);
            end
            // [추가] 비정상 FSM 상태 복구
            default: begin
                n_state = IDLE;
                counter_next = 0;
                bit_cnt_next = 0;
                rx_busy_next = 0;
            end
        endcase
    end
endmodule

module baud_tick_new (
    input  clk,
    input  reset,
    output o_baud_tick
);
    reg [$clog2(100_000_000/153600)-1:0] counter_reg;
    reg o_baud_tick_reg;
    assign o_baud_tick = o_baud_tick_reg;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_baud_tick_reg <= 0;
        end else if (counter_reg == (100_000_000 / 153600) - 1) begin
            counter_reg <= 0;
            o_baud_tick_reg <= 1;
        end else begin
            counter_reg <= counter_reg + 1'b1;
            o_baud_tick_reg <= 0;
        end
    end
endmodule
