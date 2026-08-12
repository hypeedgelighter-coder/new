`timescale 1ns / 1ps


module tb_multiply();
reg [3:0]a,b;
wire [7:0]p;
integer i,j;

multiply dut(
    .a(a),
    .b(b),
    .p(p)
);


initial begin
    a=8'b0;
    b=8'b0;
    for ( i=0;i<16;i=i+1) begin
        for (j=0;j<16;j=j+1) begin
            a=i;
            b=j;
            #10;
            
        end
        #10;
    end
    
end
endmodule
