`timescale 1ns / 1ps



module fnd_controller(
    input fnd_in,

    );
endmodule



module fnd_sep (
    input fnd_in,
    input sel,
    output fnd_1,
    output fnd_10,
    output fnd_100,
    output fnd_1000
    
);

always @(fnd_in) begin
    case (sel)
    'b00  fnd in%10;
    'b01  (fnd in/10)%10;
    'b10  (fnd in/100)%10;
    'b11  (fnd in/1000)%10; 
    
        default: 
    endcase
    
    
end

module fnd_led (
    input 
);
    
endmodule


    
endmodule
