`timescale 1ns / 1ps

// stopwatch(project_stopwatch)와 clock(new) 두 기능을 하나의 top으로 통합.
// 하위 모듈(control_unit, control_unit2, stopwatch_datapath, clock_control_unit,
// clock_datapath, fnd_controller 등)의 내부 동작 코드는 수정하지 않고,
// 이 top에서 스위치로 두 기능을 선택/배선만 함.
module top_stopwatch_clock (
    input        clk,
    input        reset,
    input        btn_L,   // stopwatch: run_stop / time attack: start   | clock: 자리 이동(왼쪽)
    input        btn_R,   // stopwatch: clear    / time attack: beside  | clock: 자리 이동(오른쪽)
    input        btn_U,   // stopwatch: mode      / time attack: up     | clock: 값 증가
    input        btn_D,   // stopwatch: store     / time attack: down   | clock: 값 감소
    input  [4:0] sw,      // sw[0]: msec,sec <-> min,hour 표시
                           // sw[1]: 0=스탑워치 보기, 1=clock 보기
                           // sw[2]: 스탑워치 저장 시간 보기
                           // sw[3]: 스탑워치 타임어택 기능
                           // sw[4]: clock 시간 변경(설정) 기능
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output [15:0] led
);

    wire w_display_mode_ms = sw[0];  // fnd_controller의 msec/sec <-> min/hour 표시 전환
    wire w_clock_mode      = sw[1];  // 0: 스탑워치 화면, 1: clock 화면
    wire w_display_mode_ts = sw[2];  // 스탑워치 저장 시간 보기
    wire w_display_mode_ta = sw[3];  // 스탑워치 타임어택 모드
    wire w_clock_set_mode  = sw[4];  // clock 시간 설정 모드

    wire w_btn_L, w_btn_R, w_btn_U, w_btn_D;

    btn_debounce U_BD_L (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_L),
        .o_btn(w_btn_L)
    );
    btn_debounce U_BD_R (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_R),
        .o_btn(w_btn_R)
    );
    btn_debounce U_BD_U (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_U),
        .o_btn(w_btn_U)
    );
    btn_debounce U_BD_D (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_D),
        .o_btn(w_btn_D)
    );

    // ---------------- 스탑워치 ----------------
    wire w_run_stop, w_clear, w_mode, w_store;
    wire w_ta_up, w_ta_down, w_ta_beside, w_ta_start, w_zero;
    wire [1:0] w_digit_cho;
    wire [3:0] w_cho_reg;
    wire w_sw_btnl, w_sw_btnr, w_sw_btnu, w_sw_btnd;
    wire [6:0] w_ws_msec;
    wire [5:0] w_ws_sec;
    wire [5:0] w_ws_min;
    wire [4:0] w_ws_hour;

    // 타임어택 모드(sw[3])일 때 버튼 기능을 start/beside/up/down으로 교체 (기존 top_stopwatch와 동일한 방식)
    assign w_sw_btnl = w_display_mode_ta ? w_ta_start  : w_run_stop;
    assign w_sw_btnr = w_display_mode_ta ? w_ta_beside : w_clear;
    assign w_sw_btnu = w_display_mode_ta ? w_ta_up     : w_mode;
    assign w_sw_btnd = w_display_mode_ta ? w_ta_down   : w_store;

    // clock 화면을 보는 중에는 버튼이 스탑워치를 건드리지 않도록 차단
    control_unit U_CONTROL_UNIT (
        .clk       (clk),
        .reset     (reset),
        .i_run_stop(w_btn_L & ~w_clock_mode),
        .i_clear   (w_btn_R & ~w_clock_mode),
        .i_mode    (w_btn_U & ~w_clock_mode),
        .i_store   (w_btn_D & ~w_clock_mode),
        .o_run_stop(w_run_stop),
        .o_clear   (w_clear),
        .o_mode    (w_mode),
        .o_store   (w_store)
    );

    control_unit2 U_CONTROL_UNIT_2 (
        .clk        (clk),
        .reset      (reset),
        .i_start    (w_btn_L & ~w_clock_mode),
        .i_beside   (w_btn_R & ~w_clock_mode),
        .i_up       (w_btn_U & ~w_clock_mode),
        .i_down     (w_btn_D & ~w_clock_mode),
        .i_zero     (w_zero),
        .o_start    (w_ta_start),
        .o_beside   (w_ta_beside),
        .o_up       (w_ta_up),
        .o_down     (w_ta_down),
        .o_digit_cho(w_digit_cho)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk            (clk),
        .reset          (reset),
        .btnl           (w_sw_btnl),
        .btnr           (w_sw_btnr),
        .btnu           (w_sw_btnu),
        .btnd           (w_sw_btnd),
        .display_mode_ta(w_display_mode_ta),
        .display_mode_ts(w_display_mode_ts),
        .cho_time       (w_digit_cho),
        .msec           (w_ws_msec),
        .sec            (w_ws_sec),
        .min            (w_ws_min),
        .hour           (w_ws_hour),
        .o_zero         (w_zero),
        .cho_reg        (w_cho_reg)
    );

    // ---------------- clock ----------------
    wire w_c_set_mode, w_c_up, w_c_down;
    wire [1:0] w_c_digit_pos;
    wire [6:0] w_c_msec;
    wire [5:0] w_c_sec;
    wire [5:0] w_c_min;
    wire [4:0] w_c_hour;

    // 스탑워치 화면을 보는 중에는 버튼이 clock을 건드리지 않도록 차단
    clock_control_unit U_CLOCK_CONTROL_UNIT (
        .clk        (clk),
        .reset      (reset),
        .i_set_mode (w_clock_set_mode),
        .i_left     (w_btn_L & w_clock_mode),
        .i_right    (w_btn_R & w_clock_mode),
        .i_up       (w_btn_U & w_clock_mode),
        .i_down     (w_btn_D & w_clock_mode),
        .o_set_mode (w_c_set_mode),
        .o_digit_pos(w_c_digit_pos),
        .o_up       (w_c_up),
        .o_down     (w_c_down)
    );

    clock_datapath #(
        .MSEC_WIDTH(7),
        .SEC_WIDTH (6),
        .MIN_WIDTH (6),
        .HOUR_WIDTH(5)
    ) U_CLOCK_DATAPATH (
        .clk         (clk),
        .reset       (reset),
        .set_mode    (w_c_set_mode),
        .display_mode(w_display_mode_ms),
        .digit_pos   (w_c_digit_pos),
        .up          (w_c_up),
        .down        (w_c_down),
        .msec        (w_c_msec),
        .sec         (w_c_sec),
        .min         (w_c_min),
        .hour        (w_c_hour)
    );

    // ---------------- 표시 선택 (sw[1]) ----------------
    wire [6:0] w_msec = w_clock_mode ? w_c_msec : w_ws_msec;
    wire [5:0] w_sec  = w_clock_mode ? w_c_sec  : w_ws_sec;
    wire [5:0] w_min  = w_clock_mode ? w_c_min  : w_ws_min;
    wire [4:0] w_hour = w_clock_mode ? w_c_hour : w_ws_hour;

    // fnd_controller의 cho_reg / display_mode_ta는 스탑워치 저장·타임어택 전용 기능이라
    // clock 표시에는 쓰이지 않으므로, clock 화면(w_clock_mode=1)에서는 0으로 고정해 무효화한다.
    wire [3:0] w_fnd_cho_reg    = w_clock_mode ? 4'b0000 : w_cho_reg;
    wire       w_fnd_display_ta = w_clock_mode ? 1'b0    : w_display_mode_ta;

    wire [15:0] w_led_fnd;

    fnd_controller U_FND_CNTL (
        .clk            (clk),
        .reset          (reset),
        .msec           (w_msec),
        .sec            (w_sec),
        .min            (w_min),
        .hour           (w_hour),
        .display_mode_ms(w_display_mode_ms),
        .display_mode_ts(w_display_mode_ts),
        .display_mode_ta(w_fnd_display_ta),
        .cho_reg        (w_fnd_cho_reg),
        .fnd_com        (fnd_com),
        .fnd_data       (fnd_data),
        .led            (w_led_fnd)
    );

    // led[15:4] : fnd_controller가 만드는 스탑워치 자리 선택 표시 (clock 모드에서는 0으로 무효화됨)
    // led[3:0]  : clock 모드에서 set_mode / 선택 자리, 스탑워치 모드에서는 run_stop 상태만 표시
    assign led[15:4] = w_led_fnd[15:4];
    assign led[3:0]  = w_clock_mode ? {1'b0, w_c_digit_pos, w_c_set_mode}
                                     : {w_run_stop, 3'b000};

endmodule
