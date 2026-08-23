`timescale 1ns / 1ps

//=====================================================================
// uart_comm  -  PC 와 주고받는 UART 계층을 통째로 묶은 덩어리
//
//                        +-------------------------------------+
//   PC --TX--> rx -----> | [uart_fifo] --> [ascii_decoder] --------> cmd_* 펄스
//                        |      ^                              |
//   PC <--RX-- tx <----- | [uart_fifo] <-- [ascii_sender]  <-------- 표시값
//                        |                      ^              |
//                        |         [송신 타이밍 ('g' 요청/센서)] |
//                        +-------------------------------------+
//
//  rx_data / rx_empty / rx_pop / tx_data / tx_push / tx_full 은 이 세
//  모듈 사이에서만 쓰이는 신호다. 그동안 top 에 그대로 널려 있어서
//  top 을 읽을 때 UART 내부 배선까지 같이 읽어야 했다. 여기로 내려서
//  숨기면 top 에는 "명령 펄스 나감 / 표시값 들어옴" 만 남는다.
//
//  하위 모듈의 동작은 하나도 건드리지 않았다. 배선만 옮겨 온 것이다.
//    uart_fifo.v     : baud tick + uart_rx/uart_tx + RX/TX FIFO
//    ascii_decoder.v : 수신 바이트 -> 1클럭 명령 펄스 (문자표는 그 파일 주석)
//    ascii_sender.v  : 현재 모드 값 -> ASCII 문자열 -> TX FIFO
//=====================================================================
module uart_comm #(
    parameter SYS_CLK = 100_000_000,
    parameter BAUD    = 9600,
    parameter AWIDTH  = 4             // FIFO 깊이 2**4 = 16
) (
    input clk,
    input reset,

    // 물리 UART (PC USB-RS232)
    input  rx,
    output tx,

    //--------- 수신 : 명령 펄스 (Control Unit 으로) ---------
    //  전부 btn_debounce 의 o_btn 과 똑같은 1클럭 폭 펄스다.
    output cmd_run,
    output cmd_stop,
    output cmd_clear,
    output cmd_mode,
    output cmd_up,
    output cmd_down,
    output cmd_left,
    output cmd_right,
    output cmd_sel_s,
    output cmd_sel_m,
    output cmd_sel_h,
    output cmd_start,

    //--------- 송신 : 현재 표시값 ---------
    input [1:0] mode_sel,
    input [6:0] msec,
    input [5:0] sec,
    input [5:0] min,
    input [4:0] hour,
    input [8:0] distance,
    input [7:0] humidity,     // 정수부
    input [7:0] temperature,  // 정수부

    //--------- 송신 타이밍 : 센서 측정 완료 ---------
    input sr04_done,
    input dht_done
);

    localparam MODE_STOPWATCH = 2'd0,
               MODE_WATCH     = 2'd1,
               MODE_SR04      = 2'd2,
               MODE_DHT11     = 2'd3;

    // 여기서부터는 전부 내부 배선. 밖으로 나가지 않는다.
    wire [7:0] w_rx_data;
    wire       w_rx_empty, w_rx_pop;
    wire [7:0] w_tx_data;
    wire       w_tx_push, w_tx_full;
    wire       w_cmd_get;  // PC 가 보낸 'g' -> 한 줄 전송 요청 펄스

    uart_fifo #(
        .SYS_CLK(SYS_CLK),
        .BAUD   (BAUD),
        .AWIDTH (AWIDTH)
    ) U_UART_FIFO (
        .clk     (clk),
        .reset   (reset),
        .rx      (rx),
        .tx      (tx),
        .rx_data (w_rx_data),
        .rx_empty(w_rx_empty),
        .rx_pop  (w_rx_pop),
        .tx_data (w_tx_data),
        .tx_push (w_tx_push),
        .tx_full (w_tx_full)
    );

    ascii_decoder U_ASCII_DECODER (
        .clk      (clk),
        .reset    (reset),
        .rx_data  (w_rx_data),
        .rx_empty (w_rx_empty),
        .rx_pop   (w_rx_pop),
        .cmd_run  (cmd_run),
        .cmd_stop (cmd_stop),
        .cmd_clear(cmd_clear),
        .cmd_mode (cmd_mode),
        .cmd_up   (cmd_up),
        .cmd_down (cmd_down),
        .cmd_left (cmd_left),
        .cmd_right(cmd_right),
        .cmd_sel_s(cmd_sel_s),
        .cmd_sel_m(cmd_sel_m),
        .cmd_sel_h(cmd_sel_h),
        .cmd_start(cmd_start),
        // 이 펄스만 Control Unit 으로 안 나가고 아래 sender 로 바로 들어간다
        .cmd_get  (w_cmd_get)
    );

    //---------------- 언제 보낼지 ----------------
    //  [기존] 1초 주기 자동 송신 + 현재 모드의 센서 측정 완료
    //  [변경] PC 가 'g' 를 보내 요청할 때 + 현재 모드의 센서 측정 완료
    //
    //  주기 송신기(periodic_pulse U_SEND_TICK)와 SEND_PERIOD 파라미터를
    //  없앴다. PC 가 원할 때만 한 줄씩 받아가는 polling 방식이라 터미널이
    //  계속 스크롤되지 않고, PC 가 요청한 그 시점의 값이 그대로 온다.
    //
    //  요청이 전송 도중에 또 들어오면 ascii_sender 의 FSM 이 SEND 상태라
    //  무시된다. 문자열이 섞이지 않고 그냥 한 번만 나간다.

    // 센서 done 은 한 클럭 늦춰서 쓴다. done 이 뜨는 그 엣지에
    // sensor_unit 의 습도/온도 래치가 갱신되므로, 같은 엣지에 전송을
    // 시작하면 sender 가 갱신 전의 옛날 값을 래치해서 한 측정 뒤처진다.
    reg sr04_done_d, dht_done_d;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            sr04_done_d <= 1'b0;
            dht_done_d  <= 1'b0;
        end else begin
            sr04_done_d <= sr04_done;
            dht_done_d  <= dht_done;
        end
    end

    wire w_send_start = w_cmd_get
                      | (sr04_done_d & (mode_sel == MODE_SR04))
                      | (dht_done_d  & (mode_sel == MODE_DHT11));

    ascii_sender U_ASCII_SENDER (
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
        .send_start (w_send_start),
        .tx_data    (w_tx_data),
        .tx_push    (w_tx_push),
        .tx_full    (w_tx_full)
    );

endmodule
