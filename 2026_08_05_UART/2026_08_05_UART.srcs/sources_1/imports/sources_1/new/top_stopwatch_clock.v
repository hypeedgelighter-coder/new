`timescale 1ns / 1ps

// stopwatch(project_stopwatch)와 clock(new) 두 기능을 하나의 top으로 통합.
// 하위 모듈(control_unit, control_unit2, stopwatch_datapath, clock_control_unit,
// clock_datapath, fnd_controller 등)의 내부 동작 코드는 수정하지 않고,
// 이 top에서 스위치로 두 기능을 선택/배선만 함.
module top_stopwatch_clock (
    input clk,
    input reset,
    input rx,  // USB-UART RX : 키보드(r/s/c/m/U/D/L/R/S/M/H)
    output tx,  // USB-UART TX : 수신 바이트 에코백
    // ---- [수정 전] ----
    // input run,   // stopwatch: run_stop / time attack: start   | clock: 자리 이동(왼쪽)
    // input stop,   // stopwatch: clear    / time attack: beside  | clock: 자리 이동(오른쪽)
    // input up,  // stopwatch: mode      / time attack: up     | clock: 값 증가
    // input down,   // stopwatch: store     / time attack: down   | clock: 값 감소
    // input left,
    // input right,
    // input S,
    // input M,
    // input H,
    // 위 9개는 전부 주석 처리된 "미사용" 포트였음(선언은 없고 밑에서 rx/tx만 쓰는데
    // 그마저도 포트가 아니었음). run/stop/... 은 실제로는 UART에서 디코딩돼 나오는
    // 내부 신호(w_run, w_stop, ...)이지, top의 외부 입력 핀이 아니었어야 함.
    // -------------------
    input [4:0] sw,  // sw[0]: msec,sec <-> min,hour 표시
                     // sw[1]: 0=스탑워치 보기, 1=clock 보기
                     // sw[2]: 스탑워치 저장 시간 보기
                     // sw[3]: 스탑워치 타임어택 기능
                     // sw[4]: clock 시간 변경(설정) 기능
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output [15:0] led
);

    wire w_display_mode_ms = sw[0];  // fnd_controller의 msec/sec <-> min/hour 표시 전환
    wire w_clock_mode = sw[1];  // 0: 스탑워치 화면, 1: clock 화면
    wire w_display_mode_ts = sw[2];  // 스탑워치 저장 시간 보기
    wire w_display_mode_ta = sw[3];  // 스탑워치 타임어택 모드
    wire w_clock_set_mode = sw[4];  // clock 시간 설정 모드

    //UART (키보드 -> ascii_decoder 디코딩 결과, 1클럭 폭 펄스로 들어온다)
    wire w_run, w_stop, w_clear, w_mode, w_up, w_down, w_left, w_right, w_S, w_M, w_H;

    uart_top U_UART_TOP (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx),
        .run(w_run),
        .stop(w_stop),
        .clear(w_clear),
        .mode(w_mode),
        .up(w_up),
        .down(w_down),
        .left(w_left),
        .right(w_right),
        .S(w_S),
        .M(w_M),
        .H(w_H)
    );

    // UART 디코딩 결과를 기존 버튼 배선(w_btn_L/R/U/D)에 연결
    wire w_btn_L = w_left;
    wire w_btn_R = w_right;
    wire w_btn_U = w_up;
    wire w_btn_D = w_down;
    wire w_run_stop, w_store;
    // control_unit은 run_stop 토글 FSM 1개뿐이라 버튼 1개(run_stop)만 받는다.
    // r/s 두 키를 분리해서 받되, 정지 상태에서는 'r'만, 동작 상태에서는 's'만
    // 토글을 발생시켜 "실행/정지"가 각각의 키로 동작하도록 만든다.
    wire w_run_stop_pulse = (w_run & ~w_run_stop) | (w_stop & w_run_stop);

    // control_unit의 o_clear/o_mode는 이 top에서 쓰이지 않는 출력인데, 기존 코드가
    // 실수로 자신의 입력(w_clear/w_mode, UART 쪽에서도 구동됨)에 그대로 연결해
    // 멀티 드라이버 충돌이 나고 있었다. 별도 미사용 net으로 분리해서 고침.
    wire w_cu_clear, w_cu_mode;

    // ---- [수정 전] 이 블록 전체가 있던 자리 ----
    // // // wire w_btn_L, w_btn_R, w_btn_U, w_btn_D;
    //
    // // btn_debounce U_BD_L (
    // //     .clk  (clk),
    // //     .reset(reset),
    // //     .i_btn(btn_L),
    // //     .o_btn(w_btn_L)
    // // );
    // // btn_debounce U_BD_R (
    // //     .clk  (clk),
    // //     .reset(reset),
    // //     .i_btn(btn_R),
    // //     .o_btn(w_btn_R)
    // // );
    // // btn_debounce U_BD_U (
    // //     .clk  (clk),
    // //     .reset(reset),
    // //     .i_btn(btn_U),
    // //     .o_btn(w_btn_U)
    // // );
    // // btn_debounce U_BD_D (
    // //     .clk  (clk),
    // //     .reset(reset),
    // //     .i_btn(btn_D),
    // //     .o_btn(w_btn_D)
    // // );
    // // 위 4개는 이미 다 주석 처리돼 있던 죽은 코드(물리 버튼용). btn_L/R/U/D라는
    // // 존재하지도 않는 포트를 참조하고 있어서 애초에 쓸 수 없는 상태였음.
    //
    // // );   <- 짝이 안 맞는 괄호. 이것도 죽은 코드라 신경 안 써도 됐음.
    //
    // // uart_top 인스턴스는 있었지만, 그 결과(w_run, w_stop, ... w_H)를
    // // control_unit / control_unit2 / clock_control_unit 어디에도 실제로
    // // 연결하는 코드가 없었음. 즉 UART로 뭘 받아도 시계/스탑워치는 반응 안 함.
    // // -> 그래서 아래에 w_btn_L/R/U/D 연결과 w_run_stop_pulse를 새로 추가함.
    // -------------------------------------------
    // ---------------- 스탑워치 ----------------

    wire w_ta_up, w_ta_down, w_ta_beside, w_ta_start, w_zero;
    wire [1:0] w_digit_cho;
    wire [3:0] w_cho_reg;
    wire w_sw_btnl, w_sw_btnr, w_sw_btnu, w_sw_btnd;
    wire [6:0] w_ws_msec;
    wire [5:0] w_ws_sec;
    wire [5:0] w_ws_min;
    wire [4:0] w_ws_hour;

    // 타임어택 모드(sw[3])일 때 버튼 기능을 start/beside/up/down으로 교체 (기존 top_stopwatch와 동일한 방식)
    assign w_sw_btnl = w_display_mode_ta ? w_ta_start : w_run_stop;
    assign w_sw_btnr = w_display_mode_ta ? w_ta_beside : w_clear;
    assign w_sw_btnu = w_display_mode_ta ? w_ta_up : w_mode;
    assign w_sw_btnd = w_display_mode_ta ? w_ta_down : w_store;

    // clock 화면을 보는 중에는 버튼이 스탑워치를 건드리지 않도록 차단
    control_unit U_CONTROL_UNIT (
        .clk       (clk),
        .reset     (reset),
        .i_run_stop(w_run_stop_pulse & ~w_clock_mode),
        .i_clear   (w_clear & ~w_clock_mode),
        .i_mode    (w_mode & ~w_clock_mode),
        .i_store   (w_btn_D & ~w_clock_mode),
        .o_run_stop(w_run_stop),
        .o_clear   (w_cu_clear),
        .o_mode    (w_cu_mode),
        .o_store   (w_store)
    );
    // ---- [수정 전] ----
    // .i_run_stop(w_run & ~w_clock_mode),   <- 'r' 키만 있었음(토글이라 s로는 못 멈춤)
    // .i_clear   (w_clear & ~w_clock_mode),
    // .i_mode    (w_mode & ~w_clock_mode),
    // .i_store   (w_btn_D & ~w_clock_mode),
    // .o_run_stop(w_run_stop),
    // .o_clear   (w_clear),   <- UART가 구동하는 w_clear에 여기서도 또 값을 씀
    // .o_mode    (w_mode),    <- UART가 구동하는 w_mode에 여기서도 또 값을 씀
    // .o_store   (w_store)
    // w_clear/w_mode를 uart_top과 control_unit이 동시에 구동 -> 멀티 드라이버 충돌.
    // 시뮬레이션/합성 툴에 따라 X가 되거나 경고만 내고 엉뚱하게 동작할 수 있는 버그였음.
    // -------------------

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

    // S/M/H : 자리 이동(L/R) 없이 초/분/시를 바로 1씩 증가시키는 단축키.
    // clock_datapath는 digit_pos + display_mode(sw[0])로 어느 필드를 만질지
    // 정하므로, S/H는 digit_pos[1]=1(상위 필드), M은 digit_pos[1]=0(하위 필드)로
    // 그 클럭 한 번만 강제로 바꿔서 up을 걸어준다(자리 커서 자체는 그대로 유지).
    // - S: sw[0]=0(msec/sec 화면)일 때 상위 필드 = 초
    // - H: sw[0]=1(min/hour 화면)일 때 상위 필드 = 시
    // - M: sw[0]=1(min/hour 화면)일 때 하위 필드 = 분
    wire w_direct_hit = (w_S | w_M | w_H) & w_clock_mode & w_clock_set_mode;
    wire [1:0] w_digit_pos_ovr = {(w_S | w_H), 1'b0};
    wire [1:0] w_c_digit_pos_final = w_direct_hit ? w_digit_pos_ovr : w_c_digit_pos;
    wire w_c_up_final = w_c_up | w_direct_hit;
    // ---- [수정 전] ----
    // 이 4줄(w_direct_hit ~ w_c_up_final) 자체가 없었음.
    // S/M/H 키를 받는 로직이 top 어디에도 없어서, UART로 S/M/H를 눌러도
    // 아무 반응이 없었음(그냥 버려지는 신호였음).
    // -------------------

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
        .digit_pos   (w_c_digit_pos_final),
        .up          (w_c_up_final),
        .down        (w_c_down),
        .msec        (w_c_msec),
        .sec         (w_c_sec),
        .min         (w_c_min),
        .hour        (w_c_hour)
    );
    // ---- [수정 전] ----
    // .digit_pos   (w_c_digit_pos),   <- L/R로 옮긴 커서 위치만 그대로 사용
    // .up          (w_c_up),          <- S/M/H로 만든 강제 up이 없었음
    // (down/msec/sec/min/hour 등 나머지는 동일)
    // -------------------

    // ---------------- 표시 선택 (sw[1]) ----------------
    wire [ 6:0] w_msec = w_clock_mode ? w_c_msec : w_ws_msec;
    wire [ 5:0] w_sec = w_clock_mode ? w_c_sec : w_ws_sec;
    wire [ 5:0] w_min = w_clock_mode ? w_c_min : w_ws_min;
    wire [ 4:0] w_hour = w_clock_mode ? w_c_hour : w_ws_hour;

    // fnd_controller의 cho_reg / display_mode_ta는 스탑워치 저장·타임어택 전용 기능이라
    // clock 표시에는 쓰이지 않으므로, clock 화면(w_clock_mode=1)에서는 0으로 고정해 무효화한다.
    wire [ 3:0] w_fnd_cho_reg = w_clock_mode ? 4'b0000 : w_cho_reg;
    wire        w_fnd_display_ta = w_clock_mode ? 1'b0 : w_display_mode_ta;

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
