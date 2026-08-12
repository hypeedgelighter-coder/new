`timescale 1ns / 1ps

module nonblocking();
    reg blk_a,blk_b,blk_c,nblk_a,nblk_b,nblk_c;
    initial begin
        blk_a =#15 1'b1;
        blk_b =#5 1'b0;
        blk_c =#10 1'b1;

    end 
    initial begin
        nblk_a <=#15 1'b1;
        nblk_b <=#5 1'b0;
        nblk_c <=#10 1'b1;

    end 


endmodule
