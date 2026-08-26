`timescale 1ns / 1ps
//======================================================================
// top_bounce_ila  -  Basys3 버튼 바운스 실측용 top
//
//  측정 대상 : btnU (T18)  <- 여기를 손으로 눌렀다 뗀다
//  reset     : btnC (U18)  <- 최악값 카운터 초기화
//  sw[1:0]   : LED 에 뭘 띄울지 선택
//  LED[15:0] : 선택된 값 (2진수, us 단위)  -> ILA 없이도 대충 읽힌다
//
//  ILA 로 보는 법은 setup_bounce_ila.tcl 주석 참고.
//
//  자기가 만든 디바운서와 비교하고 싶으면 아래 `define 주석을 풀고
//  btn_debounce.v 를 프로젝트에 같이 넣으면 probe10 에 뜬다.
//======================================================================
//`define USE_DUT

module top_bounce_ila (
    input         clk,        // W5, 100 MHz
    input         reset,      // btnC U18
    input         btn_meas,   // btnU T18  <- 측정 대상 (생 입력)
    input  [ 1:0] sw,         // V17, V16
    output [15:0] led
);

    wire        w_btn_sync;
    wire        w_any_edge;
    wire [15:0] w_time_us;
    wire [15:0] w_settle_us;
    wire [ 7:0] w_edge_cnt;
    wire        w_is_press;
    wire        w_evt_done;
    wire [15:0] w_max_press_us;
    wire [15:0] w_max_rel_us;
    wire [ 7:0] w_max_edge_cnt;

    btn_bounce_probe #(
        .SYS_CLK (100_000_000),
        .GUARD_US(30_000)          // 30 ms 조용하면 정착 판정
    ) U_PROBE (
        .clk           (clk),
        .reset         (reset),
        .i_btn_raw     (btn_meas),
        .o_btn_sync    (w_btn_sync),
        .o_any_edge    (w_any_edge),
        .o_time_us     (w_time_us),
        .o_settle_us   (w_settle_us),
        .o_edge_cnt    (w_edge_cnt),
        .o_is_press    (w_is_press),
        .o_evt_done    (w_evt_done),
        .o_max_press_us(w_max_press_us),
        .o_max_rel_us  (w_max_rel_us),
        .o_max_edge_cnt(w_max_edge_cnt)
    );

    //------------------------------------------------------------------
    // (선택) 자기가 만든 디바운서를 같이 물려서 파형으로 비교
    //------------------------------------------------------------------
    wire w_dut_btn;
`ifdef USE_DUT
    btn_debounce U_DUT (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_meas),
        .o_btn(w_dut_btn)
    );
`else
    assign w_dut_btn = 1'b0;
`endif

    //------------------------------------------------------------------
    // LED : ILA 안 열고도 최악값을 눈으로 확인 (2진수)
    //------------------------------------------------------------------
    reg [15:0] led_r;
    always @(*) begin
        case (sw)
            2'b00:   led_r = w_max_press_us;              // press 최악 (us)
            2'b01:   led_r = w_max_rel_us;                // release 최악 (us)
            2'b10:   led_r = w_settle_us;                 // 직전 이벤트 (us)
            default: led_r = {w_max_edge_cnt, w_edge_cnt};// 엣지 수 max/직전
        endcase
    end
    assign led = led_r;

    //------------------------------------------------------------------
    // ILA
    //   probe1(any_edge) 을 storage qualifier 로 쓰면
    //   "엣지가 난 클럭"만 저장되어 4096 depth 로 엣지 4096개를 담는다.
    //   probe2(time_us) 의 이웃 샘플 차이 = 엣지 간격.
    //------------------------------------------------------------------
    ila_0 U_ILA (
        .clk    (clk),
        .probe0 (w_btn_sync),      // 1  : 원시 버튼
        .probe1 (w_any_edge),      // 1  : 엣지 펄스 (storage qualifier)
        .probe2 (w_time_us),       // 16 : us 타임스탬프
        .probe3 (w_settle_us),     // 16 : 직전 정착 시간
        .probe4 (w_edge_cnt),      // 8  : 직전 엣지 수
        .probe5 (w_evt_done),      // 1  : 이벤트 확정 펄스 (trigger)
        .probe6 (w_is_press),      // 1  : press/release
        .probe7 (w_max_press_us),  // 16 : press 최악
        .probe8 (w_max_rel_us),    // 16 : release 최악
        .probe9 (w_max_edge_cnt),  // 8  : 최다 엣지
        .probe10(w_dut_btn)        // 1  : 내 디바운서 출력 (비교용)
    );

endmodule
