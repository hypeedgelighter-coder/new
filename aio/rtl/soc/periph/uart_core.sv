// =============================================================================
// UART 코어 : baud_tick_gen / uart_tx / uart_rx
//
//   2026_08_05_UART 의 코드를 그대로 가져왔다. 바꾼 것은 두 가지뿐이다.
//     1) 리셋을 비동기 active-high(reset) -> 동기 active-low(rst_n) 로.
//        CPU/메모리/컨트롤러가 전부 동기 rst_n 이라 맞춰야 리셋이 한 번에 풀린다.
//     2) reg/wire -> logic, always -> always_ff / always_comb (SV 스타일 통일)
//
//   프레이밍 : start(0) + data 8bit (LSB first) + stop(1), 16배 오버샘플링
// =============================================================================

module baud_tick_gen #(
    parameter int SYS_CLK    = 100_000_000,
    parameter int BAUD       = 9_600,
    parameter int OVERSAMPLE = 16
)(
    input  logic clk,
    input  logic rst_n,
    output logic o_baud_tick
);

    localparam int DIV = SYS_CLK / (BAUD * OVERSAMPLE);  // 100M/(9600*16) = 651

    logic [$clog2(DIV+1)-1:0] clk_counter;

    always_ff @(posedge clk)
    begin
        if(!rst_n)
        begin
            clk_counter <= '0;
            o_baud_tick <= 1'b0;
        end
        else
        begin
            o_baud_tick <= 1'b0;
            if(clk_counter == (DIV - 1))
            begin
                clk_counter <= '0;
                o_baud_tick <= 1'b1;
            end
            else
            begin
                clk_counter <= clk_counter + 1'b1;
            end
        end
    end

endmodule


