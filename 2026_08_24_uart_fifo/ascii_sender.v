`timescale 1ns / 1ps

//=====================================================================
// ascii_sender
//   현재 선택된 모드의 값을 ASCII 문자열로 만들어 TX FIFO 에 밀어넣는다.
//   tx_full 을 보고 backpressure 를 지키므로 FIFO 가 넘치지 않는다.
//
//   전송 포맷 (모두 CR+LF 로 끝남). 라벨/단위 없이 숫자만 보낸다.
//     STOPWATCH / WATCH : FND 에 보이는 두 자리만 보낸다. 7바이트.
//                           disp_mode=0 -> "SS.mm\r\n"   예) "56.78"
//                           disp_mode=1 -> "HH:MM\r\n"   예) "12:34"
//     SR04              : "DDD\r\n"          5바이트   예) "123"
//     DHT11             : "HH TT\r\n"        7바이트   예) "60 25"
//
//   [자리수 MUX -> 시프트 레지스터로 바꾼 점]
//   uart_rx 와 구조를 대칭으로 맞췄다.
//     uart_rx : 비트를 오른쪽 시프트로 data_reg 에 "모은다"
//     여기    : 문자열을 왼쪽 시프트로 한 바이트씩 "뱉는다"
//
//   전에는 자리수 4개(a3~a0)만 저장해 두고, 매 클럭 idx_reg 로 7:1 MUX 를
//   돌려 문자를 그때그때 만들어냈다. 그래서 idx_reg / len_reg / mode_reg /
//   disp_reg 네 개가 전송 내내 살아 있어야 했고 char_out 표가 42줄이었다.
//
//   지금은 send_start 순간에 문자열 7바이트를 통째로 조립해서 shift_reg 에
//   병렬 로드한다. 그 뒤로는 맨 앞 바이트를 내보내고 8비트씩 왼쪽으로 밀기만
//   하면 된다. 덕분에 아래가 전부 사라졌다.
//     - idx_reg (몇 번째 글자인지 세던 다이얼)
//     - char_out MUX 42줄
//     - mode_reg / disp_reg (문자열이 이미 완성돼 있어 전송 중엔 불필요)
//     - a3~a0 자리수 레지스터
//
//   대신 FF 가 ~30 개에서 ~60 개로 늘었다. Artix-7 기준 무시할 수준이고,
//   tx_data 가 조합 MUX 출력이 아니라 레지스터 직결이 되어 타이밍은 오히려
//   좋아졌다.
//
//   send_start 시점의 값으로 문자열을 만들어 얼려두는 성질은 그대로다.
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

    localparam [7:0] CR = 8'h0d, LF = 8'h0a;

    localparam SW = 56;  // 문자열 최대 길이 7바이트 = 56비트

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

    //---------------- 자리수 -> ASCII 문자 (조합) ----------------
    //  BCD 한 자리 앞에 4'h3 을 붙이면 그게 곧 ASCII 다.
    //  ("0" = 8'h30 이고 자리수는 0~9 라 캐리가 없어서 덧셈이 필요 없다.
    //   아래 concat 안에서 "0"+x 를 쓰면 폭이 8비트로 잡히는지 헷갈리므로
    //   여기서 8비트 wire 로 미리 확정해 둔다.)
    wire [7:0] c_hour_10 = {4'h3, hour_10};
    wire [7:0] c_hour_1 = {4'h3, hour_1};
    wire [7:0] c_min_10 = {4'h3, min_10};
    wire [7:0] c_min_1 = {4'h3, min_1};
    wire [7:0] c_sec_10 = {4'h3, sec_10};
    wire [7:0] c_sec_1 = {4'h3, sec_1};
    wire [7:0] c_msec_10 = {4'h3, msec_10};
    wire [7:0] c_msec_1 = {4'h3, msec_1};

    wire [7:0] c_dist_100 = {4'h3, dist_100};
    wire [7:0] c_dist_10 = {4'h3, dist_10};
    wire [7:0] c_dist_1 = {4'h3, dist_1};

    wire [7:0] c_humi_10 = {4'h3, humi_10};
    wire [7:0] c_humi_1 = {4'h3, humi_1};
    wire [7:0] c_temp_10 = {4'h3, temp_10};
    wire [7:0] c_temp_1 = {4'h3, temp_1};

    //---------------- 문자열 통째로 조립 (조합) ----------------
    //  send_start 가 온 클럭에 이 값이 그대로 shift_reg 로 들어간다.
    //  왼쪽(MSB) 바이트가 가장 먼저 나간다. 8바이트씩 7칸 = 56비트.
    //  SR04 는 5바이트뿐이라 뒤 2칸은 0 으로 채우고 어차피 안 내보낸다.
    reg [SW-1:0] str_load;
    reg [   2:0] len_load;
    always @(*) begin
        case (mode_sel)
            MODE_SR04: begin  // "DDD" + CR LF
                str_load = {c_dist_100, c_dist_10, c_dist_1, CR, LF, 16'h0};
                len_load = 3'd5;
            end
            MODE_DHT11: begin  // "HH TT" 습도2 + 공백 + 온도2 + CR LF
                str_load = {c_humi_10, c_humi_1, " ", c_temp_10, c_temp_1, CR, LF};
                len_load = 3'd7;
            end
            default: begin  // STOPWATCH / WATCH : FND 와 같은 두 자리만
                if (disp_mode)  // "HH:MM"
                    str_load = {c_hour_10, c_hour_1, ":", c_min_10, c_min_1, CR, LF};
                else  // "SS.mm"
                    str_load = {c_sec_10, c_sec_1, ".", c_msec_10, c_msec_1, CR, LF};
                len_load = 3'd7;
            end
        endcase
    end

    //---------------- 상태 (레지스터 + next 짝) ----------------
    reg          c_state, n_state;
    reg [SW-1:0] shift_reg, shift_next;
    reg [   2:0] cnt_reg, cnt_next;  // 남은 바이트 수

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
    assign tx_data = shift_reg[SW-1:SW-8];  // 항상 맨 앞 바이트. MUX 없음

    //---------------- 전송 FSM : 상태 저장 (순차) ----------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state   <= IDLE;
            shift_reg <= {SW{1'b0}};
            cnt_reg   <= 3'd0;
        end else begin
            c_state   <= n_state;
            shift_reg <= shift_next;
            cnt_reg   <= cnt_next;
        end
    end

    //---------------- 전송 FSM : 다음 값 판단 (조합) ----------------
    always @(*) begin
        // 기본값은 전부 "현재값 유지". 아래에서 건드리는 것만 바뀐다.
        // 한 줄이라도 빠지면 그 신호에 래치가 합성된다.
        n_state    = c_state;
        shift_next = shift_reg;
        cnt_next   = cnt_reg;

        case (c_state)
            IDLE: begin
                if (send_start) begin
                    shift_next = str_load;  // 문자열 7바이트 병렬 로드
                    cnt_next   = len_load;
                    n_state    = SEND;
                end
            end

            SEND: begin
                if (push_ok) begin
                    // 맨 앞 바이트를 내보냈으니 8비트 왼쪽으로 민다
                    shift_next = {shift_reg[SW-9:0], 8'h00};
                    if (cnt_reg == 3'd1) n_state = IDLE;  // 방금 게 마지막
                    else cnt_next = cnt_reg - 3'd1;
                end
            end
        endcase
    end

endmodule
