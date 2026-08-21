`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Unit test for btn_debounce (btn_debounce.v)
// clk is assumed 100MHz (10ns period) since the internal /50 divider is
// hard-coded to produce a 1MHz sampling clock from that.
// Covers: clean press -> exactly one o_btn pulse, held press -> no repeat
// pulses, release -> no pulse, and a bouncy press -> still only one pulse.
//////////////////////////////////////////////////////////////////////////////////

module tb_btn_debounce();

    localparam CLK_PERIOD = 10; // ns, 100MHz

    reg clk, reset, i_btn;
    wire o_btn;

    integer errors;
    integer pulse_count;

    btn_debounce DUT (
        .clk  (clk),
        .reset(reset),
        .i_btn(i_btn),
        .o_btn(o_btn)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    always @(posedge o_btn) begin
        pulse_count = pulse_count + 1;
        $display("[EVT]  o_btn pulse #%0d at t=%0dns", pulse_count, $time);
    end

    task check_pulse_count(input integer expected, input [255:0] label);
        begin
            if (pulse_count !== expected) begin
                $display("[FAIL] %0s : expected pulse_count=%0d got=%0d (t=%0dns)", label, expected, pulse_count, $time);
                errors = errors + 1;
            end else begin
                $display("[OK]   %0s : pulse_count=%0d", label, pulse_count);
            end
        end
    endtask

    initial begin
        errors      = 0;
        pulse_count = 0;
        clk         = 0;
        reset       = 1;
        i_btn       = 0;
        #(CLK_PERIOD*2);
        reset = 0;

        $display("--- clean press: hold i_btn=1 long enough to fully debounce ---");
        i_btn = 1;
        #9000; // > 8 x 1MHz periods (8000ns) needed to shift 8 ones through q_reg
        check_pulse_count(1, "after clean press settles");

        $display("--- keep holding: must not repeat while still pressed ---");
        #5000;
        check_pulse_count(1, "still held, no repeat pulse");

        $display("--- release: must not pulse on release ---");
        i_btn = 0;
        #9000;
        check_pulse_count(1, "after release settles, no new pulse");

        $display("--- bouncy press: several quick toggles then settle solid ---");
        i_btn = 1; #80;
        i_btn = 0; #120;
        i_btn = 1; #60;
        i_btn = 0; #150;
        i_btn = 1; // now hold solid from here
        #9000;
        check_pulse_count(2, "bouncy press still yields exactly one new pulse");

        i_btn = 0;
        #9000;

        if (errors == 0) $display("tb_btn_debounce: PASS");
        else $display("tb_btn_debounce: FAIL (%0d errors)", errors);
        $stop;
    end

endmodule
