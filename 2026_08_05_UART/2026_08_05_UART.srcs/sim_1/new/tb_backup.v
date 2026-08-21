`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/05 11:53:09
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb ();

    parameter baud_tick = (100_000_000 / (9600)) * 10;
    reg clk;
    reg reset;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    wire tx_done;
    wire rx_done;
    wire [7:0] rx_data;
    wire tx;
    wire rx = tx;
    integer i = 0;




    uart_controller dut (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .rx(rx),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .rx_done(rx_done),
        .rx_data(rx_data),
        .tx(tx)


    );

    always #5 clk = ~clk;

    task UART_TX_TASK(input [7:0] data);
        begin
            // #10;
            @(negedge clk);
            tx_start = 1;
            tx_data  = data;
            @(negedge clk);
            tx_start = 0;
            wait (dut.U_UART_TX.tx_done);

        end
    endtask
    task WAIT_TX_DONE();
        wait (dut.U_UART_TX.tx_done);
    endtask
    task UART_RX_TASK(output [7:0] o_data);
        begin
            $display("UART_RX_TASK", $time);
            wait (!tx);
            #(baud_tick / 2);
            if (tx) $display("start bit error");
            #(baud_tick);
            for (j = 0; j < 8; j = j + 1) begin
                o_data[i] = tx;
                #(baud_tick);
            end
            #(baud_tick);
            if (!tx) $display("start bit error");
        end
    endtask

    reg [7:0] o_rx_data;

    initial begin
        clk = 0;
        reset = 1;
        tx_data = 6'h00;
        tx_start = 0;
        #10;
        reset = 0;
        #10;
        for (i = 0; i < 256; i = i + 1) begin
            UART_TX_TASK(i);
            UART_RX_TASK(o_rx_data);
            WAIT_TX_DONE();
            if (j == o_rx_data) $display("PASS");
            else $display("FAIL");
        end

        #100;
        $stop;
    end


endmodule
