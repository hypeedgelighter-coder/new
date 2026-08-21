`timescale 1ns / 1ps

// =====================================================================
// 이 파일은 3개의 독립적인 테스트벤치 최상위 모듈을 담고 있습니다.
// Vivado에서는 시뮬레이션 1회에 top이 1개만 가능하므로,
// sim_1 소스에 추가한 뒤 실행하려는 테스트벤치를 "Set as Top" 해서 사용하세요.
//
//   [1/3] tb_control_unit_2        : control_unit_2.v (타임어택 FSM) 단위 테스트
//   [2/3] tb_clock_control_unit    : clock_control_unit.v 단위 테스트
//   [3/3] tb_top_stopwatch_clock   : top_stopwatch_clock.v 전체 통합 테스트
//
// 모든 테스트는 자체 판정(self-checking) 방식이며, 각 테스트 케이스마다
// [PASS]/[FAIL] 을 콘솔에 출력하고 마지막에 PASS/FAIL 총계를 보여줍니다.
// =====================================================================


// #######################################################################
// [1/3] TESTBENCH : control_unit_2 (타임어택 상태머신)
// #######################################################################
module tb_control_unit_2;

    localparam STOP = 0, UP = 1, DOWN = 2, BESIDE = 3, START = 4, DONE = 5;

    reg clk, reset;
    reg i_up, i_down, i_beside, i_start, i_zero;
    wire o_up, o_down, o_beside, o_start;
    wire [1:0] o_digit_cho;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    control_unit2 dut (
        .clk        (clk),
        .reset      (reset),
        .i_up       (i_up),
        .i_down     (i_down),
        .i_beside   (i_beside),
        .i_start    (i_start),
        .i_zero     (i_zero),
        .o_up       (o_up),
        .o_down     (o_down),
        .o_beside   (o_beside),
        .o_start    (o_start),
        .o_digit_cho(o_digit_cho)
    );

    always #5 clk = ~clk;

    task check_state(input [2:0] expected, input [8*100-1:0] tag);
        begin
            if (dut.c_state !== expected) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0t : %0s -> state expected=%0d actual=%0d", $time, tag, expected, dut.c_state);
            end else begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0t : %0s -> state=%0d", $time, tag, dut.c_state);
            end
        end
    endtask

    task check_bit(input actual, input expected, input [8*100-1:0] tag);
        begin
            if (actual !== expected) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0t : %0s -> expected=%0b actual=%0b", $time, tag, expected, actual);
            end else begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0t : %0s -> value=%0b", $time, tag, actual);
            end
        end
    endtask

    task check_val(input [1:0] actual, input [1:0] expected, input [8*100-1:0] tag);
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

    initial begin
        clk = 0; reset = 0;
        i_up = 0; i_down = 0; i_beside = 0; i_start = 0; i_zero = 0;

        // ---- T1 : 비동기 reset ----
        reset = 1;
        @(posedge clk); #1;
        check_state(STOP, "T1 reset -> STOP");
        check_bit(o_up, 1'b0, "T1 o_up=0");
        check_bit(o_down, 1'b0, "T1 o_down=0");
        check_bit(o_beside, 1'b0, "T1 o_beside=0");
        check_bit(o_start, 1'b0, "T1 o_start=0");
        check_val(o_digit_cho, 2'b00, "T1 o_digit_cho=0");
        reset = 0;
        @(posedge clk); #1;
        check_state(STOP, "T1 reset 해제 후에도 STOP 유지");

        // ---- T2 : STOP + i_up -> UP -> STOP ----
        // 이 FSM은 출력을 c_state의 case 블록 안에서 "다음 클럭에 반영될 값"으로
        // 계산하므로, o_up 등의 펄스는 실제로 UP 상태보다 1클럭 늦게(=STOP 복귀 시점에) 나타남
        i_up = 1;
        @(posedge clk); #1;
        check_state(UP, "T2 STOP+i_up -> UP");
        check_bit(o_up, 1'b0, "T2 UP 진입 직후 o_up은 아직 0 (1클럭 지연)");
        i_up = 0;
        @(posedge clk); #1;
        check_state(STOP, "T2 UP -> STOP 자동복귀");
        check_bit(o_up, 1'b1, "T2 o_up pulse=1 (지연되어 나타남)");
        @(posedge clk); #1;
        check_bit(o_up, 1'b0, "T2 o_up pulse 종료");

        // ---- T3 : STOP + i_down -> DOWN -> STOP ----
        i_down = 1;
        @(posedge clk); #1;
        check_state(DOWN, "T3 STOP+i_down -> DOWN");
        check_bit(o_down, 1'b0, "T3 DOWN 진입 직후 o_down 아직 0");
        i_down = 0;
        @(posedge clk); #1;
        check_state(STOP, "T3 DOWN -> STOP 자동복귀");
        check_bit(o_down, 1'b1, "T3 o_down pulse=1");
        @(posedge clk); #1;
        check_bit(o_down, 1'b0, "T3 o_down pulse 종료");

        // ---- T4 : STOP + i_beside 4번 -> digit_cho 0->1->2->3->0 wrap ----
        repeat (4) begin
            i_beside = 1;
            @(posedge clk); #1;
            check_state(BESIDE, "T4 STOP+i_beside -> BESIDE");
            i_beside = 0;
            @(posedge clk); #1;
            check_state(STOP, "T4 BESIDE -> STOP 자동복귀");
            check_bit(o_beside, 1'b1, "T4 o_beside pulse=1");
            @(posedge clk); #1;
            check_bit(o_beside, 1'b0, "T4 o_beside pulse 종료");
        end
        check_val(o_digit_cho, 2'b00, "T4 4번 눌러 digit_cho가 0->1->2->3->0 로 wrap");

        // ---- T5 : STOP + i_start -> START, o_start 유지 ----
        i_start = 1;
        @(posedge clk); #1;
        check_state(START, "T5 STOP+i_start -> START");
        check_bit(o_start, 1'b0, "T5 START 진입 직후 o_start 아직 0 (1클럭 지연)");
        i_start = 0;
        @(posedge clk); #1;
        check_state(START, "T5 START 유지 (i_zero/i_start 없음)");
        check_bit(o_start, 1'b1, "T5 o_start=1 로 올라옴 (카운트다운 enable)");
        @(posedge clk); #1;
        check_state(START, "T5 START 계속 유지");
        check_bit(o_start, 1'b1, "T5 o_start=1 계속 유지");

        // ---- T6 : START + i_zero -> DONE -> STOP 자동복귀 ----
        i_zero = 1;
        @(posedge clk); #1;
        check_state(DONE, "T6 START+i_zero -> DONE");
        check_bit(o_start, 1'b1, "T6 DONE 진입 직후 o_start 아직 1 (1클럭 지연)");
        i_zero = 0;
        @(posedge clk); #1;
        check_state(STOP, "T6 DONE -> STOP 자동복귀");
        check_bit(o_start, 1'b0, "T6 o_start=0 으로 내려감");

        // ---- T7 : START 중 i_start 재입력 -> STOP (start/stop 토글) ----
        i_start = 1;
        @(posedge clk); #1;
        check_state(START, "T7 STOP+i_start -> START");
        i_start = 0;
        @(posedge clk); #1;
        check_state(START, "T7 START 유지");
        check_bit(o_start, 1'b1, "T7 o_start=1 (카운트다운 중)");
        i_start = 1; // 두번째 start 입력 (정지 의도)
        @(posedge clk); #1;
        check_state(STOP, "T7 START 중 i_start -> STOP (토글 정지)");
        i_start = 0;
        @(posedge clk); #1;
        check_bit(o_start, 1'b0, "T7 STOP 복귀 후 o_start=0");

        // ---- T8 : STOP 상태 입력 우선순위 (i_up > i_down > i_beside > i_start) ----
        i_up = 1; i_down = 1; i_beside = 1; i_start = 1;
        @(posedge clk); #1;
        check_state(UP, "T8 모든 입력 동시 -> i_up 우선 -> UP");
        i_up = 0; i_down = 0; i_beside = 0; i_start = 0;
        @(posedge clk); #1;
        check_state(STOP, "T8 UP -> STOP 자동복귀");

        i_down = 1; i_beside = 1; i_start = 1;
        @(posedge clk); #1;
        check_state(DOWN, "T8 i_up=0, 나머지 동시 -> i_down 우선 -> DOWN");
        i_down = 0; i_beside = 0; i_start = 0;
        @(posedge clk); #1;
        check_state(STOP, "T8 DOWN -> STOP 자동복귀");

        i_beside = 1; i_start = 1;
        @(posedge clk); #1;
        check_state(BESIDE, "T8 i_beside,i_start 동시 -> i_beside 우선 -> BESIDE");
        i_beside = 0; i_start = 0;
        @(posedge clk); #1;
        check_state(STOP, "T8 BESIDE -> STOP 자동복귀");

        i_start = 1;
        @(posedge clk); #1;
        check_state(START, "T8 i_start만 -> START");
        i_start = 0;
        @(posedge clk); #1;
        check_state(START, "T8 START 유지");

        // ---- T9 : 동작(START) 중 비동기 reset ----
        reset = 1;
        #1;
        check_state(STOP, "T9 START 중 비동기 reset -> 즉시 STOP");
        check_bit(o_start, 1'b0, "T9 reset 직후 o_start=0 즉시");
        reset = 0;
        @(posedge clk); #1;
        check_bit(o_start, 1'b0, "T9 reset 해제 후에도 o_start=0");

        // ---- T10 : DONE 상태는 i_start 외 다른 입력을 무시하고 무조건 STOP으로 감 ----
        i_start = 1;
        @(posedge clk); #1;
        check_state(START, "T10 STOP+i_start -> START");
        i_start = 0;
        i_zero = 1;
        @(posedge clk); #1;
        check_state(DONE, "T10 START+i_zero -> DONE");
        i_zero = 0;
        i_up = 1; i_down = 1; i_beside = 1; // DONE에서는 전부 무시되어야 함
        @(posedge clk); #1;
        check_state(STOP, "T10 DONE은 i_up/i_down/i_beside 무시하고 무조건 STOP");
        i_up = 0; i_down = 0; i_beside = 0;

        $display("==============================================");
        $display(" [1/3] tb_control_unit_2 RESULT : PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("==============================================");
        $finish;
    end

endmodule


// #######################################################################
// [2/3] TESTBENCH : clock_control_unit
// #######################################################################
module tb_clock_control_unit;

    reg clk, reset;
    reg i_set_mode, i_left, i_right, i_up, i_down;
    wire o_set_mode;
    wire [1:0] o_digit_pos;
    wire o_up, o_down;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    clock_control_unit dut (
        .clk       (clk),
        .reset     (reset),
        .i_set_mode(i_set_mode),
        .i_left    (i_left),
        .i_right   (i_right),
        .i_up      (i_up),
        .i_down    (i_down),
        .o_set_mode(o_set_mode),
        .o_digit_pos(o_digit_pos),
        .o_up      (o_up),
        .o_down    (o_down)
    );

    always #5 clk = ~clk;

    task check_pos(input [1:0] expected, input [8*100-1:0] tag);
        begin
            if (o_digit_pos !== expected) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0t : %0s -> expected=%0d actual=%0d", $time, tag, expected, o_digit_pos);
            end else begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0t : %0s -> pos=%0d", $time, tag, o_digit_pos);
            end
        end
    endtask

    task check_bit2(input actual, input expected, input [8*100-1:0] tag);
        begin
            if (actual !== expected) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0t : %0s -> expected=%0b actual=%0b", $time, tag, expected, actual);
            end else begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0t : %0s -> value=%0b", $time, tag, actual);
            end
        end
    endtask

    initial begin
        clk = 0; reset = 0;
        i_set_mode = 0; i_left = 0; i_right = 0; i_up = 0; i_down = 0;

        // ---- T1 : reset -> digit_pos=0 ----
        reset = 1;
        @(posedge clk); #1;
        check_pos(2'd0, "T1 reset -> digit_pos=0");
        check_bit2(o_set_mode, 1'b0, "T1 o_set_mode=0");
        reset = 0;
        @(posedge clk); #1;

        // ---- T2 : set_mode=0 이면 left/right로 자리 이동 불가 ----
        i_left = 1;
        @(posedge clk); #1;
        check_pos(2'd0, "T2 set_mode=0, i_left -> 이동 없음");
        i_left = 0;
        i_right = 1;
        @(posedge clk); #1;
        check_pos(2'd0, "T2 set_mode=0, i_right -> 이동 없음");
        i_right = 0;

        // ---- T3 : set_mode=0 이면 o_up/o_down 항상 0 ----
        i_up = 1; i_down = 1;
        @(posedge clk); #1;
        check_bit2(o_up, 1'b0, "T3 set_mode=0 -> o_up=0");
        check_bit2(o_down, 1'b0, "T3 set_mode=0 -> o_down=0");
        i_up = 0; i_down = 0;
        @(posedge clk); #1;

        // ---- T4 : set_mode=1, i_left 반복 -> 0,1,2,3 에서 포화 ----
        i_set_mode = 1;
        @(posedge clk); #1;
        check_bit2(o_set_mode, 1'b1, "T4 o_set_mode=1");

        i_left = 1;
        @(posedge clk); #1; check_pos(2'd1, "T4 left 1회 -> pos=1");
        @(posedge clk); #1; check_pos(2'd2, "T4 left 2회 -> pos=2");
        @(posedge clk); #1; check_pos(2'd3, "T4 left 3회 -> pos=3");
        @(posedge clk); #1; check_pos(2'd3, "T4 left 4회 -> 포화, 여전히 pos=3");
        i_left = 0;
        @(posedge clk); #1;

        // ---- T5 : set_mode=1, i_right 반복 -> 3,2,1,0 에서 포화 ----
        i_right = 1;
        @(posedge clk); #1; check_pos(2'd2, "T5 right 1회 -> pos=2");
        @(posedge clk); #1; check_pos(2'd1, "T5 right 2회 -> pos=1");
        @(posedge clk); #1; check_pos(2'd0, "T5 right 3회 -> pos=0");
        @(posedge clk); #1; check_pos(2'd0, "T5 right 4회 -> 포화, 여전히 pos=0");
        i_right = 0;
        @(posedge clk); #1;

        // ---- T6 : set_mode=1, i_left와 i_right 동시 -> i_left 우선 ----
        i_left = 1; @(posedge clk); #1; i_left = 0; @(posedge clk); #1; // pos=1
        i_left = 1; i_right = 1;
        @(posedge clk); #1;
        check_pos(2'd2, "T6 left&right 동시 -> left 우선 -> pos 증가");
        i_left = 0; i_right = 0;
        @(posedge clk); #1;

        // ---- T7 : set_mode=1, i_up/i_down passthrough ----
        i_up = 1;
        @(posedge clk); #1;
        check_bit2(o_up, 1'b1, "T7 set_mode=1,i_up=1 -> o_up=1 통과");
        i_up = 0;
        @(posedge clk); #1;
        check_bit2(o_up, 1'b0, "T7 i_up=0 -> o_up=0");

        i_down = 1;
        @(posedge clk); #1;
        check_bit2(o_down, 1'b1, "T7 set_mode=1,i_down=1 -> o_down=1 통과");
        i_down = 0;
        @(posedge clk); #1;

        // ---- T8 : 비동기 reset은 언제든 digit_pos를 0으로 즉시 복귀 ----
        reset = 1;
        #1;
        check_pos(2'd0, "T8 비동기 reset -> 즉시 pos=0");
        reset = 0;
        @(posedge clk); #1;

        $display("==============================================");
        $display(" [2/3] tb_clock_control_unit RESULT : PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("==============================================");
        $finish;
    end

endmodule


// #######################################################################
// [3/3] TESTBENCH : top_stopwatch_clock (스탑워치+시계 통합)
// #######################################################################
module tb_top_stopwatch_clock;

    localparam ST_STOP = 0, ST_UP = 1, ST_DOWN = 2, ST_BESIDE = 3, ST_START = 4, ST_DONE = 5;

    reg clk, reset;
    reg btn_L, btn_R, btn_U, btn_D;
    reg [4:0] sw;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;
    wire [15:0] led;

    integer pass_cnt = 0;
    integer fail_cnt = 0;
    reg [31:0] snap1, snap2;

    top_stopwatch_clock uut (
        .clk(clk), .reset(reset),
        .btn_L(btn_L), .btn_R(btn_R), .btn_U(btn_U), .btn_D(btn_D),
        .sw(sw),
        .fnd_com(fnd_com), .fnd_data(fnd_data), .led(led)
    );

    // 시뮬레이션 시간 단축용 : 실제 합성에는 영향 없음 (F_COUNT=1_000_000 그대로)
    defparam uut.U_STOPWATCH_DATAPATH.U_TICK_GEN_100HZ.F_COUNT = 20;
    defparam uut.U_CLOCK_DATAPATH.U_TICK_GEN_100HZ.F_COUNT = 20;

    always #5 clk = ~clk; // 100MHz 가정

    // btn_debounce는 100clk마다 1bit씩 8bit shift register를 채워야 눌림을 인정하므로
    // 확실한 press pulse를 위해 최소 800clk 이상 눌러야 함 -> 여유있게 1000clk
    localparam HOLD = 1000;

    task automatic press(inout btn);
        begin
            btn = 1'b1;
            repeat (HOLD) @(posedge clk);
            btn = 1'b0;
            repeat (HOLD) @(posedge clk);
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

    initial begin
        clk = 0; reset = 0;
        btn_L = 0; btn_R = 0; btn_U = 0; btn_D = 0;
        sw = 5'b00000;

        reset = 1;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        // =====================================================
        // Scenario A. 일반 스탑워치 모드 (sw=00000) : run/stop/clear/store/mode
        // =====================================================
        check_eq(uut.w_ws_msec, 0, "A0 reset 직후 msec=0");

        press(btn_L); // run_stop : 카운트 시작
        repeat (150) @(posedge clk);
        snap1 = uut.w_ws_msec;
        check_true(snap1 != 0, "A1 run_stop 후 msec가 증가함");

        press(btn_L); // run_stop : 카운트 정지 (토글)
        snap1 = uut.w_ws_msec;
        repeat (150) @(posedge clk);
        snap2 = uut.w_ws_msec;
        check_eq(snap2, snap1, "A2 정지 후 값이 고정됨");

        press(btn_R); // clear (STOP 상태에서만 동작)
        check_eq(uut.w_ws_msec, 0, "A3 clear 후 msec=0");
        check_eq(uut.w_ws_sec, 0, "A3 clear 후 sec=0");

        // ---- A4 : store(btnd) 로 현재 값을 next_store_reg에 저장 ----
        press(btn_L); // 다시 run
        repeat (150) @(posedge clk);
        press(btn_L); // 다시 stop (STORE는 STOP 상태에서만 동작)
        snap1 = uut.w_ws_msec;
        press(btn_D); // store
        check_eq(uut.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.next_store_reg, snap1,
                 "A4 store 버튼으로 현재 msec 값이 next_store_reg에 저장됨");

        // ---- A5 : mode(btnu) 로 카운트 방향(up/down) 토글 ----
        check_eq(uut.w_mode, 0, "A5 초기 mode=0(증가 방향)");
        press(btn_U); // mode 토글
        check_eq(uut.w_mode, 1, "A5 mode 버튼 1회 -> 1(감소 방향)");
        press(btn_U);
        check_eq(uut.w_mode, 0, "A5 mode 버튼 2회 -> 다시 0");

        press(btn_R); // clear
        reset = 1; repeat (5) @(posedge clk); reset = 0; repeat (5) @(posedge clk);

        // =====================================================
        // Scenario B. 타임어택 모드 (sw[3]=1) : 시간설정 -> start ->
        //             일시정지/재개 -> 카운트다운 완료(DONE) -> 자동 STOP
        // =====================================================
        sw = 5'b01000;
        repeat (5) @(posedge clk);
        check_eq(uut.U_CONTROL_UNIT_2.c_state, ST_STOP, "B0 타임어택 모드 진입, control_unit2=STOP");

        // msec 자리(digit_cho=0) 값을 3만큼 증가
        press(btn_U); press(btn_U); press(btn_U);
        snap1 = uut.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg;
        check_eq(snap1, 3, "B1 btn_U 3회 -> msec 설정값=3");

        // beside 로 다음 자리(sec, digit_cho=1) 로 이동 후 값 2만큼 증가
        press(btn_R);
        check_eq(uut.w_digit_cho, 1, "B2 beside 1회 -> digit_cho=1(sec 선택)");
        press(btn_U); press(btn_U);
        snap1 = uut.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.counter_reg;
        check_eq(snap1, 2, "B3 btn_U 2회 -> sec 설정값=2");

        // start : 카운트다운 시작
        press(btn_L);
        check_eq(uut.U_CONTROL_UNIT_2.c_state, ST_START, "B4 start 후 control_unit2=START");
        repeat (200) @(posedge clk);
        snap1 = uut.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg;
        check_true(snap1 != 3, "B5 카운트다운 진행중 msec 값이 변함(감소)");

        // 일시정지 (start 재입력) -> 값 고정
        press(btn_L);
        check_eq(uut.U_CONTROL_UNIT_2.c_state, ST_STOP, "B6 카운트 중 start 재입력 -> STOP(일시정지)");
        snap1 = uut.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg;
        repeat (200) @(posedge clk);
        snap2 = uut.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg;
        check_eq(snap2, snap1, "B7 일시정지 중 값 고정");

        // 재개 (start 재입력) -> 이어서 카운트
        press(btn_L);
        check_eq(uut.U_CONTROL_UNIT_2.c_state, ST_START, "B8 재입력 -> START(재개)");

        // 0000 도달까지 대기 (타임아웃 가드 포함)
        // 순수 Verilog에는 join_any/join_none이 없어(SystemVerilog 전용) join만 사용하고,
        // 먼저 끝난 쪽이 반대쪽을 disable 시켜서 둘 다 끝나게 만든다.
        fork
            begin : wait_zero
                wait (uut.w_zero == 1'b1);
                disable timeout_guard;
            end
            begin : timeout_guard
                repeat (100000) @(posedge clk);
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0t : B9 TIMEOUT - w_zero가 끝내 1이 되지 않음", $time);
                disable wait_zero;
            end
        join

        repeat (5) @(posedge clk);
        check_eq(uut.U_CONTROL_UNIT_2.c_state, ST_STOP,
                 "B10 0000 도달 후 DONE을 거쳐 자동으로 STOP 복귀");
        check_eq(uut.w_ta_start, 0, "B11 STOP 복귀 후 카운트다운 enable(o_start)=0");

        // =====================================================
        // Scenario C. clock 모드 (sw[1]=1, sw[4]=set_mode)
        // =====================================================
        reset = 1; repeat (5) @(posedge clk); reset = 0; repeat (5) @(posedge clk);
        sw = 5'b10010; // clock 모드 + 설정모드
        repeat (5) @(posedge clk);
        check_eq(led[0], 1'b1, "C0 set_mode=1 -> led[0]=1");
        check_eq(led[2:1], 2'b00, "C0 초기 digit_pos=0");

        press(btn_L); // clock 모드에서 btn_L = 자리 이동(상위)
        check_eq(led[2:1], 2'b01, "C1 btn_L -> digit_pos=1");
        press(btn_L);
        check_eq(led[2:1], 2'b10, "C2 btn_L 재입력 -> digit_pos=2");

        press(btn_R); // btn_R = 자리 이동(하위)
        check_eq(led[2:1], 2'b01, "C3 btn_R -> digit_pos=1(뒤로)");

        snap1 = uut.w_c_msec;
        press(btn_U); // 선택된 자리(msec 10의자리) 값 증가
        check_true(uut.w_c_msec != snap1, "C4 set_mode에서 btn_U -> 선택된 자리 값 증가");

        snap1 = uut.w_c_msec;
        press(btn_D); // 값 감소
        check_true(uut.w_c_msec != snap1, "C5 set_mode에서 btn_D -> 선택된 자리 값 감소");

        sw = 5'b00010; // set_mode 해제 (clock 모드는 유지)
        repeat (5) @(posedge clk);
        check_eq(led[0], 1'b0, "C6 set_mode 해제 -> led[0]=0");
        press(btn_L); // set_mode=0 이면 btn_L 눌러도 자리 이동 안됨
        check_eq(uut.w_c_digit_pos, 1, "C7 set_mode=0 에서는 digit_pos 이동 안 함(그대로 1)");

        // =====================================================
        // Scenario D. 모드 격리 : clock 화면 보는 동안 스탑워치 쪽 버튼 무시
        // =====================================================
        reset = 1; repeat (5) @(posedge clk); reset = 0; repeat (5) @(posedge clk);
        sw = 5'b00010; // clock 모드 (설정모드 아님)
        repeat (5) @(posedge clk);
        check_eq(uut.U_CONTROL_UNIT_2.c_state, ST_STOP, "D0 clock 모드 진입 시 control_unit2=STOP");
        press(btn_L); press(btn_U); press(btn_R); press(btn_D);
        check_eq(uut.U_CONTROL_UNIT_2.c_state, ST_STOP,
                 "D1 clock 모드에서 버튼 입력해도 control_unit2 상태 불변(STOP)");
        check_eq(uut.w_run_stop, 0,
                 "D2 clock 모드에서 버튼 입력해도 control_unit(run_stop) 상태 불변");

        $display("==============================================");
        $display(" [3/3] tb_top_stopwatch_clock RESULT : PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("==============================================");
        $finish;
    end

endmodule
