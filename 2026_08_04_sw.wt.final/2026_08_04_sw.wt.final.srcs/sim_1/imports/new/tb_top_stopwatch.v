`timescale 1ns / 1ps

module tb_top_stopwatch();

    reg clk, reset;
    reg btn_L, btn_R, btn_U, btn_D, btn_C;
    reg [1:0] sw;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;
    wire [1:0] led;

    top_stopwatch DUT (
        .clk(clk),
        .reset(reset),
        .btn_L(btn_L),
        .btn_R(btn_R),
        .btn_U(btn_U),
        .btn_D(btn_D),
        .btn_C(btn_C),
        .sw(sw),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data),
        .led(led)
    );

    defparam DUT.U_STOPWATCH_DATAPATH.CLK_TICK_GEN100HZ.F_COUNT = 10;
    defparam DUT.U_WATCH_DATAPATH.CLK_TICK_GEN100HZ.F_COUNT = 10;

    always #5 clk = ~clk;

    integer i;

    always @(posedge DUT.U_STOPWATCH_DATAPATH.w_tick_hour) begin
        $display("[%0t] hour tick, msec=%0d sec=%0d min=%0d hour=%0d",
                  $time,
                  DUT.U_STOPWATCH_DATAPATH.msec,
                  DUT.U_STOPWATCH_DATAPATH.sec,
                  DUT.U_STOPWATCH_DATAPATH.min,
                  DUT.U_STOPWATCH_DATAPATH.hour);
    end

    initial begin
        $timeformat(-9, 0, " ns", 10);

        clk = 0;
        reset = 1;
        btn_L = 0; btn_R = 0; btn_U = 0; btn_D = 0; btn_C = 0;
        sw = 2'b00;

        #100;
        reset = 0;
        #100;

        // ===== 1
        btn_L = 1;
        #20_000;
        btn_L = 0;
        #5_000;

        #900_000_000;



        btn_L = 1;
        #20_000;
        btn_L = 0;
        #5_000;

        // ===== 2
        sw[1] = 1;
        #5_000;

        btn_U = 1;
        #20_000;
        btn_U = 0;
        #5_000;

        btn_D = 1;
        #20_000;
        btn_D = 0;
        #5_000;

        // s
        for (i = 0; i < 60; i = i + 1) begin
            btn_U = 1;
            #20_000;
            btn_U = 0;
            #5_000;
        end

        // ===== 3부: RIGHT로 자리 이동하며 min, hour 자리도 up/down =====
        btn_R = 1;
        #20_000;
        btn_R = 0;
        #5_000;

        btn_U = 1;
        #20_000;
        btn_U = 0;
        #5_000;

        btn_D = 1;
        #20_000;
        btn_D = 0;
        #5_000;

        btn_R = 1;
        #20_000;
        btn_R = 0;
        #5_000;

        btn_U = 1;
        #20_000;
        btn_U = 0;
        #5_000;

        btn_D = 1;
        #20_000;
        btn_D = 0;
        #5_000;

        btn_R = 1;
        #20_000;
        btn_R = 0;
        #5_000;

        // ===== 4
        btn_C = 1;
        #20_000;
        btn_C = 0;
        #5_000;




        // ===== 5

        sw[1] = 0;   // stopwatch 
        #5_000;
        #2_000_000;   // stopwatch가 sw[1]=0인 동안에도 계속 흐르는지 보려고 2ms 대기

        $display("[%0t] 2ms 경과 후 sw[1]=0 상태: top_sec=%0d (계속 흐르고 있어야 정상)",
                  $time, DUT.sec);

        sw[1] = 1;   // watch
        #5_000;

        #2_000_000;   // watch도 sw[1]=1인 동안 계속 흐르는지(msec 자동 증가) 확인

        sw[1] = 0; #1_000;
        sw[1] = 1; #1_000;
        sw[1] = 0; #1_000;

        $stop;
    end

endmodule