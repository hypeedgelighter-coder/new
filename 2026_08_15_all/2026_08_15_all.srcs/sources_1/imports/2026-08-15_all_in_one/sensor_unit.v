`timescale 1ns / 1ps

//=====================================================================
// sensor_unit  -  SR04 + DHT11 컨트롤러 한 덩어리
//
//   start --> [sr04_controller]  --> trigger / echo   --> distance
//   start --> [dht11_controller] <-> dht11_io (양방향) --> 습도/온도
//
//  DHT11 은 체크섬을 통과한 값만 래치해서 내보낸다. 전송 중 흔들리는
//  값이나 깨진 데이터가 그대로 FND/UART 로 나가는 것을 막는다.
//  (원래 top 에 있던 humidity_reg / temperature_reg 를 그대로 옮겨 왔다)
//
//  두 컨트롤러의 동작은 건드리지 않았다.
//=====================================================================
module sensor_unit #(
    parameter integer TICK_1US        = 100,        // 1us
    parameter integer SAMPLE_GUARD_US = 1_000_000   // DHT11 최소 측정 간격 1s
) (
    input clk,
    input reset,

    //------------------- HC-SR04 -------------------
    input        sr04_start,
    input        echo,
    output       trigger,
    output [8:0] distance,
    output       sr04_done,
    output       sr04_valid,

    //------------------- DHT11 -------------------
    input        dht_start,
    inout        dht11_io,
    output [7:0] humidity,      // 정수부. 체크섬 통과한 값만 래치된다.
    output [7:0] temperature,   // 정수부. 위와 같음.
    output       dht_done,
    output       dht_valid,     // 마지막 측정의 체크섬 결과 (래치된 값)
    output [5:0] dht_dbg_step   // 진단용. 자세한 설명은 dht11_controller.v
);

    sr04_controller #(
        .TICK_1US(TICK_1US)
    ) U_SR04_CONTROLLER (
        .clk     (clk),
        .reset   (reset),
        .start   (sr04_start),
        .echo    (echo),
        .done    (sr04_done),
        .valid   (sr04_valid),
        .trigger (trigger),
        .distance(distance)
    );

    wire [15:0] w_humidity, w_temperature;
    wire        w_dht_valid;

    dht11_controller #(
        .TICK_1US       (TICK_1US),
        .SAMPLE_GUARD_US(SAMPLE_GUARD_US)
    ) U_DHT11_CONTROLLER (
        .clk        (clk),
        .reset      (reset),
        .start      (dht_start),
        .humidity   (w_humidity),
        .temperature(w_temperature),
        .done       (dht_done),
        .valid      (w_dht_valid),
        .dbg_step   (dht_dbg_step),
        .dht11_io   (dht11_io)
    );

    // 체크섬 통과한 값만 래치. 실패하면 0 으로 지운다.
    reg [15:0] humidity_reg, temperature_reg;
    reg        dht_valid_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            humidity_reg    <= 16'b0;
            temperature_reg <= 16'b0;
            dht_valid_reg   <= 1'b0;
        end else if (dht_done) begin
            dht_valid_reg <= w_dht_valid;
            if (w_dht_valid) begin
                humidity_reg    <= w_humidity;
                temperature_reg <= w_temperature;
            end else begin
                humidity_reg    <= 16'b0;
                temperature_reg <= 16'b0;
            end
        end
    end

    // 표시/전송에는 정수부만 쓴다 ([7:0] 은 소수부)
    assign humidity    = humidity_reg[15:8];
    assign temperature = temperature_reg[15:8];
    assign dht_valid   = dht_valid_reg;

endmodule
