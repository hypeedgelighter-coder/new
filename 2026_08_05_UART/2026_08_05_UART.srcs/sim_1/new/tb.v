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

    parameter baud_tick =(100_000_000/(9600))*10 ;  // 1비트 유지 시간(ns), 9600bps 기준
    reg clk;
    reg reset;
    reg rx;  // USB-UART RX : 키보드(r/s/c/m/U/D/L/R/S/M/H)
    wire tx;  // USB-UART TX : 수신 바이트 에코백
    reg [4:0] sw;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;
    wire [15:0] led;




    top_stopwatch_clock dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx),
        .sw(sw),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data),
        .led(led)
    );

    always #5 clk = ~clk;

    // rx 라인으로 1바이트를 시간 흐름에 따라 직렬로 내보낸다.
    // idle(1) -> start bit(0) -> data bit 8개(LSB부터) -> stop bit(1)
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            rx = 1'b0;  // start bit
            #baud_tick;
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];  // data bit i (LSB first)
                #baud_tick;
            end
            rx = 1'b1;  // stop bit
            #baud_tick;
        end
    endtask

    initial begin
        clk   = 0;
        reset = 1;
        sw    = 5'b0;
        rx    = 1'b1;  // UART idle 상태는 High
        #10;
        reset = 0;
        #10;

        send_uart_byte(8'h72);  // 'r' -> run

        #(baud_tick * 2);
        $stop;
    end
endmodule
