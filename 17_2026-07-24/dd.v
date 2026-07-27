`timescale 1ns / 1ps



module dd ();

    reg [7:0] a, b;

    initial begin
        a = 8'h34;
        b = 8'h34;

        #10 b <= a + 1;

        $display("$display-1:time=%0t a=%h b%h", $time, a, b);
        $strobe("$display-1:time=%0t a=%h b%h", $time, a, b);
        
        #5
        
        $display("$display-2:time=%0t a=%h b%h", $time, a, b);
        $strobe("$display-2:time=%0t a=%h b%h", $time, a, b);
    end
endmodule
