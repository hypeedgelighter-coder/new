`timescale 1ns / 1ps

//=====================================================================
// main_control_unit  -  블록도의 "Control Unit"
//
//   입력 : SW(모드 one-hot), 디바운스된 버튼 펄스, ASCII 디코더 명령 펄스
//   출력 : 현재 모드 + 각 데이터패스/센서 컨트롤러로 가는 제어 신호
//
//   버튼과 UART 명령은 둘 다 1클럭 폭 펄스라 그냥 OR 로 합친다.
//   합친 뒤 현재 모드에 해당하는 블록으로만 내보내서, 예를 들어
//   SR04 모드에서 버튼을 눌러도 스톱워치가 굴러가지 않는다.
//
//  [기존 대비 바뀐 점]
//   기존 top_stopwatch 는 sw[1] 로 버튼을 게이팅했다 (btn_L & ~sw[1] 식).
//   기능이 4개로 늘어서 mode_sel 비교로 게이팅하도록 일반화했다.
//   sw[0] 은 모드 비트에서 빼서 표시모드(sw_disp)로 돌렸다. 그래서
//   모드 스위치는 sw[3:1] 3개뿐이고, 전부 내리면 스톱워치다.
//   SR04/DHT11 의 자동 주기 측정(periodic_pulse)은 제거했다. 이제
//   해당 스위치를 올린 상태에서 btn_L 을 눌렀을 때만 1회 측정한다.
//   스톱워치/시계 FSM(control_unit_stopwatch, control_unit_watch)도
//   블록도대로 Control Unit 안으로 넣었다.
//=====================================================================
module main_control_unit (
    input            clk,
    input            reset,

    input      [3:1] sw_mode,  // 기능 선택 : sw[1]=시계 sw[2]=SR04 sw[3]=DHT11
    input            sw_disp,  // sw[0] : 서브 표시모드 (0=SS.mm, 1=HH.MM)

    // 디바운스된 버튼 펄스
    input            btn_l,
    input            btn_r,
    input            btn_u,
    input            btn_d,

    // ASCII 디코더 명령 펄스
    input            u_run,
    input            u_stop,
    input            u_clear,
    input            u_mode,
    input            u_up,
    input            u_down,
    input            u_left,
    input            u_right,
    input            u_sel_s,
    input            u_sel_m,
    input            u_sel_h,
    input            u_start,

    // 모드
    output     [1:0] mode_sel,
    output           disp_mode,

    // 스톱워치 데이터패스 제어
    output           sw_run_stop,
    output           sw_clear,
    output           sw_count_mode,

    // 시계 데이터패스 제어
    output     [1:0] wt_edit_sel,
    output           wt_clear,
    output           wt_up,
    output           wt_down,

    // 센서 측정 시작
    output           sr04_start,
    output           dht_start
);

    localparam MODE_STOPWATCH = 2'd0,
               MODE_WATCH     = 2'd1,
               MODE_SR04      = 2'd2,
               MODE_DHT11     = 2'd3;

    // sw[3:1] 우선순위 인코더. 여러 개 켜지면 낮은 번호 우선.
    // 스톱워치는 전용 스위치가 없는 기본 모드라, sw[3:1] 이 전부 0 이면 스톱워치.
    assign mode_sel = sw_mode[1] ? MODE_WATCH :
                      sw_mode[2] ? MODE_SR04  :
                      sw_mode[3] ? MODE_DHT11 : MODE_STOPWATCH;

    assign disp_mode = sw_disp;

    wire is_sw   = (mode_sel == MODE_STOPWATCH);
    wire is_wt   = (mode_sel == MODE_WATCH);
    wire is_sr04 = (mode_sel == MODE_SR04);
    wire is_dht  = (mode_sel == MODE_DHT11);

    //----------------- 버튼 + UART 명령 병합 & 모드 게이팅 -----------------
    wire cmd_sw_toggle = is_sw & btn_l;              // 버튼은 run/stop 토글
    wire cmd_sw_run    = is_sw & u_run;              // 'r' 은 무조건 RUN
    wire cmd_sw_stop   = is_sw & u_stop;             // 's' 는 무조건 STOP
    wire cmd_sw_clear  = is_sw & (btn_r | u_clear);
    wire cmd_sw_mode   = is_sw & (btn_u | u_mode);

    wire cmd_wt_l      = is_wt & (btn_l | u_left);
    wire cmd_wt_r      = is_wt & (btn_r | u_right);
    wire cmd_wt_u      = is_wt & (btn_u | u_up);
    wire cmd_wt_d      = is_wt & (btn_d | u_down);
    wire cmd_wt_c      = is_wt & u_clear;
    wire cmd_wt_sel_s  = is_wt & u_sel_s;
    wire cmd_wt_sel_m  = is_wt & u_sel_m;
    wire cmd_wt_sel_h  = is_wt & u_sel_h;

    //----------------- 스톱워치 / 시계 FSM -----------------
    control_unit_stopwatch U_CU_STOPWATCH (
        .clk       (clk),
        .reset     (reset),
        .i_run_stop(cmd_sw_toggle),
        .i_run     (cmd_sw_run),
        .i_stop    (cmd_sw_stop),
        .i_clear   (cmd_sw_clear),
        .i_mode    (cmd_sw_mode),
        .o_run_stop(sw_run_stop),
        .o_clear   (sw_clear),
        .o_mode    (sw_count_mode)
    );

    control_unit_watch U_CU_WATCH (
        .clk        (clk),
        .reset      (reset),
        .btn_L      (cmd_wt_l),
        .btn_R      (cmd_wt_r),
        .btn_U      (cmd_wt_u),
        .btn_D      (cmd_wt_d),
        .btn_C      (cmd_wt_c),
        .i_sel_sec  (cmd_wt_sel_s),
        .i_sel_min  (cmd_wt_sel_m),
        .i_sel_hour (cmd_wt_sel_h),
        .edit_sel   (wt_edit_sel),
        .o_clear    (wt_clear),
        .o_up       (wt_up),
        .o_down     (wt_down)
    );

    //----------------- 센서 측정 트리거 -----------------
    // 자동 주기 측정은 쓰지 않는다. 해당 센서 스위치가 올라가 있고
    // (is_sr04 / is_dht) 그 상태에서 btn_L 을 누른 순간에만 1회 측정한다.
    //
    // btn_l 은 디바운스를 거친 1클럭 폭 펄스라 한 번 누르면 측정도 딱 한 번
    // 나간다. 버튼을 눌러 붙잡고 있어도 재측정되지 않는다.
    // 스톱워치의 btn_l 은 is_sw 로 게이팅돼 있어서 서로 간섭하지 않는다.
    //
    // 측정값은 센서 컨트롤러 안에서 래치되므로(sr04 는 distance_reg,
    // dht11 은 top 의 humidity_reg/temperature_reg) 다음 측정 전까지 유지된다.
    // UART 't' 로도 동일하게 1회 측정할 수 있다.
    assign sr04_start = is_sr04 & (btn_l | u_start);
    assign dht_start  = is_dht & (btn_l | u_start);

endmodule


//=====================================================================
// control_unit_stopwatch
//   버튼 펄스를 run_stop 레벨 / clear 펄스 / mode 레벨로 바꾼다.
//
//  [기존 대비 바뀐 점]
//   i_run_stop 하나로만 토글했는데, UART 'r'(RUN) / 's'(STOP) 는
//   토글이 아니라 특정 상태로 가야 해서 i_run / i_stop 입력을 추가했다.
//=====================================================================
module control_unit_stopwatch (
    input  clk,
    input  reset,
    input  i_run_stop,  // 토글 (버튼)
    input  i_run,       // 무조건 RUN
    input  i_stop,      // 무조건 STOP
    input  i_clear,
    input  i_mode,
    output o_run_stop,
    output o_clear,
    output o_mode
);
    localparam STOP = 2'd0, RUN = 2'd1, CLEAR = 2'd2, MODE = 2'd3;

    reg [1:0] c_state, n_state;
    reg run_stop_reg, run_stop_next;
    reg clear_reg, clear_next;
    reg mode_reg, mode_next;

    assign o_run_stop = run_stop_reg;
    assign o_clear    = clear_reg;
    assign o_mode     = mode_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state      <= STOP;
            run_stop_reg <= 1'b0;
            clear_reg    <= 1'b0;
            mode_reg     <= 1'b0;
        end else begin
            c_state      <= n_state;
            run_stop_reg <= run_stop_next;
            clear_reg    <= clear_next;
            mode_reg     <= mode_next;
        end
    end

    always @(*) begin
        n_state       = c_state;
        run_stop_next = run_stop_reg;
        clear_next    = clear_reg;
        mode_next     = mode_reg;
        case (c_state)
            STOP: begin
                run_stop_next = 1'b0;
                clear_next    = 1'b0;
                if (i_run_stop | i_run) n_state = RUN;
                else if (i_clear) n_state = CLEAR;
                else if (i_mode) n_state = MODE;
            end
            RUN: begin
                run_stop_next = 1'b1;
                if (i_run_stop | i_stop) n_state = STOP;
            end
            CLEAR: begin
                clear_next = 1'b1;  // 1클럭 펄스
                n_state    = STOP;
            end
            MODE: begin
                mode_next = ~mode_reg;  // 업/다운 카운트 토글
                n_state   = STOP;
            end
        endcase
    end
endmodule


//=====================================================================
// control_unit_watch
//   L/R 로 편집 자리(sec/min/hour)를 옮기고 U/D 로 값을 올리고 내린다.
//   C 는 시계 clear.
//
//  [기존 대비 바뀐 점]
//   UART 'S'/'M'/'H' 로 편집 자리를 바로 고를 수 있게
//   i_sel_sec / i_sel_min / i_sel_hour 입력을 추가했다.
//=====================================================================
module control_unit_watch (
    input        clk,
    input        reset,
    input        btn_L,
    input        btn_R,
    input        btn_U,
    input        btn_D,
    input        btn_C,
    input        i_sel_sec,
    input        i_sel_min,
    input        i_sel_hour,
    output [1:0] edit_sel,  // 0=sec, 1=min, 2=hour
    output       o_clear,
    output       o_up,
    output       o_down
);
    localparam IDLE = 3'd0, LEFT = 3'd1, RIGHT = 3'd2, UP = 3'd3, DOWN = 3'd4;

    reg [2:0] c_state, n_state;
    reg btn_U_reg, btn_U_next, btn_D_reg, btn_D_next;
    reg clear_reg, clear_next;
    reg [1:0] edit_sel_reg, edit_sel_next;

    assign edit_sel = edit_sel_reg;
    assign o_clear  = clear_reg;
    assign o_up     = btn_U_reg;
    assign o_down   = btn_D_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state      <= IDLE;
            btn_U_reg    <= 1'b0;
            btn_D_reg    <= 1'b0;
            clear_reg    <= 1'b0;
            edit_sel_reg <= 2'b00;
        end else begin
            c_state      <= n_state;
            btn_U_reg    <= btn_U_next;
            btn_D_reg    <= btn_D_next;
            clear_reg    <= clear_next;
            edit_sel_reg <= edit_sel_next;
        end
    end

    always @(*) begin
        n_state       = c_state;
        clear_next    = clear_reg;
        btn_U_next    = btn_U_reg;
        btn_D_next    = btn_D_reg;
        edit_sel_next = edit_sel_reg;

        case (c_state)
            IDLE: begin
                clear_next = 1'b0;
                btn_U_next = 1'b0;
                btn_D_next = 1'b0;
                if (btn_L) n_state = LEFT;
                else if (btn_R) n_state = RIGHT;
                else if (btn_U) n_state = UP;
                else if (btn_D) n_state = DOWN;
                else if (btn_C) clear_next = 1'b1;
                else if (i_sel_sec) edit_sel_next = 2'd0;
                else if (i_sel_min) edit_sel_next = 2'd1;
                else if (i_sel_hour) edit_sel_next = 2'd2;
            end
            LEFT: begin
                edit_sel_next = (edit_sel_reg == 2'd0) ? 2'd2 : edit_sel_reg - 2'd1;
                n_state       = IDLE;
            end
            RIGHT: begin
                edit_sel_next = (edit_sel_reg == 2'd2) ? 2'd0 : edit_sel_reg + 2'd1;
                n_state       = IDLE;
            end
            UP: begin
                btn_U_next = 1'b1;  // 1클럭 펄스
                n_state    = IDLE;
            end
            DOWN: begin
                btn_D_next = 1'b1;
                n_state    = IDLE;
            end
            default: n_state = IDLE;
        endcase
    end
endmodule
