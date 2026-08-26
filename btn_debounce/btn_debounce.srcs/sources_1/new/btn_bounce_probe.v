`timescale 1ns / 1ps
//======================================================================
// btn_bounce_probe
//  버튼 "원시 입력"의 실제 바운스 시간을 fabric 에서 직접 재는 계측기.
//
//  왜 ILA 파형만으로는 안 되는가:
//    100 MHz 로 그냥 샘플링하면 depth 4096 = 40.96 us 밖에 못 담는다.
//    바운스는 ms 단위라서 500배쯤 모자란다. 그래서 시간 자체는
//    여기 카운터로 세고, ILA 는 그 "결과 숫자"만 떠서 본다.
//
//  이벤트 정의:
//    첫 엣지 -> (바운스 중) -> GUARD_US 동안 엣지 없음 -> 정착 완료
//    settle_us = 첫 엣지부터 "마지막" 엣지까지의 시간 (GUARD 는 미포함)
//======================================================================
module btn_bounce_probe #(
    parameter SYS_CLK  = 100_000_000,
    parameter GUARD_US = 30_000          // 30 ms 조용하면 정착으로 판정
) (
    input             clk,
    input             reset,
    input             i_btn_raw,         // 디바운스 거치지 않은 생 버튼

    // --- ILA 용 관측 신호 ---
    output            o_btn_sync,        // 메타스테이블만 제거한 원시 버튼
    output            o_any_edge,        // 엣지마다 1클럭 펄스 (storage qualifier)
    output     [15:0] o_time_us,         // 프리러닝 us 타임스탬프 (65.5ms 랩)
    output reg [15:0] o_settle_us,       // 직전 이벤트의 정착 시간
    output reg [ 7:0] o_edge_cnt,        // 직전 이벤트의 엣지 개수
    output reg        o_is_press,        // 1=press(눌림으로 끝) 0=release
    output reg        o_evt_done,        // 이벤트 확정 1클럭 펄스 (ILA trigger)
    output reg [15:0] o_max_press_us,    // reset 이후 press 최악값
    output reg [15:0] o_max_rel_us,      // reset 이후 release 최악값
    output reg [ 7:0] o_max_edge_cnt     // reset 이후 최다 엣지 수
);

    localparam integer US_DIV = SYS_CLK / 1_000_000;   // 100 MHz -> 100

    //------------------------------------------------------------------
    // 1 us tick 프리스케일러
    //------------------------------------------------------------------
    reg [$clog2(US_DIV)-1:0] pre_cnt;
    reg                      us_tick;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            pre_cnt <= 0;
            us_tick <= 1'b0;
        end else if (pre_cnt == US_DIV - 1) begin
            pre_cnt <= 0;
            us_tick <= 1'b1;
        end else begin
            pre_cnt <= pre_cnt + 1;
            us_tick <= 1'b0;
        end
    end

    //------------------------------------------------------------------
    // 프리러닝 타임스탬프 : 엣지만 저장(storage qual)할 때 시각 축이 된다
    //------------------------------------------------------------------
    reg [15:0] time_us;
    always @(posedge clk, posedge reset) begin
        if (reset) time_us <= 16'd0;
        else if (us_tick) time_us <= time_us + 1;
    end
    assign o_time_us = time_us;

    //------------------------------------------------------------------
    // 비동기 입력 2FF 동기화 (여기서 20 ns 지연 - 측정오차로 무시 가능)
    // ASYNC_REG 로 두 FF 를 같은 슬라이스에 붙여 MTBF 확보
    //------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg btn_meta, btn_sync;

    always @(posedge clk, posedge reset) begin
        if (reset) {btn_meta, btn_sync} <= 2'b00;
        else       {btn_meta, btn_sync} <= {i_btn_raw, btn_meta};
    end
    assign o_btn_sync = btn_sync;

    // 엣지 검출 (rising / falling 모두)
    reg btn_d;
    always @(posedge clk, posedge reset) begin
        if (reset) btn_d <= 1'b0;
        else       btn_d <= btn_sync;
    end

    wire any_edge = btn_sync ^ btn_d;
    assign o_any_edge = any_edge;

    //------------------------------------------------------------------
    // 측정 FSM
    //------------------------------------------------------------------
    localparam S_IDLE = 1'b0,
               S_MEAS = 1'b1;

    reg        state;
    reg [15:0] elapsed_us;      // 첫 엣지 이후 경과 시간
    reg [15:0] last_edge_us;    // 마지막 엣지가 찍힌 시각
    reg [ 7:0] edge_cnt;        // 진행 중인 이벤트의 엣지 수

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state          <= S_IDLE;
            elapsed_us     <= 16'd0;
            last_edge_us   <= 16'd0;
            edge_cnt       <= 8'd0;
            o_settle_us    <= 16'd0;
            o_edge_cnt     <= 8'd0;
            o_is_press     <= 1'b0;
            o_evt_done     <= 1'b0;
            o_max_press_us <= 16'd0;
            o_max_rel_us   <= 16'd0;
            o_max_edge_cnt <= 8'd0;
        end else begin
            o_evt_done <= 1'b0;                      // 기본 0, 확정 때만 1클럭

            case (state)
                S_IDLE: begin
                    if (any_edge) begin              // 첫 엣지 = 이벤트 시작
                        state        <= S_MEAS;
                        elapsed_us   <= 16'd0;
                        last_edge_us <= 16'd0;
                        edge_cnt     <= 8'd1;
                    end
                end

                S_MEAS: begin
                    // 경과시간 (16'hFFFF = 65.5ms 에서 포화)
                    if (us_tick && elapsed_us != 16'hFFFF)
                        elapsed_us <= elapsed_us + 1;

                    if (any_edge) begin              // 아직 튀는 중
                        last_edge_us <= elapsed_us;
                        if (edge_cnt != 8'hFF) edge_cnt <= edge_cnt + 1;
                    end
                    else if ((elapsed_us - last_edge_us) >= GUARD_US) begin
                        // GUARD_US 동안 조용했다 -> 정착 확정
                        state       <= S_IDLE;
                        o_settle_us <= last_edge_us; // 첫 엣지 ~ 마지막 엣지
                        o_edge_cnt  <= edge_cnt;
                        o_is_press  <= btn_sync;     // 눌린 채 끝났으면 press
                        o_evt_done  <= 1'b1;

                        // 최악값 갱신 (리포트에 쓸 숫자)
                        if (btn_sync) begin
                            if (last_edge_us > o_max_press_us)
                                o_max_press_us <= last_edge_us;
                        end else begin
                            if (last_edge_us > o_max_rel_us)
                                o_max_rel_us <= last_edge_us;
                        end
                        if (edge_cnt > o_max_edge_cnt)
                            o_max_edge_cnt <= edge_cnt;
                    end
                end
            endcase
        end
    end

endmodule
