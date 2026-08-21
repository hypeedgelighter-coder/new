`timescale 1ns / 1ps

// clock 전용 TB : 100MHz 기준, 1ms = 100,000 clk
//   sw[0] : 0 = msec·sec 화면 / 1 = min·hour 화면
//   sw[1] : 1 = clock 화면
//   sw[4] : 1 = SET MODE
//
//   1) clock 모드로 시간이 흐르게 대기
//   2) SET MODE 진입 -> 시계가 멈추는지 확인
//   3) msec·sec 화면에서 자리 0~3 조정
//   4) min·hour 화면으로 바꿔서 자리 0~3 조정
//   5) 다시 min, sec 로 돌아가 재조정
//   6) SET MODE 해제 -> 맞춘 값에서 이어서 흐르는지 확인
//
// 버튼은 10ms 누르고 5ms 뗀다. btn_debounce 판정 시간보다 길어야 반응이 나온다.
// 파형에 추가할 신호 : w_tick_100hz, w_c_set_mode, w_c_digit_pos,
//                     w_c_msec, w_c_sec, w_c_min, w_c_hour
module tb_clock ();

    reg         clk;
    reg         reset;
    reg         btn_L;
    reg         btn_R;
    reg         btn_U;
    reg         btn_D;
    reg  [ 4:0] sw;
    wire [ 3:0] fnd_com;
    wire [ 7:0] fnd_data;
    wire [15:0] led;

    top_stopwatch_clock uut (
        .clk     (clk),
        .reset   (reset),
        .btn_L   (btn_L),
        .btn_R   (btn_R),
        .btn_U   (btn_U),
        .btn_D   (btn_D),
        .sw      (sw),
        .fnd_com (fnd_com),
        .fnd_data(fnd_data),
        .led     (led)
    );

    always #5 clk = ~clk;  // 100MHz

    initial begin
        clk   = 0;
        reset = 0;
        btn_L = 0;
        btn_R = 0;
        btn_U = 0;
        btn_D = 0;
        sw    = 5'b00000;

        reset = 1;
        repeat (10) @(posedge clk);
        reset = 0;
        repeat (10) @(posedge clk);

        // ---------- 1) clock 모드, 30ms 대기 : 시간이 흐른다 ----------
        sw = 5'b00010;
        repeat (3_000_000) @(posedge clk);

        // ---------- 2) SET MODE 진입, 30ms 대기 : 시간이 멈춘다 ----------
        sw = 5'b10010;
        repeat (3_000_000) @(posedge clk);

        // ================= 3) msec·sec 화면 (sw[0]=0) =================

        // 자리 0 : msec, 1씩
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);
        btn_L = 1;
        repeat (1_000_000) @(posedge clk);
        btn_L = 0;
        repeat (500_000) @(posedge clk);

        // 자리 1 : msec, 10씩
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);
        btn_L = 1;
        repeat (1_000_000) @(posedge clk);
        btn_L = 0;
        repeat (500_000) @(posedge clk);

        // 자리 2 : sec, 1씩
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);
        btn_L = 1;
        repeat (1_000_000) @(posedge clk);
        btn_L = 0;
        repeat (500_000) @(posedge clk);

        // 자리 3 : sec, 10씩
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);

        // 자리 3에서 btn_L 한 번 더 : 더 이동하지 않는지 확인
        btn_L = 1;
        repeat (1_000_000) @(posedge clk);
        btn_L = 0;
        repeat (500_000) @(posedge clk);

        // ================= 4) min·hour 화면으로 전환 (sw[0]=1) =================
        sw = 5'b10011;
        repeat (200_000) @(posedge clk);

        // 자리 3 -> 0 으로 되돌리기
        btn_R = 1;
        repeat (1_000_000) @(posedge clk);
        btn_R = 0;
        repeat (500_000) @(posedge clk);
        btn_R = 1;
        repeat (1_000_000) @(posedge clk);
        btn_R = 0;
        repeat (500_000) @(posedge clk);
        btn_R = 1;
        repeat (1_000_000) @(posedge clk);
        btn_R = 0;
        repeat (500_000) @(posedge clk);

        // 자리 0 : min, 1씩
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);
        btn_L = 1;
        repeat (1_000_000) @(posedge clk);
        btn_L = 0;
        repeat (500_000) @(posedge clk);

        // 자리 1 : min, 10씩
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);
        btn_L = 1;
        repeat (1_000_000) @(posedge clk);
        btn_L = 0;
        repeat (500_000) @(posedge clk);

        // 자리 2 : hour, 1씩
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);
        btn_L = 1;
        repeat (1_000_000) @(posedge clk);
        btn_L = 0;
        repeat (500_000) @(posedge clk);

        // 자리 3 : hour, 10씩
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);

        // ================= 5) 다시 min, 그리고 sec 재조정 =================

        // 자리 3 -> 1 : min 10의 자리로 되돌아가서 다시 조정
        btn_R = 1;
        repeat (1_000_000) @(posedge clk);
        btn_R = 0;
        repeat (500_000) @(posedge clk);
        btn_R = 1;
        repeat (1_000_000) @(posedge clk);
        btn_R = 0;
        repeat (500_000) @(posedge clk);

        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);

        // 화면만 msec·sec 로 되돌리고 (자리는 1 그대로 유지) sec 자리로 이동
        sw = 5'b10010;
        repeat (200_000) @(posedge clk);

        btn_L = 1;
        repeat (1_000_000) @(posedge clk);
        btn_L = 0;
        repeat (500_000) @(posedge clk);

        // 자리 2 : sec, 1씩 재조정
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_U = 1;
        repeat (1_000_000) @(posedge clk);
        btn_U = 0;
        repeat (500_000) @(posedge clk);
        btn_D = 1;
        repeat (1_000_000) @(posedge clk);
        btn_D = 0;
        repeat (500_000) @(posedge clk);

        // ---------- 6) SET MODE 해제, 30ms 대기 : 맞춘 값에서 다시 흐른다 ----------
        sw = 5'b00010;
        repeat (3_000_000) @(posedge clk);


    end

endmodule
