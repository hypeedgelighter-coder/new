`timescale 1ns / 1ps

//=====================================================================
//  top.v  -  전체 통합 최상위
//
//  블록 배선만 하는 최상위다. 실제 로직은 전부 아래 블록 안에 있다.
//  (RTL 스키매틱에도 이 상자 7개로 그대로 나온다)
//
//   BTN --> [BTN_UNIT] ------------+
//                                  v
//   PC <--UART--> [UART_COMM] --> [CONTROL_UNIT] <-- SW
//                     ^              |
//                     |              +--> [TIME_DATAPATH] --+
//                     |              |     스톱워치+시계     |
//                     |              +--> [SENSOR_UNIT] ----+--> 표시값
//                     |                    SR04+DHT11       |
//                     +------------------------------------+|
//                                                           v
//                                        [FND_DISPLAY] --> FND
//                                        [LED_STATUS]  --> LED
//
//  블록 구성
//    btn_unit.v      : btn_debounce x4
//    uart_comm.v     : uart_fifo + ascii_decoder + ascii_sender + 송신 타이밍
//    main_control_unit.v : 모드 판정 + 버튼/UART 명령 분배
//    time_datapath.v : stopwatch_datapath + watch_datapath + 표시 선택
//    sensor_unit.v   : sr04_controller + dht11_controller + 값 래치
//    fnd_display.v   : 자리수 분리 + 모드 MUX + fnd_controller
//    led_status.v    : LED 표시 (조합)
//
//  스위치 배치 (보드 정면 기준 오른쪽 끝이 sw[0], 왼쪽으로 갈수록 번호 증가)
//    sw[0] 오른쪽 1번째 = 자릿수 표시모드 (0 = SS.mm 초.밀리초 / 1 = HH.MM 시.분)
//    sw[1] 오른쪽 2번째 = 시계
//    sw[2] 오른쪽 3번째 = SR04(거리)
//    sw[3] 오른쪽 4번째 = DHT11(온습도)
//      -> sw[3:1] 은 one-hot, 낮은 번호 우선. 전부 내리면 스톱워치.
//    BTNC 가운데 버튼   = 전체 reset
//
//  버튼 (모드별로 의미가 다름. Control Unit 이 현재 모드로만 보낸다)
//    스톱워치 : L=Run/Stop 토글, R=Clear, U=업다운 카운트 전환
//    시계     : L/R=편집자리 이동, U/D=값 증감, C=Clear
//    센서     : L=1회 측정 (자동 주기 측정 없음. 누를 때마다 한 번씩)
//
//  UART 명령 : ascii_decoder.v 상단 주석 참고
//  UART 송신 : 1초마다 + 센서 측정 완료마다 현재 모드 값을 문자열로
//=====================================================================
// 아래 파라미터는 전부 100MHz 실보드 기준 값이다.
// 시뮬레이션에서는 top #(...) 로 확 줄여서 인스턴스하면 빨리 돈다.
// (tb_top.v 참고)
module top #(
    parameter SYS_CLK      = 100_000_000,
    parameter BAUD         = 9600,
    parameter DEBOUNCE_CNT = 100_000,      // 버튼 샘플 1ms
    parameter FND_SCAN_CNT = 100_000,      // FND 자리 스캔 1kHz
    parameter TICK_100HZ   = 1_000_000,    // 스톱워치/시계 10ms
    parameter TICK_1US     = 100,          // 센서 1us
    parameter DHT_GUARD_US = 1_000_000,    // 전원 안정화/최소 측정 간격 1s
    parameter SEND_PERIOD  = 100_000_000   // UART 자동송신 1s
) (
    input clk,
    input reset,

    input [3:0] sw,

    input btn_L,
    input btn_R,
    input btn_U,
    input btn_D,

    // UART (PC USB-RS232)
    input  rx,
    output tx,

    // HC-SR04
    input  echo,
    output trigger,

    // DHT11
    inout dht11_io,

    // FND
    output [3:0] fnd_com,
    output [7:0] fnd_data,

    output [7:0] led
);

    // BTNC asserts reset immediately.  Deassertion is synchronized to the
    // 100 MHz board clock so every block leaves reset on the same edge.
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] reset_sync;
    always @(posedge clk, posedge reset) begin
        if (reset) reset_sync <= 2'b11;
        else       reset_sync <= {reset_sync[0], 1'b0};
    end
    wire w_reset = reset_sync[1];

    //=================================================================
    // 블록 간 배선
    //=================================================================
    // BTN_UNIT -> CONTROL_UNIT (1클럭 폭 펄스)
    wire w_btn_l, w_btn_r, w_btn_u, w_btn_d;

    // UART_COMM -> CONTROL_UNIT (버튼과 같은 1클럭 폭 펄스)
    wire u_run, u_stop, u_clear, u_mode;
    wire u_up, u_down, u_left, u_right;
    wire u_sel_s, u_sel_m, u_sel_h, u_start;

    // CONTROL_UNIT -> 각 블록
    wire [1:0] w_mode_sel;
    wire       w_disp_mode;
    wire w_sw_run_stop, w_sw_clear, w_sw_count_mode;
    wire [1:0] w_wt_edit_sel;
    wire w_wt_clear, w_wt_up, w_wt_down;
    wire w_sr04_start, w_dht_start;

    // TIME_DATAPATH -> FND_DISPLAY / UART_COMM (현재 모드로 선택된 시간)
    wire [6:0] w_msec;
    wire [5:0] w_sec;
    wire [5:0] w_min;
    wire [4:0] w_hour;

    // SENSOR_UNIT -> FND_DISPLAY / UART_COMM / LED_STATUS
    wire [8:0] w_distance;
    wire       w_sr04_done, w_sr04_valid;
    wire [7:0] w_humi, w_temp;
    wire       w_dht_done, w_dht_valid;
    wire [5:0] w_dht_dbg;

    //=================================================================
    // 1) 버튼 디바운스
    //=================================================================
    btn_unit #(
        .SAMPLE_COUNT(DEBOUNCE_CNT)
    ) U_BTN_UNIT (
        .clk    (clk),
        .reset  (w_reset),
        .i_btn_l(btn_L),
        .i_btn_r(btn_R),
        .i_btn_u(btn_U),
        .i_btn_d(btn_D),
        .o_btn_l(w_btn_l),
        .o_btn_r(w_btn_r),
        .o_btn_u(w_btn_u),
        .o_btn_d(w_btn_d)
    );

    //=================================================================
    // 2) UART 통신 (UART+FIFO / ASCII Decoder / ASCII Sender)
    //     수신 : PC 문자 -> 명령 펄스 u_* -> Control Unit
    //     송신 : 1초마다 + 센서 측정 완료마다 현재 모드 값을 문자열로
    //=================================================================
    uart_comm #(
        .SYS_CLK    (SYS_CLK),
        .BAUD       (BAUD),
        .SEND_PERIOD(SEND_PERIOD)
    ) U_UART_COMM (
        .clk        (clk),
        .reset      (w_reset),

        .rx         (rx),
        .tx         (tx),

        .cmd_run    (u_run),
        .cmd_stop   (u_stop),
        .cmd_clear  (u_clear),
        .cmd_mode   (u_mode),
        .cmd_up     (u_up),
        .cmd_down   (u_down),
        .cmd_left   (u_left),
        .cmd_right  (u_right),
        .cmd_sel_s  (u_sel_s),
        .cmd_sel_m  (u_sel_m),
        .cmd_sel_h  (u_sel_h),
        .cmd_start  (u_start),

        .mode_sel   (w_mode_sel),
        .msec       (w_msec),
        .sec        (w_sec),
        .min        (w_min),
        .hour       (w_hour),
        .distance   (w_distance),
        .humidity   (w_humi),
        .temperature(w_temp),

        .sr04_done  (w_sr04_done),
        .dht_done   (w_dht_done)
    );

    //=================================================================
    // 3) Control Unit  (버튼 / UART 명령을 현재 모드로만 분배)
    //=================================================================
    main_control_unit U_CONTROL_UNIT (
        .clk          (clk),
        .reset        (w_reset),
        .sw_mode      (sw[3:1]),
        .sw_disp      (sw[0]),
        .btn_l        (w_btn_l),
        .btn_r        (w_btn_r),
        .btn_u        (w_btn_u),
        .btn_d        (w_btn_d),
        .u_run        (u_run),
        .u_stop       (u_stop),
        .u_clear      (u_clear),
        .u_mode       (u_mode),
        .u_up         (u_up),
        .u_down       (u_down),
        .u_left       (u_left),
        .u_right      (u_right),
        .u_sel_s      (u_sel_s),
        .u_sel_m      (u_sel_m),
        .u_sel_h      (u_sel_h),
        .u_start      (u_start),
        .mode_sel     (w_mode_sel),
        .disp_mode    (w_disp_mode),
        .sw_run_stop  (w_sw_run_stop),
        .sw_clear     (w_sw_clear),
        .sw_count_mode(w_sw_count_mode),
        .wt_edit_sel  (w_wt_edit_sel),
        .wt_clear     (w_wt_clear),
        .wt_up        (w_wt_up),
        .wt_down      (w_wt_down),
        .sr04_start   (w_sr04_start),
        .dht_start    (w_dht_start)
    );

    //=================================================================
    // 4) 스톱워치 / 시계 데이터패스
    //=================================================================
    time_datapath #(
        .TICK_100HZ(TICK_100HZ)
    ) U_TIME_DATAPATH (
        .clk          (clk),
        .reset        (w_reset),
        .mode_sel     (w_mode_sel),
        .sw_run_stop  (w_sw_run_stop),
        .sw_clear     (w_sw_clear),
        .sw_count_mode(w_sw_count_mode),
        .wt_edit_sel  (w_wt_edit_sel),
        .wt_clear     (w_wt_clear),
        .wt_up        (w_wt_up),
        .wt_down      (w_wt_down),
        .msec         (w_msec),
        .sec          (w_sec),
        .min          (w_min),
        .hour         (w_hour)
    );

    //=================================================================
    // 5) 센서 (SR04 / DHT11)
    //=================================================================
    sensor_unit #(
        .TICK_1US       (TICK_1US),
        .SAMPLE_GUARD_US(DHT_GUARD_US)
    ) U_SENSOR_UNIT (
        .clk         (clk),
        .reset       (w_reset),

        .sr04_start  (w_sr04_start),
        .echo        (echo),
        .trigger     (trigger),
        .distance    (w_distance),
        .sr04_done   (w_sr04_done),
        .sr04_valid  (w_sr04_valid),

        .dht_start   (w_dht_start),
        .dht11_io    (dht11_io),
        .humidity    (w_humi),
        .temperature (w_temp),
        .dht_done    (w_dht_done),
        .dht_valid   (w_dht_valid),
        .dht_dbg_step(w_dht_dbg)
    );

    //=================================================================
    // 6) FND 표시
    //=================================================================
    fnd_display #(
        .SCAN_COUNT(FND_SCAN_CNT)
    ) U_FND_DISPLAY (
        .clk        (clk),
        .reset      (w_reset),
        .mode_sel   (w_mode_sel),
        .disp_mode  (w_disp_mode),
        .msec       (w_msec),
        .sec        (w_sec),
        .min        (w_min),
        .hour       (w_hour),
        .distance   (w_distance),
        .humidity   (w_humi),
        .temperature(w_temp),
        .fnd_com    (fnd_com),
        .fnd_data   (fnd_data)
    );

    //=================================================================
    // 7) LED 상태 표시
    //=================================================================
    led_status U_LED_STATUS (
        .mode_sel    (w_mode_sel),
        .wt_edit_sel (w_wt_edit_sel),
        .sw_run_stop (w_sw_run_stop),
        .sr04_valid  (w_sr04_valid),
        .dht_valid   (w_dht_valid),
        .dht_dbg_step(w_dht_dbg),
        .led         (led)
    );

endmodule
