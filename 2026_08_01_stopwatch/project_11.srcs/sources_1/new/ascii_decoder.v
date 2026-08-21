`timescale 1ns / 1ps

module ascii_decoder(
    input[7:0] rx_data;
    output [7:0] ascii_data; 
    );
endmodule


always @(*) begin
    case (rx_data)
    8'h72:ascii_data=run;
    8'h73:ascii_data=stop;
    8'h63:ascii_data=clear;
    8'h6D;ascii_data=mode;
    8'h55;ascii_data=mode;
    8'h44;ascii_data=mode;
    8'h4C;ascii_data=mode;
    8'h52;ascii_data=mode;
    8'h53;ascii_data=mode;
    8'h4D;ascii_data=mode;
    8'h48;ascii_data=mode;
    endcase
    
end
