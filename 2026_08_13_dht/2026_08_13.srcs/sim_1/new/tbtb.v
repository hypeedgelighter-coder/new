`timescale 1ns / 1ps


module tbtb ();


    reg clk;
    reg reset;
    reg btn_start;
    wire dht11_io;
    wire led_valid;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;

    pullup (
        dht11_io
    );  // 실제 보드 풀업 역할: 아무도 안 몰면 1로 유지 (X 방지)

    top_dht dut (
        .clk(clk),
        .reset(reset),
        .btn_start(btn_start),
        .dht11_io(dht11_io),
        .led_valid(led_valid),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk       = 0;
        reset     = 1;
        btn_start = 0;
        #10;
        reset = 0;
        #10;
        btn_start = 1;
        #900;
        


        #1000;
        $finish;
    end
endmodule