module uart_tx(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       i_baud_tick,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx_busy,
    output logic       tx_done,
    output logic       tx
);

    typedef enum logic [1:0] {
        IDLE  = 2'h0,
        START = 2'h1,
        DATA  = 2'h2,
        STOP  = 2'h3
    } tx_state_e;

    tx_state_e  c_state, n_state;
    logic [2:0] bit_count_reg,  bit_count_next;
    logic       tx_reg,         tx_next;
    logic [7:0] data_reg,       data_next;
    logic       tx_done_reg,    tx_done_next;
    logic [3:0] tick_count_reg, tick_count_next;

    assign tx_done = tx_done_reg;
    assign tx      = tx_reg;

    always_ff @(posedge clk)
    begin
        if(!rst_n)
        begin
            c_state        <= IDLE;
            bit_count_reg  <= 3'b0;
            tx_reg         <= 1'b1;     // 쉬고 있을 때 라인은 1 (idle high)
            data_reg       <= 8'b0;
            tx_done_reg    <= 1'b0;
            tick_count_reg <= 4'b0;
        end
        else
        begin
            c_state        <= n_state;
            bit_count_reg  <= bit_count_next;
            tx_reg         <= tx_next;
            data_reg       <= data_next;
            tx_done_reg    <= tx_done_next;
            tick_count_reg <= tick_count_next;
        end
    end

    always_comb
    begin
        n_state         = c_state;
        bit_count_next  = bit_count_reg;
        tx_next         = tx_reg;
        data_next       = data_reg;
        tx_done_next    = tx_done_reg;
        tick_count_next = tick_count_reg;
        tx_busy         = 1'b1;

        case(c_state)
            IDLE :
            begin
                tick_count_next = 4'b0;
                tx_next         = 1'b1;
                tx_busy         = 1'b0;
                tx_done_next    = 1'b0;
                if(tx_start)
                begin
                    n_state   = START;
                    data_next = tx_data;
                end
            end

            START :
            begin
                tx_next        = 1'b0;
                bit_count_next = 3'b0;
                if(i_baud_tick)
                begin
                    if(tick_count_reg == 4'd15)
                    begin
                        tick_count_next = 4'b0;
                        n_state         = DATA;
                    end
                    else tick_count_next = tick_count_reg + 1'b1;
                end
            end

            DATA :
            begin
                tx_next = data_reg[0];
                if(i_baud_tick)
                begin
                    if(tick_count_reg == 4'd15)
                    begin
                        tick_count_next = 4'b0;
                        data_next       = {1'b0, data_reg[7:1]};
                        if(bit_count_reg == 3'd7) n_state = STOP;
                        else bit_count_next = bit_count_reg + 1'b1;
                    end
                    else tick_count_next = tick_count_reg + 1'b1;
                end
            end

            STOP :
            begin
                tx_next = 1'b1;
                if(i_baud_tick)
                begin
                    if(tick_count_reg == 4'd15)
                    begin
                        tx_done_next = 1'b1;
                        n_state      = IDLE;
                    end
                    else tick_count_next = tick_count_reg + 1'b1;
                end
            end

            default : n_state = IDLE;
        endcase
    end

endmodule


module uart_rx(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    input  logic       i_baud_tick,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    typedef enum logic [1:0] {
        IDLE  = 2'h0,
        START = 2'h1,
        DATA  = 2'h2,
        STOP  = 2'h3
    } rx_state_e;

    rx_state_e  c_state, n_state;
    logic [3:0] tick_count_reg, tick_count_next;
    logic [2:0] bit_count_reg,  bit_count_next;
    logic [7:0] data_reg,       data_next;
    logic       rx_done_reg,    rx_done_next;

    // rx 는 비동기 입력이라 2단 동기화 후 사용 (메타스테이블 방지)
    logic [1:0] rx_sync;
    logic       rx_in;

    assign rx_in   = rx_sync[1];
    assign rx_done = rx_done_reg;
    assign rx_data = data_reg;

    always_ff @(posedge clk)
    begin
        if(!rst_n)
        begin
            c_state        <= IDLE;
            tick_count_reg <= 4'b0;
            bit_count_reg  <= 3'b0;
            data_reg       <= 8'b0;
            rx_done_reg    <= 1'b0;
            rx_sync        <= 2'b11;
        end
        else
        begin
            c_state        <= n_state;
            tick_count_reg <= tick_count_next;
            bit_count_reg  <= bit_count_next;
            data_reg       <= data_next;
            rx_done_reg    <= rx_done_next;
            rx_sync        <= {rx_sync[0], rx};
        end
    end

    always_comb
    begin
        n_state         = c_state;
        tick_count_next = tick_count_reg;
        bit_count_next  = bit_count_reg;
        data_next       = data_reg;
        rx_done_next    = 1'b0;

        case(c_state)
            IDLE :
            begin
                bit_count_next  = 3'b0;
                tick_count_next = 4'b0;
                if(!rx_in) n_state = START;
            end

            START :
            begin
                // 스타트비트 한가운데(8틱)에서 다시 확인 -> 노이즈면 IDLE 복귀
                if(i_baud_tick)
                begin
                    if(tick_count_reg == 4'd7)
                    begin
                        if(!rx_in)
                        begin
                            tick_count_next = 4'b0;
                            n_state         = DATA;
                        end
                        else n_state = IDLE;
                    end
                    else tick_count_next = tick_count_reg + 1'b1;
                end
            end

            DATA :
            begin
                if(i_baud_tick)
                begin
                    if(tick_count_reg == 4'd15)
                    begin
                        tick_count_next = 4'b0;
                        data_next       = {rx_in, data_reg[7:1]};  // LSB first
                        if(bit_count_reg == 3'd7) n_state = STOP;
                        else bit_count_next = bit_count_reg + 1'b1;
                    end
                    else tick_count_next = tick_count_reg + 1'b1;
                end
            end

            STOP :
            begin
                if(i_baud_tick)
                begin
                    rx_done_next = 1'b1;
                    n_state      = IDLE;
                end
            end

            default : n_state = IDLE;
        endcase
    end

endmodule
