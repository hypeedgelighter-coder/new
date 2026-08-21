`timescale 1ns / 1ps

//=====================================================================
// btn_unit  -  버튼 4개 디바운스를 한 덩어리로
//
//   btn_L/R/U/D --> [btn_debounce] x4 --> 1클럭 폭 펄스
//
//  btn_debounce 자체는 그대로다. 같은 모듈 4개를 top 에 늘어놓으면 RTL
//  스키매틱에 상자가 4개 흩어져 보이는데, 여기 묶으면 "Btn Debounce"
//  한 상자로 나온다.
//=====================================================================
module btn_unit #(
    parameter SAMPLE_COUNT = 100_000   // 버튼 샘플 주기 (100MHz 기준 1ms)
) (
    input  clk,
    input  reset,

    input  i_btn_l,
    input  i_btn_r,
    input  i_btn_u,
    input  i_btn_d,

    output o_btn_l,
    output o_btn_r,
    output o_btn_u,
    output o_btn_d
);

    btn_debounce #(
        .SAMPLE_COUNT(SAMPLE_COUNT)
    ) U_BD_L (
        .clk  (clk),
        .reset(reset),
        .i_btn(i_btn_l),
        .o_btn(o_btn_l)
    );

    btn_debounce #(
        .SAMPLE_COUNT(SAMPLE_COUNT)
    ) U_BD_R (
        .clk  (clk),
        .reset(reset),
        .i_btn(i_btn_r),
        .o_btn(o_btn_r)
    );

    btn_debounce #(
        .SAMPLE_COUNT(SAMPLE_COUNT)
    ) U_BD_U (
        .clk  (clk),
        .reset(reset),
        .i_btn(i_btn_u),
        .o_btn(o_btn_u)
    );

    btn_debounce #(
        .SAMPLE_COUNT(SAMPLE_COUNT)
    ) U_BD_D (
        .clk  (clk),
        .reset(reset),
        .i_btn(i_btn_d),
        .o_btn(o_btn_d)
    );

endmodule
