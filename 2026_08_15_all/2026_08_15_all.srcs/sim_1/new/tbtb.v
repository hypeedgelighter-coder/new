`timescale 1ns / 1ps

//=====================================================================
// tb_uart_comm_norace  -  tbtb.v 의 레이스 제거판
//
//  원본(tbtb.v)은 자극(rx, reset, sr04_done)을 클럭 엣지와 "똑같은
//  시각"에 바꾸고, 관찰용 always 블록도 posedge 와 같은 시각에 DUT
//  내부 신호를 읽는다. 같은 시각에 일어나는 두 사건의 실행 순서는
//  Verilog 스케줄러가 정하지 않으므로(active region 안의 순서는 미정의)
//  값이 엣지 앞/뒤 중 어느 쪽으로 잡힐지 보장되지 않는다.
//  -> 시뮬레이터/버전에 따라 결과가 달라질 수 있는 레이스.
//
//  이 파일은 모든 구동/샘플링을 엣지에서 DLY(=1ns) 만큼 뒤로 밀어
//  "엣지가 먼저, 값 변화는 그 다음" 순서를 시각으로 못박은 것이다.
//  1ns 는 클럭 주기 10ns 보다 훨씬 짧아 타이밍 자체에는 영향이 없다.
//
//  [변경] 표시가 붙은 곳만 원본과 다르다.
//
//  ※ 모듈 이름을 tb_uart_comm_norace 로 바꿨다. 원본 tbtb.v 와 같은
//    sim fileset 에 두면 모듈명이 겹쳐 elaboration 에러가 나기 때문.
//    시뮬레이션 top 을 tb_uart_comm_norace 로 지정해서 돌리면 된다.
//
//   PC 역할을 TB 가 한다.
//     보낼 때 : rx 선을 직접 흔들어 start/8bit/stop 을 만든다
//     받을 때 : tx 선을 감시해 바이트로 복원한다
//
//   그 사이 uart_comm 내부는 이렇게 흐른다.
//     rx -> uart_rx -> RX_FIFO -> ascii_decoder -> cmd_get
//        -> ascii_sender -> TX_FIFO -> uart_tx -> tx
//   내부 신호도 계층 참조로 같이 찍어서 흐름이 보이게 했다.
//
//   [보드레이트]
//   실제 보드와 같은 9600bps 그대로 돌린다.
//     DIV     = 100MHz / (9600*16) = 651 클럭
//     1비트   = 651 * 16 * 10ns    = 104,160ns
//     1바이트 = 10비트 (start+8+stop) = 1.04ms
//     7바이트 문자열                 = 7.3ms
//   전체 시뮬이 ~90ms (900만 클럭) 라 실행에 수십 초 걸린다.
//=====================================================================
module tb_uart_comm_norace;

    localparam SYS_CLK = 100_000_000;
    localparam BAUD    = 9600;

    // baud_tick_gen 과 똑같이 계산해서 TB 의 비트 폭을 하드웨어에 맞춘다.
    // 1e9/BAUD (=104,166) 로 하면 하드웨어(104,160)와 6ns 씩 어긋나므로
    // 분주비에서 거꾸로 뽑는다.
    localparam DIV    = SYS_CLK / (BAUD * 16);      // 651
    localparam CLK_NS = 1_000_000_000 / SYS_CLK;    // 10
    localparam BIT_NS = DIV * 16 * CLK_NS;          // 104,160

    // [변경] 추가. 엣지에서 얼마나 뒤로 밀어 구동/샘플링할지.
    //        실물의 clock-to-out 지연 자리라고 보면 된다.
    //        0 < DLY < 클럭 반주기(5ns) 면 어떤 값이든 동작은 같다.
    localparam DLY = 1;

    reg clk = 0, reset = 1;
    reg rx = 1;  // UART 유휴 상태는 high
    wire tx;

    // 표시값 (datapath 대신 TB 가 직접 준다)
    reg [1:0] mode_sel = 2'd1;
    reg       disp_mode = 1'b1;
    reg [6:0] msec = 0;
    reg [5:0] sec = 0, min = 0;
    reg [4:0] hour = 0;
    reg [8:0] distance = 0;
    reg [7:0] humidity = 0, temperature = 0;
    reg       sr04_done = 0, dht_done = 0;

    wire cmd_run, cmd_stop, cmd_clear, cmd_mode;
    wire cmd_up, cmd_down, cmd_left, cmd_right;
    wire cmd_sel_s, cmd_sel_m, cmd_sel_h, cmd_start;

    integer errors = 0;

    uart_comm #(
        .SYS_CLK(SYS_CLK),
        .BAUD   (BAUD),
        .AWIDTH (3)
    ) DUT (
        .clk(clk), .reset(reset),
        .rx (rx),  .tx   (tx),

        .cmd_run(cmd_run), .cmd_stop(cmd_stop), .cmd_clear(cmd_clear),
        .cmd_mode(cmd_mode), .cmd_up(cmd_up), .cmd_down(cmd_down),
        .cmd_left(cmd_left), .cmd_right(cmd_right),
        .cmd_sel_s(cmd_sel_s), .cmd_sel_m(cmd_sel_m), .cmd_sel_h(cmd_sel_h),
        .cmd_start(cmd_start),

        .mode_sel(mode_sel), .disp_mode(disp_mode),
        .msec(msec), .sec(sec), .min(min), .hour(hour),
        .distance(distance), .humidity(humidity), .temperature(temperature),

        .sr04_done(sr04_done), .dht_done(dht_done)
    );

    always #5 clk = ~clk;  // 100MHz

    //=================================================================
    // PC -> FPGA : rx 선을 직접 흔든다
    //=================================================================
    task pc_send;
        input [7:0] b;
        integer i;
        begin
            $display("  [%7.1fus] PC ->  '%c' (0x%02h) 송신", $time/1000.0, b, b);
            // [변경] 원본은 호출된 시각에 바로 rx 를 내렸다. 그 시각이
            //        마침 클럭 엣지면 DUT 의 rx 샘플링과 경쟁이 된다.
            //        여기서 한 번 엣지에 정렬한 뒤 DLY 만큼 밀어 놓으면,
            //        BIT_NS(104,160ns) 가 클럭주기 10ns 의 정수배라
            //        이후 모든 비트 경계도 자동으로 "엣지+DLY" 에 선다.
            @(negedge clk);
            #(DLY);
            rx = 1'b0;                       // start bit
            #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin  // LSB first
                rx = b[i];
                #(BIT_NS);
            end
            rx = 1'b1;                       // stop bit
            #(BIT_NS);
        end
    endtask

    //=================================================================
    // FPGA -> PC : tx 선을 감시해 바이트로 복원
    //=================================================================
    reg [7:0] rxbuf[0:31];
    integer   nrx = 0;

    reg [7:0] mon_b;
    integer   mon_i;
    initial begin
        forever begin
            @(negedge tx);                   // start bit 검출
            // [변경] +DLY. tx 는 posedge clk 에서 바뀌므로 원본의 샘플
            //        시각(하강엣지 +1.5비트)은 정확히 클럭 엣지 위에
            //        떨어진다. DLY 만큼 밀어 엣지를 피해서 읽는다.
            #(BIT_NS + BIT_NS / 2 + DLY);    // bit0 한가운데로
            for (mon_i = 0; mon_i < 8; mon_i = mon_i + 1) begin
                mon_b[mon_i] = tx;
                #(BIT_NS);
            end
            rxbuf[nrx] = mon_b;
            nrx = nrx + 1;
            if (mon_b == 8'h0d) $display("  [%7.1fus] PC <-  CR", $time/1000.0);
            else if (mon_b == 8'h0a) $display("  [%7.1fus] PC <-  LF", $time/1000.0);
            else $display("  [%7.1fus] PC <-  '%c' (0x%02h)", $time/1000.0, mon_b, mon_b);
        end
    end

    //=================================================================
    // 내부 흐름 관찰 (계층 참조)
    //=================================================================
    // tx_full 은 수천 클럭 동안 계속 1 이라 엣지에서만 찍는다
    reg full_d = 0;
    // [변경] #(DLY) 추가. 엣지와 같은 시각에 읽으면 그 엣지에서 갱신되기
    //        "전" 값을 볼지 "후" 값을 볼지가 모호하다(계층 참조라 더 위험).
    //        DLY 뒤에 읽으면 항상 이번 엣지의 결과를 본다.
    always @(posedge clk) begin
        #(DLY);
        full_d <= DUT.w_tx_full;
    end

    // [변경] 위와 같은 이유로 #(DLY) 추가.
    //        블록이 1ns 만 잡아먹으므로 10ns 주기의 다음 엣지를 놓치지 않는다.
    always @(posedge clk) begin
        #(DLY);
        if (DUT.w_cmd_get)
            $display("  [%7.1fus]   .. decoder: cmd_get 펄스", $time/1000.0);
        if (DUT.w_send_start)
            $display("  [%7.1fus]   .. sender : send_start -> 문자열 래치", $time/1000.0);
        if (DUT.w_tx_push && !DUT.w_tx_full)
            $display("  [%7.1fus]   .. sender : TX FIFO <- 0x%02h", $time/1000.0, DUT.w_tx_data);
        if (DUT.w_tx_full && !full_d)
            $display("  [%7.1fus]   .. TX FIFO FULL  -> sender 정지", $time/1000.0);
        if (!DUT.w_tx_full && full_d)
            $display("  [%7.1fus]   .. TX FIFO 여유   -> sender 재개", $time/1000.0);
    end

    // 명령 펄스 관찰
    // [변경] #(DLY) 추가. cmd_* 는 DUT 안에서 posedge 에 뜨는 1클럭 펄스라
    //        같은 시각에 읽으면 한 클럭 전 값을 보게 될 수 있다.
    always @(posedge clk) begin
        #(DLY);
        if (cmd_run)   $display("  [%7.1fus]   => cmd_run",   $time/1000.0);
        if (cmd_stop)  $display("  [%7.1fus]   => cmd_stop",  $time/1000.0);
        if (cmd_clear) $display("  [%7.1fus]   => cmd_clear", $time/1000.0);
        if (cmd_mode)  $display("  [%7.1fus]   => cmd_mode",  $time/1000.0);
        if (cmd_up)    $display("  [%7.1fus]   => cmd_up",    $time/1000.0);
        if (cmd_down)  $display("  [%7.1fus]   => cmd_down",  $time/1000.0);
        if (cmd_left)  $display("  [%7.1fus]   => cmd_left",  $time/1000.0);
        if (cmd_right) $display("  [%7.1fus]   => cmd_right", $time/1000.0);
        if (cmd_sel_s) $display("  [%7.1fus]   => cmd_sel_s", $time/1000.0);
        if (cmd_sel_m) $display("  [%7.1fus]   => cmd_sel_m", $time/1000.0);
        if (cmd_sel_h) $display("  [%7.1fus]   => cmd_sel_h", $time/1000.0);
        if (cmd_start) $display("  [%7.1fus]   => cmd_start", $time/1000.0);
    end

    //=================================================================
    // 받은 문자열 확인
    //=================================================================
    task check;
        input [8*24-1:0] name;
        input [8*8-1:0]  exp;
        input integer    explen;
        integer k;
        reg [7:0] e;
        reg ok;
        begin
            ok = (nrx == explen);
            for (k = 0; k < explen; k = k + 1) begin
                e = exp[8*(explen-1-k) +: 8];
                if (rxbuf[k] !== e) ok = 0;
            end
            $write("      받은 문자열 [%0d바이트] \"", nrx);
            for (k = 0; k < nrx; k = k + 1) begin
                if (rxbuf[k] == 8'h0d) $write("\\r");
                else if (rxbuf[k] == 8'h0a) $write("\\n");
                else $write("%c", rxbuf[k]);
            end
            $write("\"\n");
            if (ok) $display("  PASS  %0s", name);
            else begin
                $display("  FAIL  %0s", name);
                errors = errors + 1;
            end
            $display("");
        end
    endtask

    task pulse_sr04;
        begin
            // [변경] 각 엣지 뒤 DLY 에서 값을 바꾼다. 원본처럼 negedge 와
            //        같은 시각에 바꾸면 DUT 가 보는 값이 모호해진다.
            //        negedge+DLY ~ 다음 negedge+DLY 구간이 posedge 하나를
            //        정확히 덮으므로 1클럭 펄스인 것도 그대로 유지된다.
            @(negedge clk); #(DLY); sr04_done = 1;
            @(negedge clk); #(DLY); sr04_done = 0;
        end
    endtask

    //=================================================================
    initial begin
        $display("");
        $display("==================================================");
        $display("  tb_uart_comm_norace   baud=%0d  1bit=%0dns", BAUD, BIT_NS);
        $display("==================================================");

        // [변경] reset 해제도 엣지 뒤 DLY 로 민다. 여기서 한 번 밀어 두면
        //        아래 자극들이 전부 "엣지+DLY" 격자 위에서 움직인다.
        repeat (10) @(negedge clk);
        #(DLY);
        reset = 0;
        repeat (10) @(negedge clk);
        #(DLY);

        //--------------------------------------------------------
        $display("");
        $display("[1] 시계 모드에서 'g' 요청  (12시 34분)");
        mode_sel = 2'd1; disp_mode = 1; hour = 12; min = 34;
        nrx = 0;
        pc_send("g");
        #(BIT_NS * 100);
        check("WATCH 'g' -> 12:34", {"12:34", 8'h0d, 8'h0a}, 7);

        //--------------------------------------------------------
        $display("[2] 스톱워치 표기로 'G' 요청  (56.78)");
        disp_mode = 0; sec = 56; msec = 78;
        nrx = 0;
        pc_send("G");            // 대문자도 받는다
        #(BIT_NS * 100);
        check("WATCH 'G' -> 56.78", {"56.78", 8'h0d, 8'h0a}, 7);

        //--------------------------------------------------------
        $display("[3] 명령 문자들 : 'r' 'U' 'H'  (송신 없음)");
        nrx = 0;
        pc_send("r");
        pc_send("U");
        pc_send("H");
        #(BIT_NS * 20);
        if (nrx == 0) $display("  PASS  명령 문자에는 응답 없음");
        else begin
            $display("  FAIL  명령 문자에 %0d바이트 응답", nrx);
            errors = errors + 1;
        end
        $display("");

        //--------------------------------------------------------
        $display("[4] 매핑 안 된 문자 'x' -> 조용히 버림");
        nrx = 0;
        pc_send("x");
        #(BIT_NS * 20);
        if (nrx == 0) $display("  PASS  'x' 무시됨");
        else begin
            $display("  FAIL  'x' 에 응답이 나옴");
            errors = errors + 1;
        end
        $display("");

        //--------------------------------------------------------
        $display("[5] SR04 모드에서 측정 완료 -> 자동 송신 (123cm)");
        mode_sel = 2'd2; distance = 123;
        nrx = 0;
        pulse_sr04;
        #(BIT_NS * 100);
        check("SR04 done -> 123", {"123", 8'h0d, 8'h0a}, 5);

        //--------------------------------------------------------
        $display("[6] DHT11 모드에서 'g' 요청  (습도60 온도25)");
        mode_sel = 2'd3; humidity = 60; temperature = 25;
        nrx = 0;
        pc_send("g");
        #(BIT_NS * 100);
        check("DHT11 'g' -> 60 25", {"60 25", 8'h0d, 8'h0a}, 7);

        //--------------------------------------------------------
        // sender 는 FIFO 에 밀어넣기만 하면 (7클럭) 바로 IDLE 로 돌아온다.
        // 그래서 'g' 가 1.04ms 간격으로 와도 대부분 다 접수된다.
        // 다만 FIFO 가 16칸뿐이라 3줄(21바이트)은 안 들어가서, 중간에
        // tx_full 이 걸려 sender 가 문자열 도중에 멈췄다 재개한다.
        // 그래도 문자열이 안 깨지는지가 이 테스트의 목적이다.
        $display("[7] 'g' 연타 : FIFO full 을 넘겨도 문자열이 안 깨지는가");
        mode_sel = 2'd1; disp_mode = 1; hour = 23; min = 59;
        nrx = 0;
        pc_send("g");
        pc_send("g");            // 첫 응답이 나가는 중에 도착
        pc_send("g");
        #(BIT_NS * 300);
        $write("      받은 문자열 [%0d바이트] \"", nrx);
        begin : dump
            integer k;
            for (k = 0; k < nrx; k = k + 1) begin
                if (rxbuf[k] == 8'h0d) $write("\\r");
                else if (rxbuf[k] == 8'h0a) $write("\\n");
                else $write("%c", rxbuf[k]);
            end
        end
        $write("\"\n");
        $display("  INFO  'g' 3번에 %0d바이트 (7의 배수면 문자열이 안 깨진 것)",
                 nrx);
        if (nrx % 7 == 0 && nrx > 0) $display("  PASS  문자열 경계 유지");
        else begin
            $display("  FAIL  문자열이 깨졌다");
            errors = errors + 1;
        end
        $display("");

        //--------------------------------------------------------
        $display("==================================================");
        if (errors == 0) $display("  ALL PASS");
        else $display("  %0d FAIL", errors);
        $display("==================================================");
        $display("");
        $finish;
    end

    // 안전장치 (9600bps 라 전체가 ~90ms. 넉넉히 300ms)
    initial begin
        #300_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
