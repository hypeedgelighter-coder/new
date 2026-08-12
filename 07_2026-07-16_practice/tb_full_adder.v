`timescale 1ns / 1ps



module tb_adder_practice();
reg [7:0]a,b;
wire [7:0] s;
wire c;
integer i,j;

full_adder_8bit dut(
    .a(a),
    .b(b),
    .s(s)

);
initial begin
    a=8'b0;
    b=8'b0;
    i=0;
    j=0;

    for (i=0;i<256;i=i+1)begin
        for (j=0;j<256;j=j+1)begin
            a=i;
            b=j;
            #10;
        end
        #10;
    end

        $stop;
end
    

endmodule
