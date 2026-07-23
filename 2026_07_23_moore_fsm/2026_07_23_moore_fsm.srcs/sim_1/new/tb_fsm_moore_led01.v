`timescale 1ns / 1ps



module tb_fsm_moore_led01();

reg reset;
reg clk;
reg [2:0]sw;
wire [2:0]led;

fsm_moore_led01 dut(
    .clk(clk),
    .reset(reset),
    .sw(sw),
    .led(led)

    );

always #5 clk=~clk;

initial begin
    clk=0;
    reset=1;
    sw=3'b000;
    #10;
    reset=0;
    #20;
    sw=3'b000;
    #20;
    sw=3'b001;
    #20;
    sw=3'b010;
    #20;
    sw=3'b011;
    #20;
    sw=3'b100;
    #20;
    sw=3'b000;
    #20
    $finish;


end

endmodule
