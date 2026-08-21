`timescale 1ns / 1ps

//=====================================================================
// tb_fnd_display  -  FND 표시 블록 검증
//
//  fnd_com 은 액티브 로우 자리 선택, fnd_data 는 공통애노드 세그먼트
//  (0 이 점등). 자리마다 어떤 숫자가 나오는지 세그먼트 코드로 확인한다.
//
//   com 1110 = 1의 자리   com 1101 = 10의 자리
//   com 1011 = 100의 자리 (여기에 dot 이 붙는다)
//   com 0111 = 1000의 자리
//
//  검사 항목
//   1) 스톱워치 SS.mm 표시
//   2) 시계 HH.MM 표시 + msec 에 따른 콜론 점멸
//   3) SR04 거리 표시 (맨 앞자리 소등)
//   4) DHT11 습도.온도 표시
//   5) 4자리를 돌아가며 스캔하는가
//=====================================================================
module tb_fnd_display ();

    localparam integer P_SCAN = 4;  // 자리당 4클럭

    // 세그먼트 코드 (seg_decoder 와 동일)
    localparam [7:0] S0 = 8'hc0, S1 = 8'hf9, S2 = 8'ha4, S3 = 8'hb0,
                     S4 = 8'h99, S5 = 8'h92, S6 = 8'h82, S9 = 8'h90,
                     SBLANK = 8'hff;

    reg clk, reset;
    reg [1:0] mode_sel;
    reg disp_mode;
    reg [6:0] msec;
    reg [5:0] sec, min;
    reg [4:0] hour;
    reg [8:0] distance;
    reg [7:0] humidity, temperature;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;

    integer err;
    reg seen_0, seen_1, seen_2, seen_3;

    fnd_display #(
        .SCAN_COUNT(P_SCAN)
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

    always #5 clk = ~clk;

    // 스캔 커버리지 확인용
    always @(posedge clk) begin
        case (fnd_com)
            4'b1110: seen_0 = 1'b1;
            4'b1101: seen_1 = 1'b1;
            4'b1011: seen_2 = 1'b1;
            4'b0111: seen_3 = 1'b1;
        endcase
    end

    task ok(input cond);
        begin
            if (cond) $write("  OK   : ");
            else begin
                $write("  FAIL : ");
                err = err + 1;
            end
        end
    endtask

    // 해당 자리가 켜지는 순간의 세그먼트 값을 확인
    task chk_digit(input [3:0] com, input [7:0] expect);
        integer k;
        begin
            k = 0;
            while (fnd_com !== com && k < 200) begin
                @(posedge clk);
                #1;
                k = k + 1;
            end
            if (fnd_data === expect)
                $write("  OK   : (com=%b seg=%h) ", com, fnd_data);
            else begin
                $write("  FAIL : (com=%b seg=%h, 기대=%h) ", com, fnd_data, expect);
                err = err + 1;
            end
        end
    endtask

    initial begin
        clk         = 1'b0;
        reset       = 1'b1;
        mode_sel    = 2'd0;
        disp_mode   = 1'b0;
        msec        = 7'd0;
        sec         = 6'd0;
        min         = 6'd0;
        hour        = 5'd0;
        distance    = 9'd0;
        humidity    = 8'd0;
        temperature = 8'd0;
        err         = 0;
        {seen_0, seen_1, seen_2, seen_3} = 4'b0000;

        repeat (10) @(posedge clk);
        reset = 1'b0;
        repeat (10) @(posedge clk);

        $display("\n===== tb_fnd_display =====");

        //---------------- 1) 스톱워치 SS.mm ----------------
        $display("\n[1] 스톱워치 SS.mm : sec=12 msec=34 -> \"12.34\"");
        mode_sel  = 2'd0;
        disp_mode = 1'b0;
        sec       = 6'd12;
        msec      = 7'd34;
        repeat (5) @(posedge clk);
        chk_digit(4'b0111, S1); $display("1000의 자리 = 1 (sec 십의자리)");
        chk_digit(4'b1011, S2 & 8'h7f); $display("100의 자리 = 2 + dot 점등");
        chk_digit(4'b1101, S3); $display("10의 자리 = 3 (msec 십의자리)");
        chk_digit(4'b1110, S4); $display("1의 자리 = 4");

        //---------------- 2) 시계 HH.MM ----------------
        $display("\n[2] 시계 HH.MM : hour=12 min=34 -> \"12.34\"");
        mode_sel  = 2'd1;
        disp_mode = 1'b1;
        hour      = 5'd12;
        min       = 6'd34;
        msec      = 7'd10;  // 50 미만 -> 콜론 점등
        repeat (5) @(posedge clk);
        chk_digit(4'b0111, S1); $display("1000의 자리 = 1 (hour 십의자리)");
        chk_digit(4'b1011, S2 & 8'h7f); $display("100의 자리 = 2 + 콜론 점등");
        chk_digit(4'b1101, S3); $display("10의 자리 = 3 (min 십의자리)");
        chk_digit(4'b1110, S4); $display("1의 자리 = 4");

        $display("\n[2-2] 콜론 점멸 : msec 이 50 이상이면 꺼진다");
        msec = 7'd60;
        repeat (5) @(posedge clk);
        chk_digit(4'b1011, S2); $display("msec=60 -> dot 소등");

        //---------------- 3) SR04 ----------------
        $display("\n[3] SR04 : distance=123 -> \"_123\"");
        mode_sel = 2'd2;
        distance = 9'd123;
        repeat (5) @(posedge clk);
        chk_digit(4'b0111, SBLANK); $display("맨 앞자리 소등");
        chk_digit(4'b1011, S1); $display("100의 자리 = 1 (dot 없음)");
        chk_digit(4'b1101, S2); $display("10의 자리 = 2");
        chk_digit(4'b1110, S3); $display("1의 자리 = 3");

        //---------------- 4) DHT11 ----------------
        $display("\n[4] DHT11 : 습도60 온도25 -> \"60.25\"");
        mode_sel    = 2'd3;
        humidity    = 8'd60;
        temperature = 8'd25;
        repeat (5) @(posedge clk);
        chk_digit(4'b0111, S6); $display("1000의 자리 = 6 (습도 십의자리)");
        chk_digit(4'b1011, S0 & 8'h7f); $display("100의 자리 = 0 + dot 점등");
        chk_digit(4'b1101, S2); $display("10의 자리 = 2 (온도 십의자리)");
        chk_digit(4'b1110, S5); $display("1의 자리 = 5");

        //---------------- 5) 스캔 ----------------
        $display("\n[5] 4자리를 돌아가며 스캔하는가");
        {seen_0, seen_1, seen_2, seen_3} = 4'b0000;
        repeat (P_SCAN * 8) @(posedge clk);
        ok(seen_0 && seen_1 && seen_2 && seen_3); $display("네 자리 모두 한 번씩 선택됨");

        if (err == 0) $display("\n===== tb_fnd_display : ALL PASS =====\n");
        else $display("\n===== tb_fnd_display : %0d FAIL =====\n", err);
        $finish;
    end

endmodule
