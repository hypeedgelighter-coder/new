`timescale 1ns / 1ps

//=====================================================================
// btn_debounce
//  - 눌림 상승엣지에서 1클럭 폭 펄스(o_btn)를 만든다.
//
//  [기존 대비 바뀐 점]
//   기존 코드는 clk를 나눠 만든 oclk를 always @(posedge oclk)에 직접 물려서
//   썼다. 파생 클럭(derived clock)이라 Vivado가 별도 클럭으로 잡고,
//   버튼 5개를 인스턴스하면 그만큼 클럭 도메인이 늘어난다.
//   여기서는 oclk 대신 1클럭 폭 sample tick(클럭 인에이블)으로 바꿔서
//   전부 clk 단일 도메인에서 돈다. 동작은 동일하고 타이밍만 깔끔해진다.
//   샘플 주기도 1us -> 1ms 로 늘려서 실제 기계식 버튼 채터링(수 ms)을
//   제대로 걸러낸다. (8단 시프트 * 1ms = 8ms 안정 후 인정)
//=====================================================================
module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);
    parameter SAMPLE_COUNT = 100_000;  // 100MHz 기준 1ms

    reg [$clog2(SAMPLE_COUNT)-1:0] tick_counter;
    reg sample_tick;

    reg [7:0] q_reg;
    reg edge_reg;
    wire debounce;

    // 1ms 샘플 tick 생성
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            tick_counter <= 0;
            sample_tick  <= 1'b0;
        end else begin
            sample_tick <= 1'b0;
            if (tick_counter == (SAMPLE_COUNT - 1)) begin
                tick_counter <= 0;
                sample_tick  <= 1'b1;
            end else begin
                tick_counter <= tick_counter + 1;
            end
        end
    end

    // 8단 시프트 레지스터 : 8번 연속 1이어야 눌린 것으로 인정
    always @(posedge clk, posedge reset) begin
        if (reset) q_reg <= 8'h0;
        else if (sample_tick) q_reg <= {i_btn, q_reg[7:1]};
    end

    assign debounce = &q_reg;

    // 상승엣지 검출 -> 1클럭 펄스
    always @(posedge clk, posedge reset) begin
        if (reset) edge_reg <= 1'b0;
        else edge_reg <= debounce;
    end

    assign o_btn = debounce & (~edge_reg);

endmodule
