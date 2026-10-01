`timescale 1ns/1ps

// =============================================================================
// nand_model : 핀 레벨 SLC NAND Flash 동작 모델 (ONFI async 인터페이스, 시뮬레이션 전용)
//
//   컨트롤러가 "핀을 제대로 흔드는지" 를 보려고 만든 모델이다. 하는 일은 셋이다.
//     1) 커맨드 시퀀스를 해석해서 실제 NAND 처럼 동작한다
//     2) AC 타이밍(tWP, tDS, tREA ...) 을 어기면 VIOLATION 을 찍고 센다
//     3) 테스트벤치가 뒷문(backdoor)으로 내용을 보고 / 고치고 / 고장을 심는다
//
//   [핀]
//     CE#  칩 선택          CLE  1 이면 DQ 가 커맨드      ALE  1 이면 DQ 가 주소
//     WE#  올라가는 엣지에서 DQ 를 받아들인다 (커맨드 / 주소 / 쓰기 데이터)
//     RE#  내려가면 tREA 뒤에 DQ 로 데이터가 나온다
//     WP#  0 이면 PROGRAM / ERASE 를 무시한다
//     R/B# 0 이면 내부 동작 중 (open-drain. 보드에 풀업이 있어야 한다)
//
//   [지원 커맨드]
//     FFh            RESET
//     90h + 00h      READ ID            -> RE# 마다 ID 1 byte
//     70h            READ STATUS        -> RE# 마다 status (busy 중에도 받는다)
//     00h + 주소 5 + 30h   PAGE READ    -> tR 동안 busy, 그 뒤 RE# 마다 1 byte
//     80h + 주소 5 + 데이터 + 10h  PAGE PROGRAM -> tPROG 동안 busy
//     60h + 주소 3 + D0h   BLOCK ERASE  -> tBERS 동안 busy
//
//   [NAND 의 물리 규칙 - 모델이 그대로 지킨다]
//     - PROGRAM 은 비트를 1 -> 0 으로만 바꾼다 (mem = mem & 새 데이터)
//     - 0 -> 1 은 ERASE 뿐이고, ERASE 는 "블록" 단위다
//     - 그래서 지운 페이지는 전부 0xFF 다
//
//   [status byte]  bit7 = WP# (1 = 쓰기 가능)  bit6 = RDY  bit5 = ARDY  bit0 = FAIL
//
//   타이밍 값은 ONFI async timing mode 4 수준의 대표값이다. 실제 부품에 붙일 때는
//   그 부품 데이터시트 값으로 바꿔야 한다. busy 시간(tR/tPROG/tBERS)은
//   시뮬레이션이 오래 걸리지 않게 실제(수십 us ~ 수 ms)보다 훨씬 짧게 잡았다.
// =============================================================================
module nand_model #(
    parameter int          PAGE_BYTES      = 2112,        // 2048 data + 64 spare
    parameter int          PAGES_PER_BLOCK = 64,
    parameter int          BLOCKS          = 4,
    parameter logic [31:0] ID              = 32'h9590_DA2C,

    // ---- AC 타이밍 (ns) ----
    parameter real tWP   = 12.0,   // WE# low 폭
    parameter real tWH   = 10.0,   // WE# high 폭
    parameter real tRP   = 12.0,   // RE# low 폭
    parameter real tREH  = 10.0,   // RE# high 폭
    parameter real tDS   = 10.0,   // DQ setup  (WE# 상승 기준)
    parameter real tDH   = 5.0,    // DQ hold
    parameter real tCLS  = 10.0,   // CLE setup
    parameter real tCLH  = 5.0,    // CLE hold
    parameter real tALS  = 10.0,   // ALE setup
    parameter real tALH  = 5.0,    // ALE hold
    parameter real tREA  = 20.0,   // RE# 하강 -> 데이터 유효
    parameter real tRHOH = 15.0,   // RE# 상승 뒤 데이터 유지
    parameter real tWHR  = 60.0,   // WE# 상승 -> RE# 하강 (status / ID 읽기)
    parameter real tADL  = 70.0,   // 마지막 주소 -> 첫 데이터
    parameter real tRR   = 20.0,   // R/B# 상승 -> RE# 하강
    parameter real tWB   = 100.0,  // WE# 상승 -> R/B# 하강 (최대)

    // ---- busy 시간 (ns, 시뮬레이션용으로 줄인 값) ----
    parameter real tR    = 2000.0,
    parameter real tPROG = 6000.0,
    parameter real tBERS = 12000.0,
    parameter real tRST  = 1000.0
) (
    input  wire       ce_n,
    input  wire       cle,
    input  wire       ale,
    input  wire       we_n,
    input  wire       re_n,
    input  wire       wp_n,
    inout  wire [7:0] dq,
    output wire       rb_n
);
    localparam int N_PAGES = BLOCKS * PAGES_PER_BLOCK;

    localparam int M_IDLE = 0, M_RD_ADDR = 1, M_PG_ADDR = 2, M_PG_DATA = 3,
                   M_ER_ADDR = 4, M_ID_ADDR = 5;
    localparam int O_NONE = 0, O_PAGE = 1, O_STATUS = 2, O_ID = 3;
    localparam int K_RESET = 0, K_READ = 1, K_PROG = 2, K_ERASE = 3;

    // ---------------- 저장소 ----------------
    logic [7:0] mem      [0:N_PAGES*PAGE_BYTES-1];
    logic [7:0] page_reg [0:PAGE_BYTES-1];      // 칩 안의 페이지 레지스터

    // ---------------- 커맨드 해석 상태 ----------------
    int          st;            // M_*
    int          out_mode;      // O_*
    int          acnt;          // 받은 주소 사이클 수
    int          col;           // 주소로 받은 column
    int          row;           // 주소로 받은 row (page 번호)
    int          ptr;           // 페이지 레지스터 읽기/쓰기 위치
    logic        busy;
    logic        fail_bit;      // 마지막 PROGRAM/ERASE 결과
    int          pend_kind;     // busy 가 끝날 때 적용할 동작
    int          pend_row;
    int          gen;           // busy 세대 번호 (RESET 이 이전 동작을 취소할 때 쓴다)
    int          busy_set;
    int          busy_end;
    logic        first_data;

    // ---------------- 테스트벤치가 건드리는 것 (backdoor) ----------------
    logic fail_next_prog;   // 1 이면 다음 PROGRAM 이 FAIL 로 끝난다 (한 번만)
    logic fail_next_erase;  // 1 이면 다음 ERASE  가 FAIL 로 끝난다 (한 번만)
    logic stuck_busy;       // 1 이면 busy 에서 영영 안 돌아온다 (timeout 시험용)
    int   viol_cnt;         // 타이밍 / 프로토콜 위반 횟수
    int   n_reset, n_read, n_prog, n_erase, n_wp_blocked;

    // ---------------- 타이밍 기록 ----------------
    real t_we_fall, t_we_rise, t_re_fall, t_re_rise;
    real t_dq_chg, t_cle_chg, t_ale_chg, t_addr_rise, t_ready;
    real now;

    // ---------------- DQ / R/B# 구동 ----------------
    logic [7:0] dq_drv;
    logic       dq_en;
    logic [7:0] rd_byte;
    int         rd_seq;         // RE# 하강마다 +1
    int         rel_req;        // DQ 를 놓으라는 예약 (그때의 rd_seq 값)

    assign dq   = dq_en ? dq_drv : 8'hzz;
    assign rb_n = busy ? 1'b0 : 1'bz;           // open-drain

    wire [7:0] status = {wp_n === 1'b1, ~busy, ~busy, 4'b0000, fail_bit};

    initial begin
        for (int i = 0; i < N_PAGES*PAGE_BYTES; i++) mem[i] = 8'hFF;
        for (int i = 0; i < PAGE_BYTES; i++) page_reg[i] = 8'hFF;
        st = M_IDLE; out_mode = O_NONE; acnt = 0; col = 0; row = 0; ptr = 0;
        busy = 1'b0; fail_bit = 1'b0; pend_kind = K_RESET; pend_row = 0;
        gen = 0; busy_set = 0; busy_end = 0; first_data = 1'b0;
        fail_next_prog = 1'b0; fail_next_erase = 1'b0; stuck_busy = 1'b0;
        viol_cnt = 0; n_reset = 0; n_read = 0; n_prog = 0; n_erase = 0; n_wp_blocked = 0;
        t_we_fall = 0.0; t_we_rise = 0.0; t_re_fall = 0.0; t_re_rise = 0.0;
        t_dq_chg = 0.0; t_cle_chg = 0.0; t_ale_chg = 0.0; t_addr_rise = 0.0; t_ready = 0.0;
        dq_drv = 8'h00; dq_en = 1'b0; rd_seq = 0; rel_req = 0;
    end

    // =========================================================================
    // backdoor : 테스트벤치 / 스코어보드가 부른다. 시간이 흐르지 않는다.
    // =========================================================================
    function automatic logic [7:0] peek(input int r, input int idx);
        return mem[(r % N_PAGES) * PAGE_BYTES + idx];
    endfunction

    function automatic void poke(input int r, input int idx, input logic [7:0] v);
        mem[(r % N_PAGES) * PAGE_BYTES + idx] = v;
    endfunction

    // 비트 하나를 뒤집는다 = 셀 하나가 잘못 읽히는 상황 (fault injection)
    function automatic void flip_bit(input int r, input int idx, input int b);
        mem[(r % N_PAGES) * PAGE_BYTES + idx] =
            mem[(r % N_PAGES) * PAGE_BYTES + idx] ^ (8'h01 << b);
    endfunction

    task automatic viol(input string msg);
        viol_cnt = viol_cnt + 1;
        $display("[%0t] NAND_MODEL VIOLATION: %s", $time, msg);
    endtask

    // =========================================================================
    // busy : 커맨드가 확정되면 tWB 안에 R/B# 가 내려가고, 정해진 시간 뒤에 올라온다.
    //
    //   지연 대입(<= #)으로 "세대 번호" 를 미래에 예약해 둔다. 그 사이에 RESET 이
    //   와서 gen 이 바뀌면 예약된 번호와 안 맞으므로 옛 동작은 조용히 버려진다.
    // =========================================================================
    task automatic start_busy(input int kind, input real dur);
        real wb;
        begin
            wb        = 10.0 + $urandom_range(0, 80);   // tWB 는 부품마다 / 매번 다르다
            gen       = gen + 1;
            pend_kind = kind;
            pend_row  = row;
            busy_set <= #(wb)       gen;
            busy_end <= #(wb + dur) gen;
        end
    endtask

    always @(busy_set) begin
        if ((busy_set == gen) && (busy_set != 0)) busy = 1'b1;
    end

    always @(busy_end) begin
        if ((busy_end == gen) && (busy_end != 0) && !stuck_busy) begin
            apply_op(pend_kind, pend_row);
            busy    = 1'b0;
            t_ready = $realtime;
        end
    end

    task automatic apply_op(input int kind, input int r);
        int base;
        begin
            base = (r % N_PAGES) * PAGE_BYTES;
            case (kind)
                K_READ: begin
                    for (int i = 0; i < PAGE_BYTES; i++) page_reg[i] = mem[base + i];
                    ptr      = col;
                    out_mode = O_PAGE;
                    n_read   = n_read + 1;
                end
                K_PROG: begin
                    if (fail_next_prog) begin
                        fail_bit       = 1'b1;
                        fail_next_prog = 1'b0;
                    end else begin
                        // 1 -> 0 만 된다
                        for (int i = 0; i < PAGE_BYTES; i++)
                            mem[base + i] = mem[base + i] & page_reg[i];
                        fail_bit = 1'b0;
                    end
                    n_prog = n_prog + 1;
                end
                K_ERASE: begin
                    if (fail_next_erase) begin
                        fail_bit        = 1'b1;
                        fail_next_erase = 1'b0;
                    end else begin
                        // row 가 속한 블록 전체
                        base = ((r % N_PAGES) / PAGES_PER_BLOCK) * PAGES_PER_BLOCK * PAGE_BYTES;
                        for (int i = 0; i < PAGES_PER_BLOCK*PAGE_BYTES; i++)
                            mem[base + i] = 8'hFF;
                        fail_bit = 1'b0;
                    end
                    n_erase = n_erase + 1;
                end
                default: begin  // K_RESET
                    st       = M_IDLE;
                    out_mode = O_NONE;
                    fail_bit = 1'b0;
                    n_reset  = n_reset + 1;
                end
            endcase
        end
    endtask

    // =========================================================================
    // 쓰기 쪽 : WE# 상승 엣지에서 DQ 를 받아들인다
    // =========================================================================
    always @(negedge we_n) begin
        if (ce_n === 1'b0) begin
            now = $realtime;
            if ((t_we_rise > 0.0) && ((now - t_we_rise) < tWH)) viol("tWH (WE# high width)");
            if (re_n !== 1'b1) viol("WE# low while RE# low");
            t_we_fall = now;
        end
    end

    always @(posedge we_n) begin
        if (ce_n === 1'b0) begin
            now = $realtime;
            if ((now - t_we_fall) < tWP)  viol("tWP (WE# low width)");
            if ((now - t_dq_chg)  < tDS)  viol("tDS (DQ setup)");
            if ((now - t_cle_chg) < tCLS) viol("tCLS (CLE setup)");
            if ((now - t_ale_chg) < tALS) viol("tALS (ALE setup)");
            if ((^dq) === 1'bx)           viol("DQ is X/Z at WE# rising edge");

            if (cle && ale)  viol("CLE and ALE both high");
            else if (cle)    do_command(dq);
            else if (ale)    do_address(dq);
            else             do_data(dq);

            t_we_rise = now;
        end
    end

    always @(dq) begin
        if ((ce_n === 1'b0) && (t_we_rise > 0.0) && (($realtime - t_we_rise) < tDH))
            viol("tDH (DQ hold)");
        t_dq_chg = $realtime;
    end

    always @(cle) begin
        if ((ce_n === 1'b0) && (t_we_rise > 0.0) && (($realtime - t_we_rise) < tCLH))
            viol("tCLH (CLE hold)");
        t_cle_chg = $realtime;
    end

    always @(ale) begin
        if ((ce_n === 1'b0) && (t_we_rise > 0.0) && (($realtime - t_we_rise) < tALH))
            viol("tALH (ALE hold)");
        t_ale_chg = $realtime;
    end

    task automatic do_command(input logic [7:0] c);
        begin
            if (busy && (c != 8'h70) && (c != 8'hFF)) begin
                viol("command while busy (only 70h / FFh allowed)");
            end else begin
                case (c)
                    8'hFF: begin
                        st       = M_IDLE;
                        out_mode = O_NONE;
                        start_busy(K_RESET, tRST);
                    end
                    8'h70: out_mode = O_STATUS;
                    8'h90: begin
                        st       = M_ID_ADDR;
                        out_mode = O_NONE;
                    end
                    8'h00: begin
                        st       = M_RD_ADDR;
                        acnt     = 0;
                        out_mode = O_NONE;
                    end
                    8'h30: begin
                        if ((st == M_RD_ADDR) && (acnt == 5)) begin
                            st = M_IDLE;
                            start_busy(K_READ, tR);
                        end else viol("30h without 00h + 5 address cycles");
                    end
                    8'h80: begin
                        st       = M_PG_ADDR;
                        acnt     = 0;
                        out_mode = O_NONE;
                        for (int i = 0; i < PAGE_BYTES; i++) page_reg[i] = 8'hFF;
                    end
                    8'h10: begin
                        if (st == M_PG_DATA) begin
                            st = M_IDLE;
                            if (wp_n !== 1'b1) n_wp_blocked = n_wp_blocked + 1;  // 무시. busy 도 없다
                            else               start_busy(K_PROG, tPROG);
                        end else viol("10h without 80h + address + data");
                    end
                    8'h60: begin
                        st       = M_ER_ADDR;
                        acnt     = 0;
                        out_mode = O_NONE;
                    end
                    8'hD0: begin
                        if ((st == M_ER_ADDR) && (acnt == 3)) begin
                            st = M_IDLE;
                            if (wp_n !== 1'b1) n_wp_blocked = n_wp_blocked + 1;
                            else               start_busy(K_ERASE, tBERS);
                        end else viol("D0h without 60h + 3 address cycles");
                    end
                    default: viol("unsupported command");
                endcase
            end
        end
    endtask

    task automatic do_address(input logic [7:0] a);
        begin
            case (st)
                M_RD_ADDR, M_PG_ADDR: begin
                    case (acnt)
                        0: col = a;
                        1: col = col | (a << 8);
                        2: row = a;
                        3: row = row | (a << 8);
                        4: row = row | (a << 16);
                        default: viol("too many address cycles");
                    endcase
                    acnt = acnt + 1;
                    if ((st == M_PG_ADDR) && (acnt == 5)) begin
                        st         = M_PG_DATA;
                        ptr        = col;
                        first_data = 1'b1;
                        if (row >= N_PAGES) viol("row address out of range");
                    end
                    if ((st == M_RD_ADDR) && (acnt == 5) && (row >= N_PAGES))
                        viol("row address out of range");
                end
                M_ER_ADDR: begin
                    case (acnt)
                        0: row = a;
                        1: row = row | (a << 8);
                        2: row = row | (a << 16);
                        default: viol("too many address cycles");
                    endcase
                    acnt = acnt + 1;
                    if ((acnt == 3) && (row >= N_PAGES)) viol("row address out of range");
                end
                M_ID_ADDR: begin
                    st       = M_IDLE;
                    ptr      = 0;
                    out_mode = O_ID;
                end
                default: viol("address cycle with no command pending");
            endcase
            t_addr_rise = $realtime;
        end
    endtask

    task automatic do_data(input logic [7:0] d);
        begin
            if (st != M_PG_DATA) begin
                viol("data cycle outside PAGE PROGRAM");
            end else begin
                if (first_data && (($realtime - t_addr_rise) < tADL)) viol("tADL (address to data)");
                first_data = 1'b0;
                if (ptr < PAGE_BYTES) begin
                    page_reg[ptr] = d;
                    ptr = ptr + 1;
                end else viol("data input past end of page");
            end
        end
    endtask

    // =========================================================================
    // 읽기 쪽 : RE# 하강 -> tREA 뒤 데이터. 그 전까지는 X 를 내보낸다.
    //           (컨트롤러가 너무 일찍 샘플하면 X 를 잡아서 바로 티가 난다)
    // =========================================================================
    always @(negedge re_n) begin
        if (ce_n === 1'b0) begin
            now = $realtime;
            if (we_n !== 1'b1) viol("RE# low while WE# low");
            if ((t_re_rise > 0.0) && ((now - t_re_rise) < tREH)) viol("tREH (RE# high width)");
            if ((now - t_we_rise) < tWHR) viol("tWHR (WE# high to RE# low)");

            case (out_mode)
                O_STATUS: rd_byte = status;
                O_ID:     rd_byte = (ptr < 4) ? ID[8*ptr +: 8] : 8'h00;
                O_PAGE: begin
                    if (busy) viol("page data read while busy");
                    if ((now - t_ready) < tRR) viol("tRR (ready to RE# low)");
                    if (ptr < PAGE_BYTES) rd_byte = page_reg[ptr];
                    else begin
                        rd_byte = 8'hFF;
                        viol("data output past end of page");
                    end
                end
                default: begin
                    rd_byte = 8'hxx;
                    viol("RE# pulse with nothing to read");
                end
            endcase

            rd_seq    = rd_seq + 1;
            t_re_fall = now;
            dq_en     = 1'b1;
            dq_drv    = 8'hxx;
            dq_drv   <= #(tREA) rd_byte;
        end
    end

    always @(posedge re_n) begin
        if ((ce_n === 1'b0) && dq_en) begin
            now = $realtime;
            if ((now - t_re_fall) < tRP) viol("tRP (RE# low width)");
            if ((out_mode == O_PAGE) || (out_mode == O_ID)) ptr = ptr + 1;
            t_re_rise = now;
            rel_req  <= #(tRHOH) rd_seq;    // tRHOH 뒤에 버스를 놓는다
        end
    end

    // 그 사이에 다음 RE# 가 이미 내려왔으면(rd_seq 가 바뀌었으면) 놓지 않는다
    always @(rel_req) begin
        if (rel_req == rd_seq) dq_en = 1'b0;
    end

    always @(posedge ce_n) dq_en = 1'b0;
endmodule
