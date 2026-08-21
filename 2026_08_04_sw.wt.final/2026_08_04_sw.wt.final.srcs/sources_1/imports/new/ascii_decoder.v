`timescale 1ns / 1ps

// ==================== [수정 전] ====================
// 모듈 전체가 주석 처리돼 있어서 사실상 빈 파일이었음(포트도, 로직도 다 주석).
// uart_top에서 이 모듈을 인스턴스화하는 코드도 같이 주석 처리돼 있었어서,
// 키보드로 뭘 눌러도 아무 신호도 안 나오는 상태였음.
//
// module ascii_decoder (
//     input [7:0] rx_data,
//     output reg run,
//     output reg stop,
//     output reg clear,
//     output reg mode,
//     output reg up,
//     output reg down,
//     output reg left,
//     output reg right,
//     output reg S,
//     output reg M,
//     output reg H
// );
//
//     always @(*) begin
//         case (rx_data)
//             8'h72: run = 1;
//             8'h73: stop = 1;
//             8'h63: clear = 1;
//             8'h6D: mode = 1;
//             8'h55: up = 1;
//             8'h44: down = 1;
//             8'h4C: left = 1;
//             8'h52: right = 1;
//             8'h53: S = 1;
//             8'h4D: M = 1;
//             8'h48: H = 1;
//         endcase
//     end
//
// endmodule
//
// 이 코드는 주석을 풀어도 어차피 문제가 있었음:
//  1) clk/reset/rx_done이 없어서 rx_data가 바뀔 때마다(즉 매 문자 수신마다)만
//     반응하는 게 아니라, rx_data 값이 유지되는 동안 계속 그 신호가 1로 걸림.
//     예를 들어 'U'(up)를 한 번 받으면 다음 문자가 올 때까지 up=1이 계속
//     유지돼서, up이 물리는 clock_datapath 쪽 카운터가 매 클럭(100MHz)마다
//     증가해버림 -> 사실상 순식간에 값이 다 돌아버리는 것과 같음.
//  2) case문에 각 키마다 값을 대입만 하고 나머지는 그대로 두는 구조라
//     (다른 출력들의 초기값을 0으로 리셋하는 부분이 없음) 래치(latch)가
//     생기는 코드였음.
// ====================================================

// UART로 수신한 ASCII 코드(rx_data)를 워치/클락 제어 펄스로 디코딩.
// rx_done이 1클럭 뜨는 순간의 rx_data만 보고, 그 자리에서 해당 출력만
// 정확히 1클럭 폭의 펄스로 만들어 btn_debounce의 o_btn과 동일한 타이밍으로 내보낸다.
// (rx_data는 다음 문자가 올 때까지 값을 유지하므로, 펄스로 만들지 않으면
//  예를 들어 up이 계속 1로 걸려 매 클럭 카운터가 증가해버린다.)
module ascii_decoder (
    input        clk,
    input        reset,
    input  [7:0] rx_data,
    input        rx_done,
    output reg   run,
    output reg   stop,
    output reg   clear,
    output reg   mode,
    output reg   up,
    output reg   down,
    output reg   left,
    output reg   right,
    output reg   S,
    output reg   M,
    output reg   H
);
 


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            run   <= 1'b0;
            stop  <= 1'b0;
            clear <= 1'b0;
            mode  <= 1'b0;
            up    <= 1'b0;
            down  <= 1'b0;
            left  <= 1'b0;
            right <= 1'b0;
            S     <= 1'b0;
            M     <= 1'b0;
            H     <= 1'b0;
        end else begin
            // 기본값 0 : 매 클럭 클리어 후, 이번 클럭에 히트한 것만 1
            run   <= 1'b0;
            stop  <= 1'b0;
            clear <= 1'b0;
            mode  <= 1'b0;
            up    <= 1'b0;
            down  <= 1'b0;
            left  <= 1'b0;
            right <= 1'b0;
            S     <= 1'b0;
            M     <= 1'b0;
            H     <= 1'b0;

            if (rx_done) begin
                case (rx_data)
                    8'h72: run   <= 1'b1;
                    8'h73: stop  <= 1'b1;
                    8'h63: clear <= 1'b1;
                    8'h6D: mode  <= 1'b1;
                    8'h55: up    <= 1'b1;
                    8'h44: down  <= 1'b1;
                    8'h4C: left  <= 1'b1;
                    8'h52: right <= 1'b1;
                    8'h53: S     <= 1'b1;
                    8'h4D: M     <= 1'b1;
                    8'h48: H     <= 1'b1;
                    default: ;  // 매핑 안 된 키는 무시
                endcase
            end
        end
    end

endmodule
