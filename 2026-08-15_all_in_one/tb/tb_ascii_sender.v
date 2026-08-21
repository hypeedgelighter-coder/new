`timescale 1ns / 1ps

//=====================================================================
// tb_ascii_sender  -  ascii_sender 단독 무작위 테스트벤치
//
//  대상 : ascii_sender.v
//
//  send_start 가 들어온 시점의 값을 자리수로 쪼개 래치해 두고, 현재
//  모드에 맞는 문자열을 TX FIFO 로 밀어넣는다.
//    STOPWATCH / WATCH : "HH:MM:SS.mm" + CR LF   13바이트
//    SR04              : "DIST 123cm"  + CR LF   12바이트
//    DHT11             : "H 60% T 25C" + CR LF   13바이트
//
//  [무작위로 만드는 것]
//    1) 모드와 표시값 전부 (시/분/초/밀리초/거리/습도/온도)
//    2) tx_full 백프레셔를 무작위로 걸었다 풀었다 한다
//    3) send_start 를 준 직후 입력값을 통째로 흐트러뜨린다
//       -> 시작 시점 값을 제대로 래치했는지 본다
//
//  [검사]
//    - 나온 바이트열이 기대 문자열과 완전히 같은가 (길이 포함)
//    - tx_full 인 클럭에는 push 가 나가지 않는가
//      (tx_full 을 본 다음 클럭에 push 하면 그 바이트가 FIFO 에서
//       조용히 사라진다. 실제로 "H 60% T 25C" 가 "H 60%T2C" 로 깨졌던
//       버그가 있어서 이 검사를 넣는다)
//    - 문자열이 끝난 뒤에 여분의 바이트를 더 뱉지 않는가
//=====================================================================
module tb_ascii_sender ();

    localparam integer N_RAND = 60;

    localparam [1:0] MODE_STOPWATCH = 2'd0,
                     MODE_WATCH     = 2'd1,
                     MODE_SR04      = 2'd2,
                     MODE_DHT11     = 2'd3;

    localparam [7:0] CR = 8'h0d, LF = 8'h0a;

    reg        clk = 1'b0;
    reg        reset;
    reg  [1:0] mode_sel;
    reg  [6:0] msec;
    reg  [5:0] sec, min;
    reg  [4:0] hour;
    reg  [8:0] distance;
    reg  [7:0] humidity, temperature;
    reg        send_start;
    wire [7:0] tx_data;
    wire       tx_push;
    reg        tx_full;

    reg [7:0] exp_s[0:15];
    integer   exp_len;
    reg [7:0] got_s[0:31];
    integer   n_got;

    integer seed, seed2, seed0;
    integer errors, checks;
    integer i, j, guard;
    reg     monitor_on;
    reg     backpressure_on;

    always #5 clk = ~clk;

    ascii_sender DUT (
        .clk        (clk),
        .reset      (reset),
        .mode_sel   (mode_sel),
        .msec       (msec),
        .sec        (sec),
        .min        (min),
        .hour       (hour),
        .distance   (distance),
        .humidity   (humidity),
        .temperature(temperature),
        .send_start (send_start),
        .tx_data    (tx_data),
        .tx_push    (tx_push),
        .tx_full    (tx_full)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20) $display("  FAIL [%0t] %0s", $time, tag);
            end
        end
    endtask

    //---------------- 나온 바이트 모으기 ----------------
    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            chk(!(tx_push === 1'b1 && tx_full === 1'b1), "push while tx_full");
            if (tx_push) begin
                if (n_got < 32) got_s[n_got] = tx_data;
                n_got = n_got + 1;
            end
        end
    end

    //---------------- tx_full 백프레셔 ----------------
    initial begin : bp_gen
        tx_full = 1'b0;
        forever begin
            @(negedge clk);
            if (backpressure_on) tx_full = (({$random(seed2)} % 3) == 0);
            else                 tx_full = 1'b0;
        end
    end

    //---------------- 기대 문자열 만들기 ----------------
    task build_expect;
        reg [3:0] h10, h1, m10, m1, s10, s1, ms10, ms1;
        reg [3:0] d100, d10, d1, hu10, hu1, te10, te1;
        begin
            h10  = hour / 10;      h1  = hour % 10;
            m10  = min / 10;       m1  = min % 10;
            s10  = sec / 10;       s1  = sec % 10;
            ms10 = (msec / 10) % 10; ms1 = msec % 10;
            d100 = (distance / 100) % 10;
            d10  = (distance / 10) % 10;
            d1   = distance % 10;
            hu10 = (humidity / 10) % 10;   hu1 = humidity % 10;
            te10 = (temperature / 10) % 10; te1 = temperature % 10;

            case (mode_sel)
                MODE_SR04: begin
                    exp_s[0]="D"; exp_s[1]="I"; exp_s[2]="S"; exp_s[3]="T";
                    exp_s[4]=" ";
                    exp_s[5]="0"+d100; exp_s[6]="0"+d10; exp_s[7]="0"+d1;
                    exp_s[8]="c"; exp_s[9]="m";
                    exp_s[10]=CR; exp_s[11]=LF;
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
                default: begin  // HH:MM:SS.mm
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

    task show(input integer n);
        integer p;
        begin
            $write("    got=\"");
            for (p = 0; p < n && p < 32; p = p + 1)
                if (got_s[p] >= 8'h20 && got_s[p] < 8'h7f) $write("%c", got_s[p]);
                else $write(".");
            $write("\"  exp=\"");
            for (p = 0; p < exp_len; p = p + 1)
                if (exp_s[p] >= 8'h20 && exp_s[p] < 8'h7f) $write("%c", exp_s[p]);
                else $write(".");
            $display("\"");
        end
    endtask

    initial begin
        seed0  = 32'h5E4D_0001;
        seed   = seed0;
        seed2  = 32'h2468_ACE0;
        errors = 0;
        checks = 0;
        backpressure_on = 1'b0;

        monitor_on = 1'b0;
        reset      = 1'b1;
        send_start = 1'b0;
        mode_sel   = MODE_STOPWATCH;
        msec = 0; sec = 0; min = 0; hour = 0;
        distance = 0; humidity = 0; temperature = 0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        for (i = 0; i < N_RAND; i = i + 1) begin
            // 앞쪽 절반은 백프레셔 없이, 뒤쪽 절반은 걸어서
            backpressure_on = (i >= N_RAND / 2);

            mode_sel    = {$random(seed)} % 4;
            msec        = {$random(seed)} % 100;
            sec         = {$random(seed)} % 60;
            min         = {$random(seed)} % 60;
            hour        = {$random(seed)} % 24;
            distance    = {$random(seed)} % 512;
            humidity    = {$random(seed)} % 100;
            temperature = {$random(seed)} % 100;
            @(negedge clk);
            build_expect;

            n_got      = 0;
            send_start = 1'b1;
            @(negedge clk);
            send_start = 1'b0;

            // 시작 시점 값을 래치했는지 보려고 곧바로 입력을 흐트러뜨린다
            msec = {$random(seed)} % 100;
            sec  = {$random(seed)} % 60;
            min  = {$random(seed)} % 60;
            hour = {$random(seed)} % 24;
            distance    = {$random(seed)} % 512;
            humidity    = {$random(seed)} % 100;
            temperature = {$random(seed)} % 100;

            // 문자열이 다 나올 때까지
            guard = 0;
            while (n_got < exp_len && guard < 4000) begin
                @(negedge clk);
                guard = guard + 1;
            end
            repeat (40) @(negedge clk);  // 여분이 더 나오는지 확인

            if (n_got != exp_len) begin
                chk(1'b0, "wrong string length");
                show(n_got);
            end else begin
                for (j = 0; j < exp_len; j = j + 1) begin
                    if (got_s[j] !== exp_s[j]) begin
                        chk(1'b0, "string content mismatch");
                        show(n_got);
                        j = exp_len;  // 한 번만 찍는다
                    end else begin
                        chk(1'b1, "ok");
                    end
                end
            end
        end

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_ascii_sender : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_ascii_sender : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #5_000_000;
        $display("  tb_ascii_sender : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
