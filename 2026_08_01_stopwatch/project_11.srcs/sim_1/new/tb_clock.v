`timescale 1ns / 1ps

// =====================================================================
// tb_clock : clock(시계) 기능 전용 테스트벤치
//
// 스탑워치/타임어택 쪽은 전혀 건드리지 않고, sw=clock 모드로만 고정한 채
//   1) CLOCK 모드만 켠 상태로 시간이 실제로 흐르는지 확인
//   2) 어느 정도 시간이 지난 뒤 SET MODE(sw[4])에 진입
//   3) btn_L 로 4자리(digit_pos 0~3)를 차례로 이동하면서 각 자리에서
//      btn_U(증가)/btn_D(감소) 를 눌러본다
//   4) SET MODE를 해제하고 다시 CLOCK 모드로 복귀해 시간이 계속 흐르는지 확인
//
// F_COUNT(=1_000_000, 100Hz tick 분주비) 등 시간 관련 파라미터는 전혀
// 줄이거나 늘리지 않고 실제 값 그대로 시뮬레이션한다 (defparam 없음).
// =====================================================================
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

    integer pass_cnt = 0;
    integer fail_cnt = 0;
    reg [6:0] snap_msec;
    reg [5:0] snap_sec;

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

    always #5 clk = ~clk;  // 100MHz 가정

    // btn_debounce는 1MHz(50clk마다 토글)로 8bit shift register를 채워야
    // 눌림을 인정하므로 최소 800clk 이상 눌러야 함 -> 여유있게 1000clk
    localparam HOLD = 1000;

    task automatic press(inout btn);
        begin
            btn = 1'b1;
            repeat (HOLD) @(posedge clk);
            btn = 1'b0;
            repeat (HOLD) @(posedge clk);
        end
    endtask

    task check_eq(input [31:0] actual, input [31:0] expected, input [8*140-1:0] tag);
        begin
            if (actual !== expected) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0t : %0s -> expected=%0d actual=%0d", $time, tag, expected, actual);
            end else begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0t : %0s -> value=%0d", $time, tag, actual);
            end
        end
    endtask

    task check_true(input cond, input [8*140-1:0] tag);
        begin
            if (!cond) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0t : %0s", $time, tag);
            end else begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0t : %0s", $time, tag);
            end
        end
    endtask

    initial begin
        clk   = 0;
        reset = 0;
        btn_L = 0;
        btn_R = 0;
        btn_U = 0;
        btn_D = 0;
        sw    = 5'b00000;

        reset = 1;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        // =====================================================
        // 1) CLOCK 모드만 켠다 (sw[1]=1, 나머지 0 : set_mode/타임어택/저장보기 없음)
        // =====================================================
        sw = 5'b00010;
        repeat (5) @(posedge clk);
        check_eq(uut.w_c_set_mode, 0, "0. CLOCK 모드 진입 직후 set_mode=0");
        check_eq(uut.w_c_digit_pos, 0, "0. CLOCK 모드 진입 직후 digit_pos=0");

        // =====================================================
        // 2) 값은 손대지 않고 시간이 자연스럽게 흐르도록 대기
        //    (F_COUNT=1_000_000 그대로, 100clk*10ns 주기 tick 3회분 이상 대기)
        // =====================================================
        repeat (3_100_000) @(posedge clk);
        check_true(uut.w_c_msec != 0, "1. 시간 경과 후 msec가 0에서 증가함 (clock이 실제로 흐름)");

        // =====================================================
        // 3) SET MODE 진입
        // =====================================================
        sw = 5'b10010;  // sw[4]=set_mode, sw[1]=clock 모드 유지
        repeat (5) @(posedge clk);
        check_eq(uut.w_c_set_mode, 1, "2. SET MODE 진입 확인 (o_set_mode=1)");
        check_eq(led[0], 1, "2. SET MODE 진입 -> led[0]=1");
        check_eq(uut.w_c_digit_pos, 0, "2. SET MODE 진입 직후 digit_pos=0");

        snap_msec = uut.w_c_msec;

        // ---- 자리 0 (msec 1의자리) : U_MSEC_COUNTER는 i_up/i_down이
        //      clock_datapath에서 아예 연결돼있지 않아 값이 바뀌지 않는다 ----
        press(btn_U);
        press(btn_D);
        check_eq(uut.w_c_msec, snap_msec, "3. 자리0(msec) U/D -> msec 미연결이라 값 불변");

        press(btn_L);  // 다음 자리로 이동
        check_eq(uut.w_c_digit_pos, 1, "4. btn_L -> digit_pos=1");

        // ---- 자리 1 (msec 10의자리, 하위필드) : display_mode_ms(sw[0])=0 이라
        //      lower field는 min에 연결되어 있어도 min_up 조건(display_mode=1)이
        //      성립하지 않아 역시 값이 바뀌지 않는다 ----
        press(btn_U);
        press(btn_D);
        check_eq(uut.w_c_msec, snap_msec, "5. 자리1(msec) U/D -> 여전히 msec 불변");

        press(btn_L);
        check_eq(uut.w_c_digit_pos, 2, "6. btn_L -> digit_pos=2");

        // ---- 자리 2 (sec 1의자리, 상위필드 step=1) : sw[0]=0 이면
        //      upper field(digit_pos[1]=1)는 sec에 연결되어 실제로 동작한다 ----
        snap_sec = uut.w_c_sec;
        press(btn_U);
        check_eq(uut.w_c_sec, (snap_sec + 1) % 60, "7. 자리2 btn_U -> sec +1 (step=1)");

        snap_sec = uut.w_c_sec;
        press(btn_D);
        check_eq(uut.w_c_sec, (snap_sec + 59) % 60, "8. 자리2 btn_D -> sec -1 (step=1)");

        press(btn_L);
        check_eq(uut.w_c_digit_pos, 3, "9. btn_L -> digit_pos=3");

        // ---- 자리 3 (sec 10의자리, 상위필드 step=10) ----
        snap_sec = uut.w_c_sec;
        press(btn_U);
        check_eq(uut.w_c_sec, (snap_sec + 10) % 60, "10. 자리3 btn_U -> sec +10 (step=10)");

        snap_sec = uut.w_c_sec;
        press(btn_D);
        check_eq(uut.w_c_sec, (snap_sec + 50) % 60, "11. 자리3 btn_D -> sec -10 (step=10)");

        // =====================================================
        // 4) SET MODE 해제 -> 다시 CLOCK(시간 흐름) 모드로 복귀
        // =====================================================
        sw = 5'b00010;
        repeat (5) @(posedge clk);
        check_eq(uut.w_c_set_mode, 0, "12. SET MODE 해제 확인 (o_set_mode=0)");
        check_eq(led[0], 0, "12. SET MODE 해제 -> led[0]=0");

        snap_msec = uut.w_c_msec;
        repeat (1_100_000) @(posedge clk);  // tick 1회분 이상 대기
        check_true(uut.w_c_msec != snap_msec, "13. SET MODE 해제 후 다시 시간이 흐름");

        $display("==============================================");
        $display(" tb_clock RESULT : PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("==============================================");
        $finish;
    end

endmodule
