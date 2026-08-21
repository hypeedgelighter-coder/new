`timescale 1ns / 1ps

//=====================================================================
// ascii_decoder
//   RX FIFO 에서 한 바이트씩 꺼내(pop) 명령 펄스로 바꾼다.
//   모든 출력은 btn_debounce 의 o_btn 과 똑같이 1클럭 폭 펄스라서
//   Control Unit 에서 버튼과 그냥 OR 로 합칠 수 있다.
//
//  [기존 대비 바뀐 점]
//   기존 ascii_decoder 는 rx_done 을 직접 받았다. 이제 앞단에 FIFO 가
//   있으므로 rx_empty 를 보고 스스로 pop 하는 구조로 바꿨다.
//   FIFO 의 r_data 는 조합 출력이라, empty=0 이면 그 자리에서 head 가
//   보인다. 그래서 "디코드 + pop 예약" 을 같은 사이클에 한다.
//
//  명령 문자표 (대소문자 구분함)
//   r : 스톱워치 RUN          s : 스톱워치 STOP
//   c : CLEAR                 m : 스톱워치 카운트방향(업/다운) 토글
//   U : UP (시계 +1)          D : DOWN (시계 -1)
//   L : LEFT (편집자리 왼쪽)  R : RIGHT (편집자리 오른쪽)
//   S : 초 편집 선택          M : 분 편집 선택        H : 시 편집 선택
//   t : 센서 수동 측정 시작 (SR04 / DHT11)
//=====================================================================
module ascii_decoder (
    input clk,
    input reset,

    input  [7:0] rx_data,
    input        rx_empty,
    output       rx_pop,

    output reg cmd_run,
    output reg cmd_stop,
    output reg cmd_clear,
    output reg cmd_mode,
    output reg cmd_up,
    output reg cmd_down,
    output reg cmd_left,
    output reg cmd_right,
    output reg cmd_sel_s,
    output reg cmd_sel_m,
    output reg cmd_sel_h,
    output reg cmd_start
);

    reg pop_reg;
    assign rx_pop = pop_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            pop_reg   <= 1'b0;
            cmd_run   <= 1'b0;
            cmd_stop  <= 1'b0;
            cmd_clear <= 1'b0;
            cmd_mode  <= 1'b0;
            cmd_up    <= 1'b0;
            cmd_down  <= 1'b0;
            cmd_left  <= 1'b0;
            cmd_right <= 1'b0;
            cmd_sel_s <= 1'b0;
            cmd_sel_m <= 1'b0;
            cmd_sel_h <= 1'b0;
            cmd_start <= 1'b0;
        end else begin
            // 기본값 0 : 매 클럭 클리어하고, 이번에 히트한 것만 1클럭 1
            pop_reg   <= 1'b0;
            cmd_run   <= 1'b0;
            cmd_stop  <= 1'b0;
            cmd_clear <= 1'b0;
            cmd_mode  <= 1'b0;
            cmd_up    <= 1'b0;
            cmd_down  <= 1'b0;
            cmd_left  <= 1'b0;
            cmd_right <= 1'b0;
            cmd_sel_s <= 1'b0;
            cmd_sel_m <= 1'b0;
            cmd_sel_h <= 1'b0;
            cmd_start <= 1'b0;

            // pop_reg 가 1인 사이클은 이미 꺼낸 바이트를 처리 중이므로 건너뛴다
            // (한 바이트당 2클럭. 9600bps 대비 압도적으로 빠르다)
            if (!rx_empty && !pop_reg) begin
                pop_reg <= 1'b1;
                case (rx_data)
                    "r": cmd_run <= 1'b1;
                    "s": cmd_stop <= 1'b1;
                    "c": cmd_clear <= 1'b1;
                    "m": cmd_mode <= 1'b1;
                    "U": cmd_up <= 1'b1;
                    "D": cmd_down <= 1'b1;
                    "L": cmd_left <= 1'b1;
                    "R": cmd_right <= 1'b1;
                    "S": cmd_sel_s <= 1'b1;
                    "M": cmd_sel_m <= 1'b1;
                    "H": cmd_sel_h <= 1'b1;
                    "t": cmd_start <= 1'b1;
                    default:
                    ;  // 매핑 안 된 문자(개행 등)는 버린다
                endcase
            end
        end
    end

endmodule
