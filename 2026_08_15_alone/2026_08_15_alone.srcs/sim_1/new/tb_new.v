`timescale 1ns / 1ps

// [신규 파일] tb.v는 원본 보존.
module tb_new ();
    reg clk, reset, start, rx;
    wire [7:0] rx_data;
    wire rx_done, rx_busy, rx_error;

    uart_rx_new dut (
        .clk(clk),
        .reset(rset),
        // [수정 제안] rset은 선언되지 않았으므로 아래처럼 바꾸면 reset이 DUT에 연결됨
        // .reset(reset),
        .start(start), .rx(rx), .rx_data(rx_data), .rx_done(rx_done),
        .rx_busy(rx_busy), .rx_error(rx_error)
    );

    always #5 clk = ~clk;
    initial begin
        clk = 0; reset = 1; start = 0;
        #10 reset = 0; start = 1;
    end
endmodule
