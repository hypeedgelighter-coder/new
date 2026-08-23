`timescale 1ns / 1ps

//=====================================================================
// ascii_sender  (신규)
//   현재 선택된 모드의 값을 ASCII 문자열로 만들어 TX FIFO 에 밀어넣는다.
//   tx_full 을 보고 backpressure 를 지키므로 FIFO 가 넘치지 않는다.
//
//   전송 포맷 (모두 CR+LF 로 끝남)
//     STOPWATCH / WATCH : FND 에 보이는 두 자리만 보낸다. 7바이트.
//                           disp_mode=0 -> "SS.mm\r\n"   예) "56.78"
//                           disp_mode=1 -> "HH:MM\r\n"   예) "12:34"
//     SR04              : "DIST 123cm\r\n"    12바이트
//     DHT11             : "H 60% T 25C\r\n"   13바이트
//
//   [기존 대비 바뀐 점]
//   시간 문자열이 "HH:MM:SS.mm" 13바이트였다. 통신 확인 용도라 FND 와
//   같은 두 자리만 보내면 충분해서, sw[0](disp_mode)로 고르게 바꿨다.
//   덕분에 자리수 레지스터가 a7~a0 8개에서 a3~a0 4개로 줄었고,
//   시간/SR04/DHT11 이 같은 4칸을 나눠 쓴다.
//
//   send_start 가 들어온 시점의 값을 자리수로 쪼개 래치해 두고 보낸다.
//   (전송 도중 카운터가 굴러도 문자열이 섞이지 않게)
//=====================================================================
module ascii_sender (
    input clk,
    input reset,

    input [1:0] mode_sel,
    input       disp_mode,  // sw[0] : 0 = SS.mm, 1 = HH:MM (FND 와 동일)

    input [6:0] msec,
    input [5:0] sec,
    input [5:0] min,
    input [4:0] hour,
    input [8:0] distance,
    input [7:0] humidity,    // 정수부
    input [7:0] temperature, // 정수부

    input send_start,  // 1클럭 펄스

    output [7:0] tx_data,
    output       tx_push,
    input        tx_full
);

    localparam MODE_STOPWATCH = 2'd0,
               MODE_WATCH     = 2'd1,
               MODE_SR04      = 2'd2,
               MODE_DHT11     = 2'd3;

    localparam IDLE = 1'b0, SEND = 1'b1;

    localparam [4:0] LEN_TIME = 5'd7, LEN_DIST = 5'd12, LEN_DHT = 5'd13;

    localparam [7:0] CR = 8'h0d, LF = 8'h0a;

    //---------------- 입력값 자리수 분리 (조합) ----------------
    wire [3:0] hour_10 = hour / 10;
    wire [3:0] hour_1 = hour % 10;
    wire [3:0] min_10 = min / 10;
    wire [3:0] min_1 = min % 10;
    wire [3:0] sec_10 = sec / 10;
    wire [3:0] sec_1 = sec % 10;
    wire [3:0] msec_10 = (msec / 10) % 10;
    wire [3:0] msec_1 = msec % 10;

    wire [3:0] dist_100 = (distance / 100) % 10;
    wire [3:0] dist_10 = (distance / 10) % 10;
    wire [3:0] dist_1 = distance % 10;

    wire [3:0] humi_10 = (humidity / 10) % 10;
    wire [3:0] humi_1 = humidity % 10;
    wire [3:0] temp_10 = (temperature / 10) % 10;
    wire [3:0] temp_1 = temperature % 10;

    //---------------- 상태 ----------------
    reg        c_state;
    reg  [4:0] idx_reg;
    reg  [4:0] len_reg;
    reg  [1:0] mode_reg;
    reg        disp_reg;  // 요청 순간의 sw[0]. 구분자(':' / '.') 를 고른다.

    // 전송 시작 시점에 래치한 자리수. a0 이 가장 마지막(오른쪽) 자리.
    // 네 모드가 같은 4칸을 나눠 쓴다.
    //   시간   : a3 a2 . a1 a0   (disp_mode=1 이면 a3 a2 : a1 a0)
    //   SR04   :    a2 a1 a0
    //   DHT11  : a3 a2 % a1 a0
    reg [3:0] a0, a1, a2, a3;

    //---------------- idx -> 문자 (조합) ----------------
    reg [7:0] char_out;
    always @(*) begin
        char_out = " ";
        case (mode_reg)
            MODE_SR04: begin
                case (idx_reg)
                    5'd0: char_out = "D";
                    5'd1: char_out = "I";
                    5'd2: char_out = "S";
                    5'd3: char_out = "T";
                    5'd4: char_out = " ";
                    5'd5: char_out = "0" + a2;
                    5'd6: char_out = "0" + a1;
                    5'd7: char_out = "0" + a0;
                    5'd8: char_out = "c";
                    5'd9: char_out = "m";
                    5'd10: char_out = CR;
                    5'd11: char_out = LF;
                    default: char_out = " ";
                endcase
            end
            MODE_DHT11: begin
                case (idx_reg)
                    5'd0: char_out = "H";
                    5'd1: char_out = " ";
                    5'd2: char_out = "0" + a3;
                    5'd3: char_out = "0" + a2;
                    5'd4: char_out = "%";
                    5'd5: char_out = " ";
                    5'd6: char_out = "T";
                    5'd7: char_out = " ";
                    5'd8: char_out = "0" + a1;
                    5'd9: char_out = "0" + a0;
                    5'd10: char_out = "C";
                    5'd11: char_out = CR;
                    5'd12: char_out = LF;
                    default: char_out = " ";
                endcase
            end
            default: begin  // STOPWATCH / WATCH : 두 자리만 (7바이트)
                // 어느 두 자리를 담을지는 아래 IDLE 에서 이미 정해졌다.
                // 여기서 disp_reg 가 정하는 건 가운데 구분자뿐이다.
                case (idx_reg)
                    5'd0: char_out = "0" + a3;
                    5'd1: char_out = "0" + a2;
                    5'd2: char_out = disp_reg ? ":" : ".";
                    5'd3: char_out = "0" + a1;
                    5'd4: char_out = "0" + a0;
                    5'd5: char_out = CR;
                    5'd6: char_out = LF;
                    default: char_out = " ";
                endcase
            end
        endcase
    end

    //---------------- FIFO 로 밀어넣기 (조합) ----------------
    //  tx_full 을 확인한 "그 클럭에" push 를 내보낸다.
    //
    //  [주의] push 를 레지스터로 한 클럭 늦게 내보내면 안 된다.
    //  FIFO 는 we = push & ~full 이라, 확인한 다음 클럭에 full 이 되어
    //  있으면 그 바이트는 조용히 버려진다. 그런데 sender 는 이미 다음
    //  문자로 넘어간 뒤라 문자가 하나씩 사라진다.
    //  (실제로 시뮬에서 "H 60% T 25C" 가 "H 60%T2C" 로 깨졌다)
    wire push_ok = (c_state == SEND) && !tx_full;

    assign tx_push = push_ok;
    assign tx_data = char_out;

    //---------------- 전송 FSM ----------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            idx_reg <= 0;
            len_reg <= 0;
            mode_reg <= MODE_STOPWATCH;
            disp_reg <= 1'b0;
            {a3, a2, a1, a0} <= 16'h0;
        end else begin
            case (c_state)
                IDLE: begin
                    if (send_start) begin
                        mode_reg <= mode_sel;
                        disp_reg <= disp_mode;
                        idx_reg  <= 0;
                        c_state  <= SEND;
                        case (mode_sel)
                            MODE_SR04: begin
                                a2      <= dist_100;
                                a1      <= dist_10;
                                a0      <= dist_1;
                                len_reg <= LEN_DIST;
                            end
                            MODE_DHT11: begin
                                a3      <= humi_10;
                                a2      <= humi_1;
                                a1      <= temp_10;
                                a0      <= temp_1;
                                len_reg <= LEN_DHT;
                            end
                            default: begin  // STOPWATCH / WATCH
                                // FND 가 보여주는 두 자리를 그대로 담는다
                                if (disp_mode) begin  // HH:MM
                                    a3 <= hour_10;
                                    a2 <= hour_1;
                                    a1 <= min_10;
                                    a0 <= min_1;
                                end else begin  // SS.mm
                                    a3 <= sec_10;
                                    a2 <= sec_1;
                                    a1 <= msec_10;
                                    a0 <= msec_1;
                                end
                                len_reg <= LEN_TIME;
                            end
                        endcase
                    end
                end

                SEND: begin
                    if (push_ok) begin
                        if (idx_reg == (len_reg - 1)) c_state <= IDLE;
                        else idx_reg <= idx_reg + 1;
                    end
                end
            endcase
        end
    end

endmodule
