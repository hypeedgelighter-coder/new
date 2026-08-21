`timescale 1ns / 1ps

//=====================================================================
// tb_fnd_display  -  fnd_display 단독 무작위 테스트벤치
//
//  대상 : fnd_display.v  (자리수 분리 + 모드 MUX + fnd_controller)
//
//  모드마다 FND 4자리에 뭘 띄우는지가 다르다.
//    스톱워치/시계 sw[0]=0 : SS.mm  (초 . 밀리초, dot 항상 점등)
//    스톱워치/시계 sw[0]=1 : HH.MM  (시 . 분,     dot 은 msec<50 일 때만)
//    SR04                  : _123   (맨 앞자리 소등, dot 꺼짐)
//    DHT11                 : 60.25  (습도 . 온도, dot 항상 점등)
//
//  [무작위로 만드는 것]
//    mode_sel / disp_mode / msec / sec / min / hour / distance /
//    humidity / temperature 를 전부 무작위로, 무작위 간격마다 바꾼다.
//    실제로 나올 수 없는 큰 값(거리 511, 습도 255 등)도 일부러 넣는다.
//    -> 예전에 거리 400cm 에서 digit_10 = 40 이 되어 4비트를 넘쳐
//       깨졌던 종류의 버그를 잡기 위해서다.
//
//  [검사 방법]
//    테스트벤치가 모드별로 4자리를 따로 계산해 두고, 자리 스캔이
//    돌아가는 매 클럭마다 "지금 켜진 자리의 세그먼트 코드"를 비교한다.
//    dp(비트7) 점등 조건도 같이 본다.
//=====================================================================
module tb_fnd_display ();

    localparam integer SCAN    = 4;
    localparam integer N_CYCLE = 6000;

    localparam [1:0] MODE_STOPWATCH = 2'd0,
                     MODE_WATCH     = 2'd1,
                     MODE_SR04      = 2'd2,
                     MODE_DHT11     = 2'd3;

    localparam [3:0] BLANK = 4'he;

    reg        clk = 1'b0;
    reg        reset;
    reg  [1:0] mode_sel;
    reg        disp_mode;
    reg  [6:0] msec;
    reg  [5:0] sec, min;
    reg  [4:0] hour;
    reg  [8:0] distance;
    reg  [7:0] humidity, temperature;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;

    reg [7:0] tbl[0:15];

    integer seed, seed0;
    integer errors, checks;
    integer i, hold, sel;
    reg [3:0] e_d1, e_d10, e_d100, e_d1000, exp_digit;
    reg       e_dot;
    reg [7:0] exp_seg;
    reg       monitor_on;

    always #5 clk = ~clk;

    fnd_display #(
        .SCAN_COUNT(SCAN)
    ) DUT (
        .clk        (clk),
        .reset      (reset),
        .mode_sel   (mode_sel),
        .disp_mode  (disp_mode),
        .msec       (msec),
        .sec        (sec),
        .min        (min),
        .hour       (hour),
        .distance   (distance),
        .humidity   (humidity),
        .temperature(temperature),
        .fnd_com    (fnd_com),
        .fnd_data   (fnd_data)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  mode=%0d sel=%0d data=%h exp=%h",
                             $time, tag, mode_sel, sel, fnd_data, exp_seg);
            end
        end
    endtask

    function integer com2sel(input [3:0] com);
        begin
            case (com)
                4'b1110: com2sel = 0;
                4'b1101: com2sel = 1;
                4'b1011: com2sel = 2;
                4'b0111: com2sel = 3;
                default: com2sel = -1;
            endcase
        end
    endfunction

    //-----------------------------------------------------------------
    //  기대하는 4자리와 dot  (fnd_display 와 같은 규칙을 따로 계산)
    //-----------------------------------------------------------------
    task calc_expect;
        begin
            case (mode_sel)
                MODE_SR04: begin
                    e_d1000 = BLANK;
                    e_d100  = (distance / 100) % 10;
                    e_d10   = (distance / 10) % 10;
                    e_d1    = distance % 10;
                    e_dot   = 1'b0;
                end
                MODE_DHT11: begin
                    e_d1000 = (humidity / 10) % 10;
                    e_d100  = humidity % 10;
                    e_d10   = (temperature / 10) % 10;
                    e_d1    = temperature % 10;
                    e_dot   = 1'b1;
                end
                default: begin
                    if (disp_mode) begin  // HH.MM
                        e_d1000 = hour / 10;
                        e_d100  = hour % 10;
                        e_d10   = min / 10;
                        e_d1    = min % 10;
                        e_dot   = (msec < 50);
                    end else begin        // SS.mm
                        e_d1000 = sec / 10;
                        e_d100  = sec % 10;
                        e_d10   = (msec / 10) % 10;
                        e_d1    = msec % 10;
                        e_dot   = 1'b1;
                    end
                end
            endcase
        end
    endtask

    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            calc_expect;
            sel = com2sel(fnd_com);
            chk(sel >= 0, "fnd_com is not one-cold");
            if (sel >= 0) begin
                case (sel)
                    0: exp_digit = e_d1;
                    1: exp_digit = e_d10;
                    2: exp_digit = e_d100;
                    default: exp_digit = e_d1000;
                endcase
                exp_seg = tbl[exp_digit];
                if (e_dot && sel == 2) exp_seg[7] = 1'b0;
                chk(fnd_data === exp_seg, "fnd_data mismatch");
            end
        end
    end

    initial begin
        seed0  = 32'h0FD0_0D15;
        seed   = seed0;
        errors = 0;
        checks = 0;

        tbl[0]  = 8'hc0; tbl[1]  = 8'hf9; tbl[2]  = 8'ha4; tbl[3]  = 8'hb0;
        tbl[4]  = 8'h99; tbl[5]  = 8'h92; tbl[6]  = 8'h82; tbl[7]  = 8'hf8;
        tbl[8]  = 8'h80; tbl[9]  = 8'h90; tbl[10] = 8'h88; tbl[11] = 8'h83;
        tbl[12] = 8'hc6; tbl[13] = 8'ha1; tbl[14] = 8'hff; tbl[15] = 8'h7f;

        monitor_on  = 1'b0;
        reset       = 1'b1;
        mode_sel    = MODE_STOPWATCH;
        disp_mode   = 1'b0;
        msec = 0; sec = 0; min = 0; hour = 0;
        distance = 0; humidity = 0; temperature = 0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        i = 0;
        while (i < N_CYCLE) begin
            mode_sel    = {$random(seed)} % 4;
            disp_mode   = {$random(seed)} % 2;
            msec        = {$random(seed)} % 128;  // 0~127 (표시범위 밖도 포함)
            sec         = {$random(seed)} % 64;
            min         = {$random(seed)} % 64;
            hour        = {$random(seed)} % 32;
            distance    = {$random(seed)} % 512;  // 0~511
            humidity    = {$random(seed)} % 256;
            temperature = {$random(seed)} % 256;
            hold        = 1 + ({$random(seed)} % 20);
            repeat (hold) @(negedge clk);
            i = i + hold;
        end

        //---------------- 콜론 점멸 경계를 콕 집어서 ----------------
        mode_sel = MODE_WATCH; disp_mode = 1'b1;
        msec = 49; repeat (SCAN * 4) @(negedge clk);  // dot 켜짐
        msec = 50; repeat (SCAN * 4) @(negedge clk);  // dot 꺼짐
        msec = 99; repeat (SCAN * 4) @(negedge clk);
        msec = 0;  repeat (SCAN * 4) @(negedge clk);

        //---------------- SR04 맨 앞자리 소등 확인 ----------------
        mode_sel = MODE_SR04; distance = 123;
        repeat (SCAN * 6) @(negedge clk);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_fnd_display : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_fnd_display : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_fnd_display : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
