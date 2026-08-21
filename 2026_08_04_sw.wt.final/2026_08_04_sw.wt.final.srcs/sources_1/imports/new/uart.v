`timescale 1ns / 1ps



module uart_controller (
    input clk,
    input reset,
    input tx_start,
    input [7:0] tx_data,
    input rx,
    output tx_busy,
    output tx_done,
    output rx_done,
    output [7:0] rx_data,
    output tx


);

    wire w_o_btn;
    wire w_i_baud_tick;
    wire w_i_baud_tick_16;
    uart_tx U_UART_TX (
        .clk(clk),
        .reset(reset),
        .i_baud_tick(w_i_baud_tick_16),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .tx(tx)
    );

    // baud_tick U_BAUD_TICK (
    //     .clk(clk),
    //     .reset(reset),
    //     .o_baud_tick(w_i_baud_tick)
    // );
    // btn_debounce U_BTN_DEBOUNCE (
    //     .clk  (clk),
    //     .reset(reset),
    //     .i_btn(btn_R),
    //     .o_btn(w_o_btn)
    // );
    baud_tick_rx U_BAUD_TICK_RX (
        .clk(clk),
        .reset(reset),
        .o_baud_tick(w_i_baud_tick_16)
    );
    uart_rx U_UART_RX (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .i_baud_tick(w_i_baud_tick_16),
        .rx_data(rx_data),
        .rx_done(rx_done)

    );



endmodule





module uart_rx (
    input clk,
    input reset,
    input rx,
    input i_baud_tick,
    output [7:0] rx_data,
    output rx_done

);

    localparam IDLE = 2'h0, START = 2'h1, DATA = 2'h2, STOP = 2'h3;
    reg [1:0] c_state, n_state;
    reg [3:0] tick_count_reg, tick_count_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [7:0] data_reg, data_next;
    reg rx_done_reg, rx_done_next;


    assign rx_done = rx_done_reg;
    assign rx_data = data_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= 0;
            tick_count_reg <= 0;
            bit_count_reg <= 0;
            data_reg <= 0;
            rx_done_reg <= 0;
        end else begin
            c_state <= n_state;
            tick_count_reg <= tick_count_next;
            bit_count_reg <= bit_count_next;
            data_reg <= data_next;
            rx_done_reg <= rx_done_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        tick_count_next = tick_count_reg;
        bit_count_next = bit_count_reg;
        data_next = data_reg;
        rx_done_next = 0;
        case (c_state)
            IDLE: begin
                bit_count_next  = 0;
                tick_count_next = 0;
                if (!rx) begin
                    n_state = START;
                end
            end
            START: begin
                if (i_baud_tick) begin
                    if (tick_count_reg == 7) begin
                        if (!rx) begin
                            tick_count_next = 0;
                            n_state = DATA;
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
                        data_next = {rx, data_reg[7:1]};
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                if (i_baud_tick) begin
                    // if (tick_count_reg == 7) begin
                    rx_done_next = 1;
                    n_state = IDLE;
                    //     end else begin
                    //         tick_count_next = tick_count_reg + 1;
                    //     end
                end
            end
        endcase
    end

endmodule





module uart_tx (
    input clk,
    input reset,
    input i_baud_tick,
    input tx_start,
    input [7:0] tx_data,
    output reg tx_busy,
    output tx_done,
    output tx
);

    localparam [1:0] IDLE = 4'h0, START = 4'h1;
    localparam [1:0] DATA = 4'h2;
    localparam [1:0] STOP = 4'h3;
    // localparam [2:0] WAIT = 4'h4;
    // localparam [3:0] BIT0 = 4'h2, BIT1 = 4'h3;
    // localparam [3:0] BIT2 = 4'h4, BIT3 = 4'h5;
    // localparam [3:0] BIT4 = 4'h6, BIT5 = 4'h7;
    // localparam [3:0] BIT6 = 4'h8, BIT7 = 4'h9;
    reg [3:0] c_state, n_state;
    reg [2:0] bit_count_reg, bit_count_next;
    reg tx_reg, tx_next;
    reg [7:0] data_reg, data_next;
    reg tx_done_reg, tx_done_next;
    reg [3:0] tick_count_reg, tick_count_next;


    assign tx_done = tx_done_reg;
    assign tx = tx_reg;
    //state_reg
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


    //next_state
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
            // WAIT: begin
            //     if (i_baud_tick) n_state = START;
            // end
            START: begin
                tx_next        = 1'b0;
                bit_count_next = 3'b0;
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        n_state = DATA;
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
                        data_next = {1'b0, data_reg[7:1]};
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tx_done_next = 1;
                        n_state = IDLE;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
        endcase

    end
endmodule



module baud_tick_rx (
    input  clk,
    input  reset,
    output o_baud_tick
);

    reg o_baud_tick_reg;
    reg [$clog2(100_000_000/(9600*16))-1:0] clk_counter;
    assign o_baud_tick = o_baud_tick_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            clk_counter <= 0;
            o_baud_tick_reg <= 0;
        end else begin
            o_baud_tick_reg <= 0;
            clk_counter <= clk_counter + 1;
            if (clk_counter == ((100_000_000 / (9600 * 16)) - 1)) begin
                clk_counter <= 0;
                o_baud_tick_reg <= 1;
            end
        end

    end

endmodule



// BIT0: begin
//     tx_next = tx_data[0];
//     if (i_baud_tick) begin
//         n_state = BIT1;
//     end
// end
// BIT1: begin
//     tx_next = tx_data[1];
//     if (i_baud_tick) begin
//         n_state = BIT2;
//     end
// end
// BIT2: begin
//     tx_next = tx_data[2];
//     if (i_baud_tick) begin
//         n_state = BIT3;
//     end
// end
// BIT3: begin
//     tx_next = tx_data[3];
//     if (i_baud_tick) begin
//         n_state = BIT4;
//     end
// end
// BIT4: begin
//     tx_next = tx_data[4];
//     if (i_baud_tick) begin
//         n_state = BIT5;
//     end
// end
// BIT5: begin
//     tx_next = tx_data[5];
//     if (i_baud_tick) begin
//         n_state = BIT6;
//     end
// end
// BIT6: begin
//     tx_next = tx_data[6];
//     if (i_baud_tick) begin
//         n_state = BIT7;
//     end
// end
// BIT7: begin
//     tx_next = tx_data[7];
//     if (i_baud_tick) begin
//         n_state = STOP;
//     end
// end






// module baud_tick (
//     input  clk,
//     input  reset,
//     output o_baud_tick
// );

//     reg o_baud_tick_reg;
//     reg [$clog2(100_000_000/9600)-1:0] clk_counter;
//     assign o_baud_tick = o_baud_tick_reg;

//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             clk_counter <= 0;
//             o_baud_tick_reg <= 0;
//         end else begin
//             o_baud_tick_reg <= 0;
//             clk_counter <= clk_counter + 1;
//             if (clk_counter == (100_000_000 / 9600 - 1)) begin
//                 clk_counter <= 0;
//                 o_baud_tick_reg <= 1;
//             end
//         end

//     end

// endmodule
