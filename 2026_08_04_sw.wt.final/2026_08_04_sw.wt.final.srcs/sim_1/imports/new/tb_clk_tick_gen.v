`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Unit test for tick_gen_100hz (clk_tick_gen.v)
// Verifies o_tick pulses exactly once every F_COUNT clock cycles.
//////////////////////////////////////////////////////////////////////////////////

module tb_clk_tick_gen();

    localparam F_COUNT_TEST = 20;   // small value so sim finishes fast
    localparam CLK_PERIOD   = 10;   // ns

    reg  clk, reset;
    wire o_tick;

    integer errors;
    integer tick_num;
    integer gap;
    time    last_tick_time;

    tick_gen_100hz #(
        .F_COUNT(F_COUNT_TEST)
    ) DUT (
        .clk   (clk),
        .reset (reset),
        .o_tick(o_tick)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        errors   = 0;
        tick_num = 0;
        clk      = 0;
        reset    = 1;
        #(CLK_PERIOD*2);
        reset = 0;
        last_tick_time = $time;

        // give it enough time to see 6 ticks, then fail-safe stop
        #(F_COUNT_TEST*CLK_PERIOD*8);
        $display("tb_clk_tick_gen: TIMEOUT waiting for ticks (saw %0d)", tick_num);
        if (tick_num < 6) errors = errors + 1;
        finish_test;
    end

    always @(posedge o_tick) begin
        gap = $time - last_tick_time;
        tick_num = tick_num + 1;
        if (tick_num > 1) begin
            if (gap !== F_COUNT_TEST*CLK_PERIOD) begin
                $display("[FAIL] tick #%0d gap=%0dns, expected %0dns", tick_num, gap, F_COUNT_TEST*CLK_PERIOD);
                errors = errors + 1;
            end else begin
                $display("[OK]   tick #%0d gap=%0dns", tick_num, gap);
            end
        end else begin
            $display("[OK]   first tick observed at t=%0d", $time);
        end
        last_tick_time = $time;
        if (tick_num >= 6) finish_test;
    end

    task finish_test;
        begin
            if (errors == 0) $display("tb_clk_tick_gen: PASS");
            else $display("tb_clk_tick_gen: FAIL (%0d errors)", errors);
            $stop;
        end
    endtask

endmodule
