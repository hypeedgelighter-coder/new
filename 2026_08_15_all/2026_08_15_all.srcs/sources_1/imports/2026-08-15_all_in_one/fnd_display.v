`timescale 1ns / 1ps

//=====================================================================
// fnd_display  -  자리수 분리 + 모드별 FND MUX + fnd_controller
//
//   시간/거리/온습도 --> [자리수 분리] --> [모드 MUX] --> [fnd_controller] --> FND
//
//  원래 top 에 있던 나눗셈(%10, /10) 과 always @(*) MUX 를 여기로 옮겼다.
//  이게 top 에 있으면 RTL 스키매틱에 나눗셈/MUX 로직이 상자 밖에
//  흩어져 보인다. 묶으면 "FND" 한 상자로 나온다.
//
//  fnd_controller 자체는 건드리지 않았다.
//=====================================================================
module fnd_display #(
    parameter SCAN_COUNT = 100_000   // 자리 스캔 주기 (100MHz 기준 1kHz)
) (
    input clk,
    input reset,

    input [1:0] mode_sel,
    input       disp_mode,    // 스톱워치/시계에서 0 = SS.mm, 1 = HH.MM

    input [6:0] msec,
    input [5:0] sec,
    input [5:0] min,
    input [4:0] hour,
    input [8:0] distance,
    input [7:0] humidity,     // 정수부
    input [7:0] temperature,  // 정수부

    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    localparam MODE_STOPWATCH = 2'd0,
               MODE_WATCH     = 2'd1,
               MODE_SR04      = 2'd2,
               MODE_DHT11     = 2'd3;

    localparam [3:0] BLANK = 4'he;  // seg_decoder 에서 전부 소등

    //---------------- 자리수 분리 ----------------
    wire [3:0] d_msec_1 = msec % 10;
    wire [3:0] d_msec_10 = (msec / 10) % 10;
    wire [3:0] d_sec_1 = sec % 10;
    wire [3:0] d_sec_10 = sec / 10;
    wire [3:0] d_min_1 = min % 10;
    wire [3:0] d_min_10 = min / 10;
    wire [3:0] d_hour_1 = hour % 10;
    wire [3:0] d_hour_10 = hour / 10;

    wire [3:0] d_dist_1 = distance % 10;
    wire [3:0] d_dist_10 = (distance / 10) % 10;
    wire [3:0] d_dist_100 = (distance / 100) % 10;

    wire [3:0] d_humi_1 = humidity % 10;
    wire [3:0] d_humi_10 = (humidity / 10) % 10;
    wire [3:0] d_temp_1 = temperature % 10;
    wire [3:0] d_temp_10 = (temperature / 10) % 10;

    //---------------- 모드별로 4자리에 뭘 띄울지 ----------------
    reg [3:0] fnd_d1, fnd_d10, fnd_d100, fnd_d1000;
    reg fnd_dot;

    always @(*) begin
        case (mode_sel)
            MODE_SR04: begin  // "_123" cm
                fnd_d1000 = BLANK;
                fnd_d100  = d_dist_100;
                fnd_d10   = d_dist_10;
                fnd_d1    = d_dist_1;
                fnd_dot   = 1'b0;
            end
            MODE_DHT11: begin  // "60.25" = 습도 60%, 온도 25C
                fnd_d1000 = d_humi_10;
                fnd_d100  = d_humi_1;
                fnd_d10   = d_temp_10;
                fnd_d1    = d_temp_1;
                fnd_dot   = 1'b1;
            end
            default: begin  // 스톱워치 / 시계
                if (disp_mode) begin  // HH.MM (콜론 1초 주기 점멸)
                    fnd_d1000 = d_hour_10;
                    fnd_d100  = d_hour_1;
                    fnd_d10   = d_min_10;
                    fnd_d1    = d_min_1;
                    fnd_dot   = (msec < 50);
                end else begin  // SS.mm
                    fnd_d1000 = d_sec_10;
                    fnd_d100  = d_sec_1;
                    fnd_d10   = d_msec_10;
                    fnd_d1    = d_msec_1;
                    fnd_dot   = 1'b1;
                end
            end
        endcase
    end

    fnd_controller #(
        .SCAN_COUNT(SCAN_COUNT)
    ) U_FND_CONTROLLER (
        .clk       (clk),
        .reset     (reset),
        .digit_1   (fnd_d1),
        .digit_10  (fnd_d10),
        .digit_100 (fnd_d100),
        .digit_1000(fnd_d1000),
        .dot_on    (fnd_dot),
        .fnd_com   (fnd_com),
        .fnd_data  (fnd_data)
    );

endmodule
