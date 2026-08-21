`timescale 1ns / 1ps

//=====================================================================
// fnd_controller  (통합판)
//
//  [기존 대비 바뀐 점]
//   1) fnd_controller 가 두 벌 있었다.
//        - 시계용   : msec/sec/min/hour 를 받아서 내부에서 자리수 분리
//        - 센서용   : fnd_in[15:0] 을 받아서 상위/하위 바이트를 나눠 표시
//      두 파일이 clk_div / bcd / decoder_2x4 / digit_splitter 를
//      "같은 이름 다른 내용"으로 각각 정의해서 한 프로젝트에 못 넣었다.
//      -> "4자리 digit + dot" 인터페이스 하나로 합쳤다.
//         자리수 분리는 top 에서 모드별로 해서 넣어준다.
//         (센서용 digit_spliter 는 거리 400cm 같은 3자리 값에서
//          digit_10 = 400/10 = 40 이 되어 4비트를 넘쳐 깨졌었다.)
//
//   2) 기존 시계용은 mux_8x1 의 sel(3비트) 에 {w_dot_onoff, w_digit_sel}
//      (4비트) 를 연결해서, 상위 1비트인 w_dot_onoff 가 잘려나갔다.
//      즉 msec<50 점멸 로직이 실제로는 동작하지 않고 점이 항상 켜져 있었다.
//      -> dp 는 세그먼트 비트7 을 직접 끄는 방식으로 바꿔서 dot_on 이
//         제대로 먹는다.
//
//   3) clk_div 로 만든 1kHz 를 counter 의 클럭으로 직접 쓰던 것을
//      클럭 인에이블(scan tick)로 바꿨다. clk 단일 도메인.
//=====================================================================
module fnd_controller #(
    parameter SCAN_COUNT = 100_000  // 100MHz -> 1kHz 자리 스캔 (화면 갱신 250Hz)
) (
    input        clk,
    input        reset,
    input  [3:0] digit_1,     // an[0] : 오른쪽 첫번째
    input  [3:0] digit_10,    // an[1]
    input  [3:0] digit_100,   // an[2]
    input  [3:0] digit_1000,  // an[3] : 왼쪽 끝
    input        dot_on,      // digit_100 자리의 dp 점등 (콜론 대용)
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire [1:0] w_digit_sel;
    wire [3:0] w_bcd;
    wire [7:0] w_seg;
    wire       w_scan_tick;

    fnd_scan_tick #(
        .COUNT(SCAN_COUNT)
    ) U_SCAN_TICK (
        .clk   (clk),
        .reset (reset),
        .o_tick(w_scan_tick)
    );

    counter_4 U_COUNTER_4 (
        .clk      (clk),
        .reset    (reset),
        .tick     (w_scan_tick),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER_2x4 (
        .digit_sel(w_digit_sel),
        .fnd_com  (fnd_com)
    );

    mux_4x1 U_MUX_4x1 (
        .sel       (w_digit_sel),
        .digit_1   (digit_1),
        .digit_10  (digit_10),
        .digit_100 (digit_100),
        .digit_1000(digit_1000),
        .mux_out   (w_bcd)
    );

    seg_decoder U_SEG_DECODER (
        .bcd_in (w_bcd),
        .seg_out(w_seg)
    );

    // 공통애노드라 세그먼트는 0 일 때 켜진다. dp(bit7) 를 0 으로 눌러 점등.
    assign fnd_data = (dot_on && (w_digit_sel == 2'b10)) ? {1'b0, w_seg[6:0]} : w_seg;

endmodule


module fnd_scan_tick #(
    parameter COUNT = 100_000
) (
    input      clk,
    input      reset,
    output reg o_tick
);
    reg [$clog2(COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else begin
            o_tick <= 1'b0;
            if (counter_reg == (COUNT - 1)) begin
                counter_reg <= 0;
                o_tick      <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
            end
        end
    end
endmodule


module counter_4 (
    input        clk,
    input        reset,
    input        tick,
    output [1:0] digit_sel
);
    reg [1:0] counter_reg;
    assign digit_sel = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) counter_reg <= 0;
        else if (tick) counter_reg <= counter_reg + 1;
    end
endmodule


module decoder_2x4 (
    input      [1:0] digit_sel,
    output reg [3:0] fnd_com
);
    always @(*) begin
        case (digit_sel)
            2'b00:   fnd_com = 4'b1110;
            2'b01:   fnd_com = 4'b1101;
            2'b10:   fnd_com = 4'b1011;
            2'b11:   fnd_com = 4'b0111;
            default: fnd_com = 4'b1111;
        endcase
    end
endmodule


module mux_4x1 (
    input  [1:0] sel,
    input  [3:0] digit_1,
    input  [3:0] digit_10,
    input  [3:0] digit_100,
    input  [3:0] digit_1000,
    output [3:0] mux_out
);
    assign mux_out = (sel == 2'b00) ? digit_1 :
                     (sel == 2'b01) ? digit_10 :
                     (sel == 2'b10) ? digit_100 : digit_1000;
endmodule


// 4'h0~4'h9 : 숫자, 4'ha~4'hd : 헥사 A~d
// 4'he      : BLANK (전부 소등)  <- 자리 비울 때 사용
// 4'hf      : dp 만 점등
module seg_decoder (
    input      [3:0] bcd_in,
    output reg [7:0] seg_out
);
    always @(*) begin
        case (bcd_in)
            4'h0:    seg_out = 8'hc0;
            4'h1:    seg_out = 8'hf9;
            4'h2:    seg_out = 8'ha4;
            4'h3:    seg_out = 8'hb0;
            4'h4:    seg_out = 8'h99;
            4'h5:    seg_out = 8'h92;
            4'h6:    seg_out = 8'h82;
            4'h7:    seg_out = 8'hf8;
            4'h8:    seg_out = 8'h80;
            4'h9:    seg_out = 8'h90;
            4'ha:    seg_out = 8'h88;
            4'hb:    seg_out = 8'h83;
            4'hc:    seg_out = 8'hc6;
            4'hd:    seg_out = 8'ha1;
            4'he:    seg_out = 8'hff;  // BLANK
            4'hf:    seg_out = 8'h7f;  // dp only
            default: seg_out = 8'hff;
        endcase
    end
endmodule
