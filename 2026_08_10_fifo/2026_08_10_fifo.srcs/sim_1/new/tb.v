`timescale 1ns / 1ps



module tb ();
    reg push;
    reg pop;
    reg clk;
    reg reset;
    wire full;
    wire empty;
    reg [7:0] w_data;
    wire [7:0] r_data;
    reg [7:0] compare_buffer[0:3];
    reg [1:0] push_cnt;
    reg [1:0] pop_cnt;
    integer pass_count = 0, fail_count = 0;
    integer i = 0;
    fifo dut (

        .push(push),
        .pop(pop),
        .clk(clk),
        .reset(reset),
        .w_data(w_data),
        .r_data(r_data),
        .empty(empty),
        .full(full)
    );

    always #5 clk = ~clk;

    initial begin
        clk    = 0;
        reset  = 1;
        pop    = 0;
        push   = 0;
        w_data = 8'h00;


        @(negedge clk);
        reset  = 0;
        push   = 1;
        w_data = 8'h0a;
        @(negedge clk);
        w_data = 8'h0b;
        @(negedge clk);
        w_data = 8'h0c;
        @(negedge clk);
        w_data = 8'h0d;
        @(negedge clk);
        w_data = 8'h0e;
        @(negedge clk);
        push = 0;
        @(negedge clk);
        pop = 1;
        repeat (5) @(negedge clk);  // #50 대신
        pop = 0;
        @(negedge clk);  // 이제 엣지 정각 충돌 없음
        push   = 1;
        w_data = 8'h10;
        #5;
        pop = 1;
        @(negedge clk);
        w_data = 8'h0b;
        @(negedge clk);
        w_data = 8'h0c;
        @(negedge clk);
        w_data = 8'h0d;
        @(negedge clk);
        w_data = 8'h0e;
        @(negedge clk);
        w_data = 8'h0f;
        @(negedge clk);
        w_data = 8'h10;
        @(negedge clk);
        w_data = 8'h20;
        @(negedge clk);
        push = 0;
        @(negedge clk);
        pop = 0;



        $strobe("%t:RANDOME test start", $time);
        push_cnt = 0;
        pop_cnt  = 0;
        @(posedge clk);
        for (i = 0; i < 256; i = i + 1) begin
            push = $random % 2;
            pop = $random % 2;
            w_data = $random % 256;
            $strobe("%t:push=%d, pop=%d,w_data=%d", $time, push, pop, w_data);
            if (!full & push) begin
                $strobe("%t : compare_buffer = %d, push = %d", $time,
                        compare_buffer[push_cnt], push);
                compare_buffer[push_cnt] = w_data;
                push_cnt = push_cnt + 1;
            end
            if (!empty & pop) begin
                if (compare_buffer[pop_cnt] == r_data) begin
                    $strobe(
                        "%t : PASS!! compare_data = %d, r_data = %d, pop = %d, empty = %d",
                        $time, compare_buffer[pop_cnt], r_data, pop, empty);
                    pass_count = pass_count + 1;
                end else begin
                    $strobe(
                        "%t : Fail!! compare_data = %d, r_data = %d, pop = %d, empty = %d",
                        $time, compare_buffer[pop_cnt], r_data, pop, empty);
                    fail_count = fail_count + 1;
                end
                pop_cnt = pop_cnt + 1;
            end
            #10;
        end
        $strobe("%t : pass_count=%d, fail_count=%d", $time, pass_count,
                fail_count);

        $finish;
    end
endmodule
