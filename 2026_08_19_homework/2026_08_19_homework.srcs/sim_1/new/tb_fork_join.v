`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/19 21:39:12
// Design Name: 
// Module Name: tb_fork_join
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


// 1) fork - join
module tb_fork_join ();

    initial begin
        #1 $display("%t : start fork - join", $time);

        fork
            // task A
            #10 A_thread();
            // task B
            #20 B_thread();
            // task C
            #15 C_thread();
        join

        #10 $display("%t : end fork - join", $time);
    end

    task A_thread();
        $display("%t : A thread", $time);
    endtask  //A_thread

    task B_thread();
        $display("%t : B thread", $time);
    endtask  //A_thread

    task C_thread();
        $display("%t : C thread", $time);
    endtask  //A_thread
endmodule


// 2) fork - join_any
module tb_fork_join2 ();

    initial begin
        #1 $display("%t : start fork - join", $time);

        fork
            // task A
            #10 A_thread();
            // task B
            #20 B_thread();
            // task C
            #15 C_thread();
        join_any

        #10 $display("%t : end fork - join", $time);
    end

    task A_thread();
        $display("%t : A thread", $time);
    endtask  //A_thread

    task B_thread();
        $display("%t : B thread", $time);
    endtask  //A_thread

    task C_thread();
        $display("%t : C thread", $time);
    endtask  //A_thread
endmodule


// 3) nested fork - join / join_any
module tb_fork_join3 ();

    initial begin
        #1 $display("%t : start fork - join", $time);

        fork
            // task A
            #10 A_thread();
            fork
                // task B
                #20 B_thread();
                #50 B_thread();
            join
            // task C
            #30 C_thread();
        join_any

        #10 $display("%t : end fork - join", $time);
    end

    task A_thread();
        $display("%t : A thread", $time);
    endtask  //A_thread

    task B_thread();
        $display("%t : B thread", $time);
    endtask  //A_thread

    task C_thread();
        $display("%t : C thread", $time);
    endtask  //A_thread
endmodule


// 4) fork - join_none
module tb_fork_join4 ();

    initial begin
        #1 $display("%t : start fork - join", $time);

        fork
            // task A
            #10 A_thread();
            // task B
            #20 B_thread();
            // task C
            #15 C_thread();
        join_none

        #10 $display("%t : end fork - join", $time);
    end

    task A_thread();
        $display("%t : A thread", $time);
    endtask  //A_thread

    task B_thread();
        $display("%t : B thread", $time);
    endtask  //A_thread

    task C_thread();
        $display("%t : C thread", $time);
    endtask  //A_thread
endmodule


// 5) fork - join_any + disable fork
module tb_fork_join5 ();

    initial begin
        #1 $display("%t : start fork - join", $time);
        fork
            // task A
            A_thread();
            // task B
            B_thread();
            // task C
            C_thread();
        join_any
        #10 $display("%t : end fork - join", $time);
        disable fork;
        $stop;
    end

    task A_thread();
        repeat (5) $display("%t : A thread", $time);
    endtask  //A_thread

    task B_thread();
        forever begin
            $display("%t : B thread", $time);
            #5;
        end
    endtask  //A_thread

    task C_thread();
        forever begin
            $display("%t : C thread", $time);
            #10;
        end
    endtask  //A_thread
endmodule
