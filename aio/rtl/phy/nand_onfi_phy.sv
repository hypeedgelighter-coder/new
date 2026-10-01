`timescale 1ns/1ps

// =============================================================================
// nand_onfi_cycle : ONFI async 버스의 "한 사이클"
//
//   NAND 와 주고받는 모든 것은 네 종류의 사이클 중 하나다.
//     CMD   : CLE = 1 로 두고 WE# 펄스      (DQ = 커맨드)
//     ADDR  : ALE = 1 로 두고 WE# 펄스      (DQ = 주소)
//     WDATA : CLE = ALE = 0 에서 WE# 펄스   (DQ = 쓸 데이터)
//     RDATA : CLE = ALE = 0 에서 RE# 펄스   (DQ 는 NAND 가 몬다)
//
//   한 사이클은 세 구간이다. 길이는 전부 클럭 수(파라미터)다.
//
//            | SETUP  |   PULSE    |  HOLD  |
//     CLE/ALE ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
//     DQ(out) =========== valid ============---
//     WE#     ‾‾‾‾‾‾‾‾‾\____________/‾‾‾‾‾‾‾‾‾‾
//                                  ^ NAND 가 DQ 를 잡는 순간 (상승 엣지)
//
//     SETUP : CLE / ALE / DQ 를 먼저 세워 둔다            -> tCLS, tALS, tDS
//     PULSE : WE# (또는 RE#) 를 내린다                    -> tWP, tRP, tREA
//     HOLD  : 스트로브를 올리고 나머지는 그대로 유지한다  -> tCLH, tALH, tDH, tWH, tREH
//
//   [읽기 데이터를 언제 잡나]
//   RE# 를 올리는 바로 그 클럭 엣지에서 DQ 를 잡는다. RE# 는 우리가 만든 신호라
//   NAND 데이터가 언제 나오는지(tREA) 를 우리가 안다. 그래서 동기화 플롭 없이
//   한 번에 잡아도 되고, 조건은 "PULSE 구간 길이 >= tREA + setup" 하나다.
//   (R/B# 는 NAND 가 제멋대로 움직이는 비동기 신호라서 따로 2단 동기화한다)
//
//   [출력은 전부 플립플롭에서 바로 나간다]
//   WE# / RE# 에 글리치가 생기면 NAND 는 그걸 진짜 펄스로 받아들인다.
//   조합 논리를 거치지 않은 레지스터 출력이어야 한다.
// =============================================================================
module nand_onfi_cycle #(
    parameter int T_SU = 1,     // SETUP 클럭 수 (>= 1)
    parameter int T_PW = 3,     // PULSE 클럭 수 (>= 1)
    parameter int T_HD = 2      // HOLD  클럭 수 (>= 1)
) (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       req,     // ready 일 때 1 이면 사이클을 시작한다
    input  logic [1:0] kind,    // KIND_*
    input  logic [7:0] wdata,
    output logic       ready,   // 쉬는 중
    output logic       done,    // 사이클의 마지막 클럭에 1 (한 클럭)
    output logic [7:0] rdata,   // RDATA 결과. done 과 함께 유효하다

    output logic       nand_cle,
    output logic       nand_ale,
    output logic       nand_we_n,
    output logic       nand_re_n,
    output logic [7:0] nand_dq_o,
    output logic       nand_dq_oe,
    input  logic [7:0] nand_dq_i
);
    localparam logic [1:0] KIND_CMD   = 2'd0;
    localparam logic [1:0] KIND_ADDR  = 2'd1;
    localparam logic [1:0] KIND_WDATA = 2'd2;
    localparam logic [1:0] KIND_RDATA = 2'd3;

    typedef enum logic [1:0] {
        C_IDLE, C_SETUP, C_PULSE, C_HOLD
    } cyc_state_t;

    cyc_state_t state;
    logic [1:0] kind_q;
    logic [7:0] cnt;

    assign ready = (state == C_IDLE);
    assign done  = (state == C_HOLD) && (cnt == 0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= C_IDLE;
            kind_q     <= KIND_CMD;
            cnt        <= '0;
            rdata      <= '0;
            nand_cle   <= 1'b0;
            nand_ale   <= 1'b0;
            nand_we_n  <= 1'b1;
            nand_re_n  <= 1'b1;
            nand_dq_o  <= '0;
            nand_dq_oe <= 1'b0;
        end else begin
            case (state)
                C_IDLE: begin
                    if (req) begin
                        kind_q     <= kind;
                        nand_cle   <= (kind == KIND_CMD);
                        nand_ale   <= (kind == KIND_ADDR);
                        nand_dq_o  <= wdata;
                        nand_dq_oe <= (kind != KIND_RDATA);  // 읽을 때는 버스를 놓는다
                        cnt        <= 8'(T_SU - 1);
                        state      <= C_SETUP;
                    end
                end

                C_SETUP: begin
                    if (cnt == 0) begin
                        if (kind_q == KIND_RDATA) nand_re_n <= 1'b0;
                        else                      nand_we_n <= 1'b0;
                        cnt   <= 8'(T_PW - 1);
                        state <= C_PULSE;
                    end else cnt <= cnt - 1'b1;
                end

                C_PULSE: begin
                    if (cnt == 0) begin
                        nand_we_n <= 1'b1;
                        nand_re_n <= 1'b1;
                        rdata     <= nand_dq_i;     // RE# 가 올라가는 엣지에서 잡는다
                        cnt       <= 8'(T_HD - 1);
                        state     <= C_HOLD;
                    end else cnt <= cnt - 1'b1;
                end

                C_HOLD: begin
                    if (cnt == 0) begin
                        nand_cle   <= 1'b0;
                        nand_ale   <= 1'b0;
                        nand_dq_oe <= 1'b0;
                        state      <= C_IDLE;
                    end else cnt <= cnt - 1'b1;
                end

                default: state <= C_IDLE;
            endcase
        end
    end
endmodule


// =============================================================================
// nand_onfi_phy : aio_nand_dma_ctrl 의 트랜잭션 포트 <-> 실제 NAND 핀
//
//   코어는 "PROGRAM row=5, 16 word" 같은 트랜잭션만 안다. 이 모듈이 그걸
//   NAND 가 알아듣는 커맨드 시퀀스로 풀어 준다.
//
//     PROGRAM : 80h - 주소 5 - (tADL) - 데이터 - 10h - (tWB) - R/B# 대기 - 70h - status
//     READ    : 00h - 주소 5 - 30h - (tWB) - R/B# 대기 - (tRR) - 데이터
//     ERASE   : 60h - 주소 3 - D0h - (tWB) - R/B# 대기 - 70h - status
//     RESET   : FFh - (tWB) - R/B# 대기          (nand_cmd = 3. 전원 인가 직후 자동으로 한 번)
//
//   [페이지 안에서의 배치 - codeword interleave]
//     word 하나 = 5 byte 가 연달아 놓인다 :  d[7:0] d[15:8] d[23:16] d[31:24] ecc
//     데이터와 그 ECC 를 붙여 두면 PHY 가 한 워드를 읽자마자 코어에 넘길 수 있다.
//     (spare 영역에 ECC 를 몰아 두면 PHY 가 페이지 전체를 한 번 더 버퍼링해야 한다)
//
//   [지운 페이지 문제와 ECC 마스크]
//     지운 페이지는 전부 0xFF 다. 그런데 데이터 0xFFFF_FFFF 의 SEC-DED ECC 는
//     0x18 이지 0x7F 가 아니다. 그대로 두면 "지운 페이지를 읽었더니 워드마다
//     정정 불가" 가 된다. 그래서 ECC 를 0x67 (= 0x18 ^ 0x7F) 과 XOR 해서 저장한다.
//     Hamming 코드는 선형이라 쓸 때와 읽을 때 같은 상수를 XOR 해도 정정 능력은
//     그대로고, 지운 페이지가 "에러 없음" 으로 읽힌다. ECC byte 의 남는 bit7 은
//     1 로 써서 지운 상태와 맞춘다.
//
//   [예외]
//     - R/B# 가 2^RB_TIMEOUT_W 클럭 안에 안 돌아오면 done + fail 로 끝낸다.
//     - 코어가 watchdog 으로 먼저 떠나 버리면 데이터 스트림이 멈춘다.
//       2^STALL_W 클럭 동안 handshake 가 없으면 NAND 에 FFh 를 보내 정리하고
//       IDLE 로 돌아간다 (이때는 done 을 내지 않는다. 받을 상대가 없다).
//     - PROGRAM / ERASE 뒤에는 status 를 읽어 FAIL(bit0) 또는 쓰기 금지(bit7 = 0)
//       이면 fail 을 올린다.
// =============================================================================
module nand_onfi_phy #(
    parameter int WORD_COUNT_WIDTH = 16,
    parameter int T_SU         = 1,     // nand_onfi_cycle 참고 (클럭 수)
    parameter int T_PW         = 3,
    parameter int T_HD         = 2,
    parameter int T_WAIT       = 16,    // tWB / tWHR / tADL / tRR 공용 대기 (클럭 수)
    parameter int RB_TIMEOUT_W = 24,
    parameter int STALL_W      = 10
) (
    input  logic                        clk,
    input  logic                        rst_n,

    // ---------------- 코어 쪽 트랜잭션 포트 ----------------
    input  logic                        cmd_valid,
    output logic                        cmd_ready,
    input  logic [1:0]                  cmd,
    input  logic [23:0]                 row,
    input  logic [WORD_COUNT_WIDTH-1:0] words,

    input  logic                        w_valid,
    output logic                        w_ready,
    input  logic [31:0]                 w_data,
    input  logic [6:0]                  w_ecc,
    input  logic                        w_last,

    output logic                        r_valid,
    input  logic                        r_ready,
    output logic [31:0]                 r_data,
    output logic [6:0]                  r_ecc,
    output logic                        r_last,

    output logic                        done,
    output logic                        fail,

    // ---------------- 상태 / 제어 ----------------
    input  logic                        write_protect,  // 1 이면 WP# = 0
    output logic                        init_done,      // 전원 인가 후 RESET 이 끝났다
    output logic [7:0]                  nand_status,    // 마지막으로 읽은 status byte

    // ---------------- NAND 핀 ----------------
    output logic                        nand_ce_n,
    output logic                        nand_cle,
    output logic                        nand_ale,
    output logic                        nand_we_n,
    output logic                        nand_re_n,
    output logic                        nand_wp_n,
    output logic [7:0]                  nand_dq_o,
    output logic                        nand_dq_oe,
    input  logic [7:0]                  nand_dq_i,
    input  logic                        nand_rb_n
);
    localparam logic [1:0] OP_PROGRAM = 2'd0;
    localparam logic [1:0] OP_READ    = 2'd1;
    localparam logic [1:0] OP_ERASE   = 2'd2;
    localparam logic [1:0] OP_RESET   = 2'd3;

    localparam logic [1:0] KIND_CMD   = 2'd0;
    localparam logic [1:0] KIND_ADDR  = 2'd1;
    localparam logic [1:0] KIND_WDATA = 2'd2;
    localparam logic [1:0] KIND_RDATA = 2'd3;

    localparam logic [6:0] ECC_ERASED_MASK = 7'h67;

    localparam int WAIT_W = (T_WAIT > 1) ? $clog2(T_WAIT) : 1;

    typedef enum logic [4:0] {
        P_INIT,         // 리셋 직후 : 잠깐 기다렸다가 FFh
        P_IDLE,
        P_CMD1,         // 80h / 00h / 60h / FFh
        P_ADDR,
        P_WAIT_ADL,     // 주소 -> 데이터 (tADL)
        P_W_BEAT,       // 코어에서 word 하나 받기
        P_W_BYTE,       // 5 byte 로 풀어 쓰기
        P_CMD2,         // 10h / 30h / D0h
        P_WAIT_WB,      // R/B# 가 내려올 시간을 준다 (tWB)
        P_WAIT_RB,      // R/B# = 1 대기
        P_STAT_CMD,     // 70h
        P_WAIT_RD,      // 읽기 전 대기 (tWHR / tRR)
        P_STAT_RD,
        P_R_BYTE,       // 5 byte 읽어 모으기
        P_R_BEAT,       // 코어에 word 하나 넘기기
        P_DONE
    } phy_state_t;

    phy_state_t state;

    logic [1:0]                  op_q;
    logic                        quiet_q;       // 1 이면 끝나도 done 을 내지 않는다
    logic [23:0]                 row_q;
    logic [WORD_COUNT_WIDTH-1:0] words_q;
    logic [WORD_COUNT_WIDTH-1:0] widx;
    logic [2:0]                  aidx;
    logic [2:0]                  bidx;
    logic [39:0]                 sh;            // {ecc byte, data[31:0]}
    logic                        last_q;
    logic                        fail_q;
    logic [WAIT_W-1:0]           wait_cnt;
    logic [RB_TIMEOUT_W-1:0]     to_cnt;
    logic [STALL_W-1:0]          stall_cnt;

    logic       cyc_req, cyc_ready, cyc_done;
    logic [1:0] cyc_kind;
    logic [7:0] cyc_wdata, cyc_rdata;

    logic [1:0] rb_meta;
    logic       rb_sync;

    // ---------------- R/B# 2단 동기화 ----------------
    // 리셋 값은 0 (busy). 동기화가 끝나기 전에 "ready 다" 로 오해하지 않게 한다.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rb_meta <= 2'b00;
        else        rb_meta <= {rb_meta[0], nand_rb_n};
    end
    assign rb_sync = rb_meta[1];

    // ---------------- CE# / WP# ----------------
    // 동작 하나(커맨드 ~ status)가 끝날 때까지 CE# 를 계속 잡고 있는다.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nand_ce_n <= 1'b1;
            nand_wp_n <= 1'b0;      // 리셋 중에는 쓰기 금지가 안전한 쪽이다
        end else begin
            nand_ce_n <= (state == P_IDLE) || (state == P_INIT);
            nand_wp_n <= !write_protect;
        end
    end

    // ---------------- 커맨드 / 주소 바이트 ----------------
    logic [7:0] cmd1_byte, cmd2_byte, addr_byte;

    always_comb begin
        case (op_q)
            OP_PROGRAM: begin cmd1_byte = 8'h80; cmd2_byte = 8'h10; end
            OP_READ:    begin cmd1_byte = 8'h00; cmd2_byte = 8'h30; end
            OP_ERASE:   begin cmd1_byte = 8'h60; cmd2_byte = 8'hD0; end
            default:    begin cmd1_byte = 8'hFF; cmd2_byte = 8'hFF; end
        endcase
    end

    // aidx 0,1 = column (항상 0 : 페이지 맨 앞부터)   aidx 2,3,4 = row
    // ERASE 는 column 이 없어서 aidx 가 2 에서 시작한다.
    always_comb begin
        case (aidx)
            3'd2:    addr_byte = row_q[7:0];
            3'd3:    addr_byte = row_q[15:8];
            3'd4:    addr_byte = row_q[23:16];
            default: addr_byte = 8'h00;
        endcase
    end

    // ---------------- 사이클 엔진에 넘길 요청 ----------------
    always_comb begin
        cyc_req   = 1'b0;
        cyc_kind  = KIND_CMD;
        cyc_wdata = 8'h00;
        case (state)
            P_CMD1:     begin cyc_req = 1'b1; cyc_kind = KIND_CMD;   cyc_wdata = cmd1_byte; end
            P_ADDR:     begin cyc_req = 1'b1; cyc_kind = KIND_ADDR;  cyc_wdata = addr_byte; end
            P_W_BYTE:   begin cyc_req = 1'b1; cyc_kind = KIND_WDATA; cyc_wdata = sh[7:0];   end
            P_CMD2:     begin cyc_req = 1'b1; cyc_kind = KIND_CMD;   cyc_wdata = cmd2_byte; end
            P_STAT_CMD: begin cyc_req = 1'b1; cyc_kind = KIND_CMD;   cyc_wdata = 8'h70;     end
            P_STAT_RD:  begin cyc_req = 1'b1; cyc_kind = KIND_RDATA;                        end
            P_R_BYTE:   begin cyc_req = 1'b1; cyc_kind = KIND_RDATA;                        end
            default: ;
        endcase
    end

    nand_onfi_cycle #(
        .T_SU(T_SU), .T_PW(T_PW), .T_HD(T_HD)
    ) u_cycle (
        .clk       (clk),
        .rst_n     (rst_n),
        .req       (cyc_req),
        .kind      (cyc_kind),
        .wdata     (cyc_wdata),
        .ready     (cyc_ready),
        .done      (cyc_done),
        .rdata     (cyc_rdata),
        .nand_cle  (nand_cle),
        .nand_ale  (nand_ale),
        .nand_we_n (nand_we_n),
        .nand_re_n (nand_re_n),
        .nand_dq_o (nand_dq_o),
        .nand_dq_oe(nand_dq_oe),
        .nand_dq_i (nand_dq_i)
    );

    // ---------------- 코어 쪽 출력 ----------------
    assign cmd_ready = (state == P_IDLE);
    assign w_ready   = (state == P_W_BEAT);
    assign r_valid   = (state == P_R_BEAT);
    assign r_data    = sh[31:0];
    assign r_ecc     = sh[38:32] ^ ECC_ERASED_MASK;
    assign r_last    = (widx == words_q - 1'b1);
    assign done      = (state == P_DONE) && !quiet_q;
    assign fail      = fail_q;

    // ---------------- 시퀀서 ----------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= P_INIT;
            op_q        <= OP_RESET;
            quiet_q     <= 1'b1;
            row_q       <= '0;
            words_q     <= '0;
            widx        <= '0;
            aidx        <= '0;
            bidx        <= '0;
            sh          <= '0;
            last_q      <= 1'b0;
            fail_q      <= 1'b0;
            wait_cnt    <= WAIT_W'(T_WAIT - 1);
            to_cnt      <= '0;
            stall_cnt   <= '0;
            init_done   <= 1'b0;
            nand_status <= '0;
        end else begin
            case (state)
                // 전원이 막 들어온 NAND 는 FFh 를 받기 전까지 다른 커맨드를 보장하지 않는다.
                P_INIT: begin
                    if (wait_cnt == 0) state <= P_CMD1;
                    else               wait_cnt <= wait_cnt - 1'b1;
                end

                P_IDLE: begin
                    if (cmd_valid) begin
                        op_q    <= cmd;
                        quiet_q <= 1'b0;
                        row_q   <= row;
                        words_q <= words;
                        widx    <= '0;
                        aidx    <= (cmd == OP_ERASE) ? 3'd2 : 3'd0;
                        fail_q  <= 1'b0;
                        state   <= P_CMD1;
                    end
                end

                P_CMD1: begin
                    if (cyc_done) begin
                        wait_cnt <= WAIT_W'(T_WAIT - 1);
                        state    <= (op_q == OP_RESET) ? P_WAIT_WB : P_ADDR;
                    end
                end

                P_ADDR: begin
                    if (cyc_done) begin
                        if (aidx == 3'd4) begin
                            wait_cnt <= WAIT_W'(T_WAIT - 1);
                            state    <= (op_q == OP_PROGRAM) ? P_WAIT_ADL : P_CMD2;
                        end else aidx <= aidx + 1'b1;
                    end
                end

                P_WAIT_ADL: begin
                    stall_cnt <= '0;
                    if (wait_cnt == 0) state <= P_W_BEAT;
                    else               wait_cnt <= wait_cnt - 1'b1;
                end

                P_W_BEAT: begin
                    if (w_valid) begin
                        sh        <= {1'b1, w_ecc ^ ECC_ERASED_MASK, w_data};
                        last_q    <= w_last;
                        bidx      <= '0;
                        stall_cnt <= '0;
                        state     <= P_W_BYTE;
                    end else if (&stall_cnt) begin
                        // 코어가 떠났다. NAND 를 RESET 으로 정리하고 조용히 끝낸다.
                        op_q    <= OP_RESET;
                        quiet_q <= 1'b1;
                        state   <= P_CMD1;
                    end else stall_cnt <= stall_cnt + 1'b1;
                end

                P_W_BYTE: begin
                    if (cyc_done) begin
                        sh <= {8'h00, sh[39:8]};    // 낮은 바이트부터 나간다
                        if (bidx == 3'd4) state <= last_q ? P_CMD2 : P_W_BEAT;
                        else              bidx  <= bidx + 1'b1;
                    end
                end

                P_CMD2: begin
                    if (cyc_done) begin
                        wait_cnt <= WAIT_W'(T_WAIT - 1);
                        state    <= P_WAIT_WB;
                    end
                end

                // R/B# 는 확정 커맨드 뒤 tWB 안에 내려온다. 그 전에 보면 아직 1 이라
                // "벌써 끝났다" 고 착각한다. 그래서 먼저 기다린다.
                P_WAIT_WB: begin
                    to_cnt <= '0;
                    if (wait_cnt == 0) state <= P_WAIT_RB;
                    else               wait_cnt <= wait_cnt - 1'b1;
                end

                P_WAIT_RB: begin
                    wait_cnt <= WAIT_W'(T_WAIT - 1);
                    if (rb_sync) begin
                        case (op_q)
                            OP_RESET: state <= P_DONE;
                            OP_READ:  state <= P_WAIT_RD;
                            default:  state <= P_STAT_CMD;
                        endcase
                    end else if (&to_cnt) begin
                        fail_q <= 1'b1;
                        state  <= P_DONE;
                    end else to_cnt <= to_cnt + 1'b1;
                end

                P_STAT_CMD: begin
                    if (cyc_done) begin
                        wait_cnt <= WAIT_W'(T_WAIT - 1);
                        state    <= P_WAIT_RD;
                    end
                end

                P_WAIT_RD: begin
                    bidx <= '0;
                    if (wait_cnt == 0) state <= (op_q == OP_READ) ? P_R_BYTE : P_STAT_RD;
                    else               wait_cnt <= wait_cnt - 1'b1;
                end

                P_STAT_RD: begin
                    if (cyc_done) begin
                        nand_status <= cyc_rdata;
                        fail_q      <= cyc_rdata[0] || !cyc_rdata[7];
                        state       <= P_DONE;
                    end
                end

                P_R_BYTE: begin
                    if (cyc_done) begin
                        sh        <= {cyc_rdata, sh[39:8]};     // 먼저 온 바이트가 낮은 쪽
                        stall_cnt <= '0;
                        if (bidx == 3'd4) state <= P_R_BEAT;
                        else              bidx  <= bidx + 1'b1;
                    end
                end

                P_R_BEAT: begin
                    if (r_ready) begin
                        bidx <= '0;
                        if (r_last) state <= P_DONE;
                        else begin
                            widx  <= widx + 1'b1;
                            state <= P_R_BYTE;
                        end
                    end else if (&stall_cnt) begin
                        op_q    <= OP_RESET;
                        quiet_q <= 1'b1;
                        state   <= P_CMD1;
                    end else stall_cnt <= stall_cnt + 1'b1;
                end

                P_DONE: begin
                    init_done <= 1'b1;
                    state     <= P_IDLE;
                end

                default: state <= P_IDLE;
            endcase
        end
    end

`ifndef SYNTHESIS
    // 핀 레벨에서 절대 일어나면 안 되는 것들
    always_ff @(posedge clk) begin
        if (rst_n) begin
            assert (nand_we_n || nand_re_n)
                else $error("WE# and RE# low at the same time");
            assert (!(nand_cle && nand_ale))
                else $error("CLE and ALE high at the same time");
            assert (nand_re_n || !nand_dq_oe)
                else $error("driving DQ while RE# is low (bus contention)");
            assert (!nand_ce_n || (nand_we_n && nand_re_n))
                else $error("strobe while CE# is high");
        end
    end
`endif
endmodule
