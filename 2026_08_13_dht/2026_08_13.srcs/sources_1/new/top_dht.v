`timescale 1ns / 1ps


module top_dht (
    input clk,
    input reset,
    input btn_start,
    inout dht11_io,
    output led_valid,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire w_start;
    wire w_done;
    wire w_valid;
    wire [15:0] w_humidity;
    wire [15:0] w_temperature;

    // done 펄스마다 valid 상태를 그대로 LED에 유지 (체크섬 정상이면 켜짐)
    reg led_valid_reg;
    always @(posedge clk, posedge reset) begin
        if (reset) led_valid_reg <= 1'b0;
        else if (w_done) led_valid_reg <= w_valid;
    end
    assign led_valid = led_valid_reg;

    // 체크섬 통과(done && valid)한 값만 래치 -> 전송 중 흔들리는 값이나 깨진 데이터가 그대로 표시되는 것을 방지
    reg [15:0] humidity_reg, temperature_reg;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            humidity_reg <= 0;
            temperature_reg <= 0;
        end else if (w_done && w_valid) begin
            humidity_reg <= w_humidity;
            temperature_reg <= w_temperature;
        end
    end

    // 습도 정수부 * 100 + 온도 정수부 -> 4자리 FND에 "HHTT" 형태로 표시
    
    btn_debounce U_BTN_START (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_start),
        .o_btn(w_start)
    );

    dht U_DHT (
        .clk(clk),
        .reset(reset),
        .start(w_start),
        .humidity(w_humidity),
        .temperature(w_temperature),
        .done(w_done),
        .valid(w_valid),
        .dht11_io(dht11_io)
    );

    fnd_controller U_FND_CONTROLLER (
        .clk(clk),
        .reset(reset),
        .fnd_in(humidity_reg[15:8] * 8'd100 + temperature_reg[15:8]),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

endmodule
