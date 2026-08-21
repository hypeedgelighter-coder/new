`timescale 1ns / 1ps

//=====================================================================
// 공용 tick 생성기 모음
//
//  [기존 대비 바뀐 점]
//   sr04_controller.v 와 dht_controller.v 가 서로 다른 포트를 가진
//   tick_gen 이라는 "같은 이름"의 모듈을 각각 들고 있어서, 두 파일을
//   한 프로젝트에 넣으면 모듈 이름 충돌로 합성이 안 됐다.
//   -> tick_gen_1us 하나로 합치고, DHT11 쪽은 run_stop=1, clear=0 으로
//      묶어서 쓰면 기존 동작과 동일하다.
//=====================================================================

// 1us tick (100MHz 기준). run_stop/clear 로 카운터를 세우고 지울 수 있다.
module tick_gen_1us #(
    parameter F_COUNT = 100  // 100MHz -> 1us
) (
    input      clk,
    input      reset,
    input      run_stop,
    input      clear,
    output reg o_tick
);
    reg [$clog2(F_COUNT)-1:0] clk_counter;

    always @(posedge clk, posedge reset) begin
        if (reset || clear) begin
            clk_counter <= 0;
            o_tick      <= 1'b0;
        end else begin
            o_tick <= 1'b0;
            if (run_stop) begin
                if (clk_counter == (F_COUNT - 1)) begin
                    clk_counter <= 0;
                    o_tick      <= 1'b1;
                end else begin
                    clk_counter <= clk_counter + 1;
                end
            end
        end
    end
endmodule


// 100Hz tick (10ms). 스톱워치/시계의 msec 카운터용.
module tick_gen_100hz #(
    parameter F_COUNT = 1_000_000  // 100MHz -> 100Hz
) (
    input      clk,
    input      reset,
    output reg o_tick
);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else begin
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                o_tick      <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                o_tick      <= 1'b0;
            end
        end
    end
endmodule


// 주기 펄스 생성기. en=0 이면 카운터를 세워두고 리셋한다.
// 센서 자동 측정 트리거 / UART 자동 송신 트리거에 쓴다.
module periodic_pulse #(
    parameter COUNT = 100_000_000  // 100MHz 기준 1초
) (
    input      clk,
    input      reset,
    input      en,
    output reg o_pulse
);
    reg [$clog2(COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_pulse     <= 1'b0;
        end else if (!en) begin
            counter_reg <= 0;
            o_pulse     <= 1'b0;
        end else begin
            o_pulse <= 1'b0;
            if (counter_reg == (COUNT - 1)) begin
                counter_reg <= 0;
                o_pulse     <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
            end
        end
    end
endmodule


// 스톱워치/시계 공용 카운터.
//  mode      : 0=업카운트, 1=다운카운트
//  up/down   : 시계 설정용 1클럭 펄스 (i_tick 과 무관하게 즉시 +1/-1)
//  o_tick    : 자리올림(넘침) 펄스 -> 상위 자리 카운터의 i_tick 으로 연결
module time_counter #(
    parameter BIT_WIDTH = 7,
    parameter TIMES     = 100,
    parameter INIT_VAL  = 0
) (
    input                  clk,
    input                  reset,
    input                  i_tick,
    input                  mode,
    input                  clear,
    input                  run_stop,
    input                  up,
    input                  down,
    output [BIT_WIDTH-1:0] time_count,
    output reg             o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;
    assign time_count = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= INIT_VAL;
            o_tick      <= 1'b0;
        end else if (clear) begin
            counter_reg <= INIT_VAL;
            o_tick      <= 1'b0;
        end else if (up | down) begin
            if (up) counter_reg <= (counter_reg == (TIMES - 1)) ? 0 : counter_reg + 1;
            else counter_reg <= (counter_reg == 0) ? (TIMES - 1) : counter_reg - 1;
            o_tick <= 1'b0;
        end else if (run_stop && i_tick) begin
            if (!mode) begin
                if (counter_reg == (TIMES - 1)) begin
                    counter_reg <= 0;
                    o_tick      <= 1'b1;
                end else begin
                    counter_reg <= counter_reg + 1;
                    o_tick      <= 1'b0;
                end
            end else begin
                if (counter_reg == 0) begin
                    counter_reg <= (TIMES - 1);
                    o_tick      <= 1'b1;
                end else begin
                    counter_reg <= counter_reg - 1;
                    o_tick      <= 1'b0;
                end
            end
        end else begin
            o_tick <= 1'b0;
        end
    end
endmodule
