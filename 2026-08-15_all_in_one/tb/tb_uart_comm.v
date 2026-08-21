`timescale 1ns / 1ps

//=====================================================================
// tb_uart_comm  -  uart_comm 단독 무작위 테스트벤치
//
//  대상 : uart_comm.v  (uart_fifo + ascii_decoder + ascii_sender + 송신 타이밍)
//
//   PC --TX--> rx --> [uart_fifo] --> [ascii_decoder] --> cmd_* 펄스
//   PC <--RX-- tx <-- [uart_fifo] <-- [ascii_sender]  <-- 표시값
//                                          ^
//                              1초마다 + 센서 측정 완료마다
//
//  하위 모듈들은 각자의 테스트벤치에서 따로 본다. 여기서는 PC 쪽 역할을
//  하면서 "문자를 넣으면 명령이 나오고, 값을 넣으면 문자열이 나오는가"
//  를 선 끝에서 확인한다.
//
//  시뮬용으로 625kbps, 자동 송신 주기도 확 줄여서 쓴다.
//
//  [무작위로 만드는 것]
//    1) 보내는 명령 문자 순서 (12개 중 무작위) + 매핑 없는 문자 섞기
//    2) 문자 사이 간격
//    3) 표시값 (시/분/초/밀리초/거리/습도/온도) 전부 무작위
//
//  [검사]
//    1) 문자 하나에 해당 명령 펄스가 정확히 한 번 (다른 명령은 안 나감)
//    2) 매핑 없는 문자는 아무 명령도 안 냄
//    3) 자동 주기 송신 문자열이 모드별 포맷과 정확히 같은가
//    4) 센서 측정 완료(done)로도 송신이 나가는가
//    5) 현재 모드가 아닌 센서의 done 으로는 송신이 안 나가는가
//=====================================================================
module tb_uart_comm ();

    localparam integer BAUD     = 625_000;
    localparam integer DIV      = 100_000_000 / (BAUD * 16);  // 10
    localparam integer BIT_CLKS = 16 * DIV;                   // 160
    localparam integer SEND_PER = 120_000;                    // 자동 송신 주기

    localparam [1:0] MODE_STOPWATCH = 2'd0,
                     MODE_WATCH     = 2'd1,
                     MODE_SR04      = 2'd2,
                     MODE_DHT11     = 2'd3;

    localparam [7:0] CR = 8'h0d, LF = 8'h0a;

    reg  clk = 1'b0;
    reg  reset;
    reg  rx;
    wire tx;

    wire cmd_run, cmd_stop, cmd_clear, cmd_mode;
    wire cmd_up, cmd_down, cmd_left, cmd_right;
    wire cmd_sel_s, cmd_sel_m, cmd_sel_h, cmd_start;

    reg [1:0] mode_sel;
    reg [6:0] msec;
    reg [5:0] sec, min;
    reg [4:0] hour;
    reg [8:0] distance;
    reg [7:0] humidity, temperature;
    reg       sr04_done, dht_done;

    wire [11:0] cmd_vec = {cmd_start, cmd_sel_h, cmd_sel_m, cmd_sel_s,
                           cmd_right, cmd_left, cmd_down, cmd_up,
                           cmd_mode, cmd_clear, cmd_stop, cmd_run};

    reg [11:0] hits;
    integer    n_pulse;

    // 수신한 문자열 모으기
    reg [7:0] line[0:31];
    integer   n_line;
    reg       line_done;
    integer   k2;
    reg [7:0] b2;

    reg [7:0] exp_s[0:15];
    integer   exp_len;

    reg [7:0] cmd_tbl[0:11];

    integer seed, seed0;
    integer errors, checks;
    integer i, j, guard;
    reg [7:0] ch;
    reg [11:0] expv;

    always #5 clk = ~clk;

    uart_comm #(
        .SYS_CLK    (100_000_000),
        .BAUD       (BAUD),
        .AWIDTH     (4),
        .SEND_PERIOD(SEND_PER)
    ) DUT (
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),
        .tx         (tx),
        .cmd_run    (cmd_run),
        .cmd_stop   (cmd_stop),
        .cmd_clear  (cmd_clear),
        .cmd_mode   (cmd_mode),
        .cmd_up     (cmd_up),
        .cmd_down   (cmd_down),
        .cmd_left   (cmd_left),
        .cmd_right  (cmd_right),
        .cmd_sel_s  (cmd_sel_s),
        .cmd_sel_m  (cmd_sel_m),
        .cmd_sel_h  (cmd_sel_h),
        .cmd_start  (cmd_start),
        .mode_sel   (mode_sel),
        .msec       (msec),
        .sec        (sec),
        .min        (min),
        .hour       (hour),
        .distance   (distance),
        .humidity   (humidity),
        .temperature(temperature),
        .sr04_done  (sr04_done),
        .dht_done   (dht_done)
    );

    task chk(input cond, input [8*30:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20) $display("  FAIL [%0t] %0s", $time, tag);
            end
        end
    endtask

    function [11:0] decode(input [7:0] b);
        begin
            case (b)
                "r": decode = 12'b0000_0000_0001;
                "s": decode = 12'b0000_0000_0010;
                "c": decode = 12'b0000_0000_0100;
                "m": decode = 12'b0000_0000_1000;
                "U": decode = 12'b0000_0001_0000;
                "D": decode = 12'b0000_0010_0000;
                "L": decode = 12'b0000_0100_0000;
                "R": decode = 12'b0000_1000_0000;
                "S": decode = 12'b0001_0000_0000;
                "M": decode = 12'b0010_0000_0000;
                "H": decode = 12'b0100_0000_0000;
                "t": decode = 12'b1000_0000_0000;
                default: decode = 12'b0000_0000_0000;
            endcase
        end
    endfunction

    //---------------- 명령 펄스 모으기 ----------------
    always @(posedge clk) begin
        if (cmd_vec !== 12'b0) begin
            hits    = hits | cmd_vec;
            n_pulse = n_pulse + 1;
        end
    end

    //---------------- TX 선을 계속 받아서 한 줄씩 모으기 ----------------
    initial begin : tx_monitor
        n_line    = 0;
        line_done = 1'b0;
        forever begin
            @(negedge tx);
            repeat (BIT_CLKS + BIT_CLKS / 2) @(negedge clk);
            for (k2 = 0; k2 < 8; k2 = k2 + 1) begin
                b2[k2] = tx;
                if (k2 < 7) repeat (BIT_CLKS) @(negedge clk);
            end
            if (n_line < 32) line[n_line] = b2;
            n_line = n_line + 1;
            if (b2 == LF) line_done = 1'b1;
        end
    end

    task start_capture;
        begin
            n_line    = 0;
            line_done = 1'b0;
        end
    endtask

    // 한 줄이 다 올 때까지 기다린다. 못 받으면 ok=0.
    task capture_line(input integer max_clk, output ok);
        begin
            guard = 0;
            while (line_done !== 1'b1 && guard < max_clk) begin
                @(negedge clk);
                guard = guard + 1;
            end
            ok = line_done;
        end
    endtask

    task send_serial(input [7:0] b);
        integer k;
        begin
            rx = 1'b0;
            repeat (BIT_CLKS) @(negedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                rx = b[k];
                repeat (BIT_CLKS) @(negedge clk);
            end
            rx = 1'b1;
            repeat (BIT_CLKS) @(negedge clk);
        end
    endtask

    //---------------- 기대 문자열 ----------------
    task build_expect;
        reg [3:0] h10, h1, m10, m1, s10, s1, ms10, ms1;
        reg [3:0] d100, d10, d1, hu10, hu1, te10, te1;
        begin
            h10  = hour / 10;        h1  = hour % 10;
            m10  = min / 10;         m1  = min % 10;
            s10  = sec / 10;         s1  = sec % 10;
            ms10 = (msec / 10) % 10; ms1 = msec % 10;
            d100 = (distance / 100) % 10;
            d10  = (distance / 10) % 10;
            d1   = distance % 10;
            hu10 = (humidity / 10) % 10;    hu1 = humidity % 10;
            te10 = (temperature / 10) % 10; te1 = temperature % 10;

            case (mode_sel)
                MODE_SR04: begin
                    exp_s[0]="D"; exp_s[1]="I"; exp_s[2]="S"; exp_s[3]="T";
                    exp_s[4]=" ";
                    exp_s[5]="0"+d100; exp_s[6]="0"+d10; exp_s[7]="0"+d1;
                    exp_s[8]="c"; exp_s[9]="m"; exp_s[10]=CR; exp_s[11]=LF;
                    exp_len = 12;
                end
                MODE_DHT11: begin
                    exp_s[0]="H"; exp_s[1]=" ";
                    exp_s[2]="0"+hu10; exp_s[3]="0"+hu1;
                    exp_s[4]="%"; exp_s[5]=" "; exp_s[6]="T"; exp_s[7]=" ";
                    exp_s[8]="0"+te10; exp_s[9]="0"+te1;
                    exp_s[10]="C"; exp_s[11]=CR; exp_s[12]=LF;
                    exp_len = 13;
                end
                default: begin
                    exp_s[0]="0"+h10; exp_s[1]="0"+h1;  exp_s[2]=":";
                    exp_s[3]="0"+m10; exp_s[4]="0"+m1;  exp_s[5]=":";
                    exp_s[6]="0"+s10; exp_s[7]="0"+s1;  exp_s[8]=".";
                    exp_s[9]="0"+ms10; exp_s[10]="0"+ms1;
                    exp_s[11]=CR; exp_s[12]=LF;
                    exp_len = 13;
                end
            endcase
        end
    endtask

    task show_line;
        integer p;
        begin
            $write("    tx=\"");
            for (p = 0; p < n_line && p < 32; p = p + 1)
                if (line[p] >= 8'h20 && line[p] < 8'h7f) $write("%c", line[p]);
            $display("\"");
        end
    endtask

    task compare_line;
        integer p;
        begin
            chk(n_line == exp_len, "tx line length wrong");
            if (n_line == exp_len)
                for (p = 0; p < exp_len; p = p + 1)
                    chk(line[p] === exp_s[p], "tx line content wrong");
            show_line;
        end
    endtask

    reg ok;

    initial begin
        seed0  = 32'h0C00_9901;
        seed   = seed0;
        errors = 0;
        checks = 0;
        hits   = 12'b0;
        n_pulse = 0;

        cmd_tbl[0]="r"; cmd_tbl[1]="s"; cmd_tbl[2]="c"; cmd_tbl[3]="m";
        cmd_tbl[4]="U"; cmd_tbl[5]="D"; cmd_tbl[6]="L"; cmd_tbl[7]="R";
        cmd_tbl[8]="S"; cmd_tbl[9]="M"; cmd_tbl[10]="H"; cmd_tbl[11]="t";

        reset       = 1'b1;
        rx          = 1'b1;
        mode_sel    = MODE_WATCH;
        msec = 0; sec = 0; min = 0; hour = 0;
        distance = 0; humidity = 0; temperature = 0;
        sr04_done = 1'b0;
        dht_done  = 1'b0;
        repeat (5) @(negedge clk);
        reset = 1'b0;
        repeat (20) @(negedge clk);

        //=============== 1) 수신 : 문자 -> 명령 펄스 ===============
        for (i = 0; i < 24; i = i + 1) begin
            if (({$random(seed)} % 4) != 0) ch = cmd_tbl[{$random(seed)} % 12];
            else                            ch = {$random(seed)} % 256;

            hits    = 12'b0;
            n_pulse = 0;
            send_serial(ch);
            repeat (60) @(negedge clk);

            expv = decode(ch);
            chk(hits === expv, "wrong command for char");
            if (expv == 12'b0) chk(n_pulse == 0, "unmapped char made a pulse");
            else               chk(n_pulse == 1, "command pulse count != 1");

            repeat (10 + ({$random(seed)} % 200)) @(negedge clk);
        end

        //=============== 2) 자동 주기 송신 : 모드별 문자열 ===============
        for (i = 0; i < 2; i = i + 1) begin
            mode_sel    = MODE_WATCH;
            hour        = {$random(seed)} % 24;
            min         = {$random(seed)} % 60;
            sec         = {$random(seed)} % 60;
            msec        = {$random(seed)} % 100;
            build_expect;

            start_capture;              // 진행 중이던 줄은 버리고
            capture_line(SEND_PER * 2, ok);
            start_capture;              // 값이 안정된 뒤의 다음 줄로 본다
            capture_line(SEND_PER * 2, ok);
            chk(ok === 1'b1, "no periodic tx line (watch)");
            if (ok) compare_line;
        end

        //=============== 3) SR04 : done 으로도 송신이 나가는가 ===============
        mode_sel = MODE_SR04;
        distance = {$random(seed)} % 400;
        build_expect;

        start_capture;
        capture_line(SEND_PER * 2, ok);   // 주기 송신 한 줄 흘려보내고
        start_capture;
        @(negedge clk);
        sr04_done = 1'b1;                 // 측정 완료 펄스
        @(negedge clk);
        sr04_done = 1'b0;
        capture_line(50_000, ok);         // 주기(120k)보다 훨씬 빨리 나와야 한다
        chk(ok === 1'b1, "sr04_done did not trigger a tx");
        if (ok) compare_line;

        //=============== 4) 모드가 아닌 센서의 done 은 무시 ===============
        start_capture;
        @(negedge clk);
        dht_done = 1'b1;                  // SR04 모드인데 DHT done
        @(negedge clk);
        dht_done = 1'b0;
        capture_line(40_000, ok);
        chk(ok === 1'b0, "dht_done triggered a tx while in SR04 mode");

        //=============== 5) DHT11 : done 으로 송신 ===============
        mode_sel    = MODE_DHT11;
        humidity    = {$random(seed)} % 100;
        temperature = {$random(seed)} % 100;
        build_expect;

        start_capture;
        capture_line(SEND_PER * 2, ok);
        start_capture;
        @(negedge clk);
        dht_done = 1'b1;
        @(negedge clk);
        dht_done = 1'b0;
        capture_line(50_000, ok);
        chk(ok === 1'b1, "dht_done did not trigger a tx");
        if (ok) compare_line;

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_uart_comm : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_uart_comm : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #60_000_000;
        $display("  tb_uart_comm : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
