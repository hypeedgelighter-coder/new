// =============================================================================
// aio_scoreboard.svh : 기준 모델 + 예측 스코어보드
//
//   [스코어보드가 아는 것]
//     APB 모니터  : CPU 가 레지스터에 뭘 쓰고 뭘 읽었나
//     DMA 모니터  : DUT 가 host memory 를 어떻게 읽고 썼나
//     NAND 모니터 : DUT 가 NAND 핀으로 어떤 커맨드 시퀀스를 내보냈나
//     backdoor    : NAND 셀에 지금 실제로 들어 있는 값
//
//   [판정 방식]
//     START 가 쓰이는 순간 "이 동작이 어떻게 끝나야 하는지" 를 미리 계산해 둔다.
//     STATUS.DONE 이 읽히면 그 예측과 아래 넷을 전부 비교한다.
//       1) STATUS / CORR_COUNT / UNCORR_COUNT / ERROR_CODE / irq
//       2) DMA 가 옮긴 주소와 데이터
//       3) NAND 핀에 나간 커맨드 / 주소 / 데이터
//       4) NAND 셀의 최종 내용 (backdoor)
//
//     테스트가 "이번엔 뭘 기대한다" 고 알려 주지 않는다. 테스트는 자극만 넣고,
//     에러 주입도 셀을 뒤집기만 한다. 스코어보드가 셀을 직접 읽어 보고 결과를
//     스스로 계산한다. 그래서 무작위 테스트를 그대로 돌릴 수 있다.
//     (유일한 예외가 cfg.expect_watchdog 다. watchdog 은 클럭 수를 세어야
//      예측할 수 있어서 테스트가 미리 알려 준다.)
// =============================================================================

// -----------------------------------------------------------------------------
// 기준 ECC 모델. RTL(secded_ecc_32.sv)은 38 자리 코드워드를 for 문으로 조립한다.
// 여기서는 "1 인 데이터 비트들의 자리 번호를 전부 XOR" 하는 방식으로 짰다.
// 같은 Hamming 코드지만 계산 경로가 달라서 서로를 검증한다.
// (이 모델 자체는 scripts/ecc_ref.py 가 만든 벡터로 시뮬레이션 시작 때 검사한다)
// -----------------------------------------------------------------------------
class aio_ref_model;
    // 데이터 비트 d (0..31) 가 코드워드에서 차지하는 자리 (1..38, 2 의 거듭제곱 제외)
    static function int data_pos(int d);
        int cnt;
        cnt = -1;
        for (int p = 1; p <= 38; p++) begin
            if ((p & (p - 1)) != 0) begin
                cnt++;
                if (cnt == d) return p;
            end
        end
        return 0;
    endfunction

    static function logic [6:0] ecc32(logic [31:0] data);
        logic [5:0] h;
        int         p;
        h = '0;
        for (int d = 0; d < 32; d++) begin
            if (data[d]) begin
                p = data_pos(d);
                h = h ^ p[5:0];
            end
        end
        return {(^data) ^ (^h), h};
    endfunction

    static function void decode(input  logic [31:0] data,
                                input  logic [6:0]  stored,
                                output int          status,
                                output logic [31:0] fixed,
                                output int          bitpos);
        logic [6:0] calc;
        logic [5:0] syn;
        bit         par;
        int         s;

        calc   = ecc32(data);
        syn    = calc[5:0] ^ stored[5:0];
        par    = (^data) ^ (^stored);           // 코드워드 전체의 패리티. 멀쩡하면 0
        s      = syn;
        fixed  = data;
        bitpos = -1;

        if ((s == 0) && !par)       status = ECC_CLEAN;
        else if ((s == 0) && par)   status = ECC_PARITY_FIXED;      // overall parity 비트만 깨짐
        else if (par && (s <= 38)) begin
            if ((s & (s - 1)) == 0) status = ECC_PARITY_FIXED;      // Hamming parity 비트가 깨짐
            else begin
                status = ECC_DATA_FIXED;
                for (int d = 0; d < 32; d++) begin
                    if (data_pos(d) == s) begin
                        fixed[d] = ~fixed[d];
                        bitpos   = d;
                    end
                end
            end
        end else                    status = ECC_UNCORR;            // 2 bit 이상
    endfunction

    // NAND 에 저장되는 ECC byte
    static function logic [7:0] ecc_byte(logic [31:0] data);
        return {1'b1, ecc32(data) ^ ECC_ERASED_MASK};
    endfunction
endclass


// -----------------------------------------------------------------------------
// 스코어보드
// -----------------------------------------------------------------------------
class aio_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(aio_scoreboard)

    uvm_analysis_imp_apb  #(apb_item, aio_scoreboard) apb_imp;
    uvm_analysis_imp_mem  #(mem_item, aio_scoreboard) mem_imp;
    uvm_analysis_imp_nand #(nand_txn, aio_scoreboard) nand_imp;
    uvm_analysis_port     #(aio_op_result)            result_ap;

    aio_env_cfg cfg;

    // ---------------- 레지스터 미러 ----------------
    logic [1:0]  m_op;
    logic [23:0] m_row;
    logic [31:0] m_host;
    logic [15:0] m_words;
    logic [31:0] m_timeout;
    bit          m_irq_en;

    // ---------------- sticky status 예측 (busy 가 아닐 때만 유효) ----------------
    bit m_done, m_error, m_uncorr;
    int m_corr_cnt, m_uncorr_cnt, m_err_code;

    // ---------------- 진행 중인 동작 ----------------
    bit          busy;
    int          a_op, a_row, a_words;
    logic [31:0] a_host;
    bit          a_bad_len, a_wp, a_fail_armed, a_stuck, a_watchdog;
    logic [7:0]  raw_before [$];

    mem_item mem_q  [$];
    nand_txn nand_q [$];
    bit      first_nand_seen;       // 전원 인가 후 PHY 의 FFh 를 봤다
    bit      expect_abort_txn;      // watchdog 뒤 PHY 의 정리(FFh)가 곧 올 것이다

    // ---------------- 통계 ----------------
    int n_ops, n_checks, n_words_read, n_words_prog;
    int n_by_op [4];
    int n_by_err [5];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_imp   = new("apb_imp", this);
        mem_imp   = new("mem_imp", this);
        nand_imp  = new("nand_imp", this);
        result_ap = new("result_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aio_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "aio_env_cfg not found")
        do_reset();
    endfunction

    // 비교 하나. 틀리면 UVM_ERROR, 맞으면 세기만 한다.
    function void chk(string what, logic [31:0] actual, logic [31:0] expected);
        string msg;
        n_checks++;
        if (actual !== expected) begin
            msg = $sformatf("%s : actual=%08x expected=%08x (op=%0d row=%0d words=%0d)",
                            what, actual, expected, a_op, a_row, a_words);
            `uvm_error("SB", msg)
        end
    endfunction

    function void do_reset();
        m_op = 0; m_row = 0; m_host = 0; m_words = 16; m_timeout = 1024; m_irq_en = 0;
        m_done = 0; m_error = 0; m_uncorr = 0;
        m_corr_cnt = 0; m_uncorr_cnt = 0; m_err_code = 0;
        busy = 0;
        mem_q.delete();
        nand_q.delete();
        first_nand_seen  = 0;
        expect_abort_txn = 0;
    endfunction

    function void clear_sticky();
        m_done = 0; m_error = 0; m_uncorr = 0;
        m_corr_cnt = 0; m_uncorr_cnt = 0; m_err_code = 0;
    endfunction

    // =========================================================================
    // APB
    // =========================================================================
    function void write_apb(apb_item it);
        bit addr_ok;

        if (it.is_reset) begin
            do_reset();
            return;
        end

        addr_ok = (it.addr inside {REG_CONTROL, REG_STATUS, REG_NAND_ROW, REG_HOST_ADDR,
                                   REG_PAGE_WORDS, REG_TIMEOUT, REG_CORR_COUNT,
                                   REG_UNCORR_COUNT, REG_ERROR_CODE, REG_IRQ_ENABLE, REG_ID});
        chk("PSLVERR", it.slverr, !addr_ok);

        // irq 핀 : 쉬는 동안에는 "켜져 있고, 끝났거나 에러" 와 정확히 같아야 한다.
        // (동작 중에는 ECC 에러가 DONE 보다 먼저 irq 를 올릴 수 있어서 보지 않는다)
        if (!busy) chk("irq pin", it.irq, m_irq_en && (m_done || m_error));

        if (!addr_ok) begin
            if (!it.write) chk("read of undefined address", it.data, 32'h0);
            return;
        end

        if (it.write) apb_wr(it);
        else          apb_rd(it);
    endfunction

    function void apb_wr(apb_item it);
        case (it.addr)
            REG_CONTROL: begin
                m_op = it.data[2:1];
                if (it.data[8]) begin
                    if (busy) `uvm_error("SB", "CLEAR_STATUS written while busy : result is not predictable")
                    clear_sticky();
                end
                if (it.data[0]) begin
                    if (busy) `uvm_info("SB", "START while busy : the DUT must ignore it", UVM_MEDIUM)
                    else      start_op();
                end
            end
            REG_NAND_ROW:   m_row     = it.data[23:0];
            REG_HOST_ADDR:  m_host    = it.data;
            REG_PAGE_WORDS: m_words   = it.data[15:0];
            REG_TIMEOUT:    m_timeout = it.data;
            REG_IRQ_ENABLE: m_irq_en  = it.data[0];
            default: ;      // RO 레지스터에 쓰기 : 아무 일도 없어야 한다
        endcase
    endfunction

    function void apb_rd(apb_item it);
        case (it.addr)
            REG_CONTROL:    chk("CONTROL", it.data, {29'h0, m_op, 1'b0});
            REG_NAND_ROW:   chk("NAND_ROW", it.data, {8'h0, m_row});
            REG_HOST_ADDR:  chk("HOST_ADDR", it.data, m_host);
            REG_PAGE_WORDS: chk("PAGE_WORDS", it.data, {16'h0, m_words});
            REG_TIMEOUT:    chk("TIMEOUT", it.data, m_timeout);
            REG_IRQ_ENABLE: chk("IRQ_ENABLE", it.data, {31'h0, m_irq_en});
            REG_ID:         chk("ID", it.data, ID_VALUE);
            REG_STATUS: begin
                if (busy) begin
                    if (it.data[1]) finish_op(it);      // DONE 이 처음 보였다
                end else begin
                    chk("STATUS (idle)", it.data,
                        {27'h0, m_uncorr, m_error, m_irq_en && (m_done || m_error), m_done, 1'b0});
                end
            end
            REG_CORR_COUNT:   if (!busy) chk("CORR_COUNT", it.data, m_corr_cnt);
            REG_UNCORR_COUNT: if (!busy) chk("UNCORR_COUNT", it.data, m_uncorr_cnt);
            REG_ERROR_CODE:   if (!busy) chk("ERROR_CODE", it.data, m_err_code);
            default: ;
        endcase
    endfunction

    // =========================================================================
    // START : 이 순간의 상황을 찍어 둔다
    // =========================================================================
    function void start_op();
        int n;

        clear_sticky();
        a_op    = m_op;
        a_row   = m_row;
        a_host  = m_host;
        a_words = m_words;

        a_bad_len  = (m_words == 0) || (m_words > cfg.max_words);
        a_wp       = cfg.bd_vif.write_protect;
        a_stuck    = cfg.bd_vif.stuck_busy();
        a_watchdog = cfg.expect_watchdog;
        cfg.expect_watchdog = 0;

        case (a_op)
            OP_PROGRAM: a_fail_armed = cfg.bd_vif.fail_prog_armed();
            OP_ERASE:   a_fail_armed = cfg.bd_vif.fail_erase_armed();
            default:    a_fail_armed = 0;
        endcase

        // NAND 셀의 지금 내용. READ 라면 DUT 가 읽게 될 바로 그 값이다.
        raw_before.delete();
        if (!a_bad_len) begin
            n = (a_op == OP_ERASE) ? BYTES_PER_WORD * cfg.max_words * cfg.pages_per_block
                                   : BYTES_PER_WORD * a_words;
            for (int i = 0; i < n; i++) raw_before.push_back(flash_byte(i));
        end

        mem_q.delete();
        busy = 1;
    endfunction

    // ERASE 는 블록 전체를 본다 : i 를 (페이지, 바이트) 로 풀어 읽는다
    function logic [7:0] flash_byte(int i);
        int per_page, blk_row0;
        if (a_op == OP_ERASE) begin
            per_page = BYTES_PER_WORD * cfg.max_words;
            blk_row0 = (a_row / cfg.pages_per_block) * cfg.pages_per_block;
            return cfg.bd_vif.peek(blk_row0 + i / per_page, i % per_page);
        end
        return cfg.bd_vif.peek(a_row, i);
    endfunction

    // =========================================================================
    // DONE : 예측을 만들고 전부 비교한다
    // =========================================================================
    function void finish_op(apb_item it);
        aio_op_result res;
        int           exp_code;
        bit           flash_changes;
        logic [7:0]   image [$];        // PROGRAM 이 NAND 로 보냈어야 하는 바이트
        logic [31:0]  exp_rd [$];       // READ 가 host memory 에 썼어야 하는 워드
        int           st, bp;
        logic [31:0]  d, fx;
        logic [7:0]   exp_cmds [$];
        bit           nand_ok;          // NAND 가 끝까지 정상 응답했다 (status 까지 읽었다)

        res = aio_op_result::type_id::create("res");
        res.op = a_op; res.row = a_row; res.words = a_words;
        res.wp = a_wp; res.bp_level = cfg.bp_level;

        m_corr_cnt = 0; m_uncorr_cnt = 0;
        flash_changes = 0;
        nand_ok = !a_stuck;

        // ---------------- 1. 결과 코드 예측 ----------------
        if (a_bad_len)          exp_code = ERR_BAD_LENGTH;
        else if (a_watchdog)    exp_code = ERR_TIMEOUT;
        else if (a_stuck)       exp_code = ERR_NAND_FAIL;       // PHY 가 R/B# 를 기다리다 포기
        else begin
            case (a_op)
                OP_PROGRAM, OP_ERASE: begin
                    if (a_wp || a_fail_armed) exp_code = ERR_NAND_FAIL;
                    else begin
                        exp_code      = ERR_NONE;
                        flash_changes = 1;
                    end
                end
                OP_READ: begin
                    for (int i = 0; i < a_words; i++) begin
                        d = {raw_before[5*i+3], raw_before[5*i+2], raw_before[5*i+1], raw_before[5*i]};
                        aio_ref_model::decode(d, raw_before[5*i+4][6:0] ^ ECC_ERASED_MASK, st, fx, bp);
                        exp_rd.push_back(fx);
                        res.ecc_status.push_back(st);
                        res.ecc_bitpos.push_back(bp);
                        if ((st == ECC_DATA_FIXED) || (st == ECC_PARITY_FIXED)) m_corr_cnt++;
                        if (st == ECC_UNCORR) m_uncorr_cnt++;
                    end
                    exp_code = (m_uncorr_cnt != 0) ? ERR_ECC : ERR_NONE;
                end
                default: exp_code = ERR_NONE;                   // RESET
            endcase
        end

        m_err_code = exp_code;
        m_done     = 1;
        m_error    = (exp_code != ERR_NONE);
        m_uncorr   = (m_uncorr_cnt != 0);
        busy       = 0;

        // ---------------- 2. STATUS ----------------
        chk("STATUS at DONE", it.data[4:1],
            {m_uncorr, m_error, m_irq_en && (m_done || m_error), m_done});

        // ---------------- 3. DMA ----------------
        if (a_bad_len) begin
            chk("DMA transfers on bad length", mem_q.size(), 0);
        end else if (a_watchdog) begin
            // 어디까지 갔는지는 클럭 수에 달렸다. "READ 는 host memory 를 건드리지 않았다" 만 본다.
            if (a_op == OP_READ) chk("DMA writes after aborted READ", mem_q.size(), 0);
        end else begin
            case (a_op)
                OP_PROGRAM: begin
                    chk("DMA read count", mem_q.size(), a_words);
                    foreach (mem_q[i]) begin
                        chk("DMA direction (PROGRAM reads)", mem_q[i].write, 0);
                        chk("DMA read address", mem_q[i].addr, a_host + 4*i);
                        d = mem_q[i].data;
                        image.push_back(d[7:0]);
                        image.push_back(d[15:8]);
                        image.push_back(d[23:16]);
                        image.push_back(d[31:24]);
                        image.push_back(aio_ref_model::ecc_byte(d));
                    end
                    n_words_prog += a_words;
                end
                OP_READ: begin
                    if (nand_ok) begin
                        chk("DMA write count", mem_q.size(), a_words);
                        foreach (mem_q[i]) begin
                            chk("DMA direction (READ writes)", mem_q[i].write, 1);
                            chk("DMA write address", mem_q[i].addr, a_host + 4*i);
                            if (i < exp_rd.size()) chk("DMA write data (after ECC)", mem_q[i].data, exp_rd[i]);
                        end
                        n_words_read += a_words;
                    end else chk("DMA writes after failed READ", mem_q.size(), 0);
                end
                default: chk("DMA transfers on ERASE/RESET", mem_q.size(), 0);
            endcase
        end

        // ---------------- 4. NAND 핀 ----------------
        if (a_bad_len) begin
            chk("NAND transactions on bad length", nand_q.size(), 0);
        end else if (a_watchdog) begin
            expect_abort_txn = 1;           // PHY 가 조금 뒤에 FFh 로 정리한다
            nand_q.delete();
        end else begin
            case (a_op)
                OP_PROGRAM: begin exp_cmds.push_back(8'h80); exp_cmds.push_back(8'h10); end
                OP_READ:    begin exp_cmds.push_back(8'h00); exp_cmds.push_back(8'h30); end
                OP_ERASE:   begin exp_cmds.push_back(8'h60); exp_cmds.push_back(8'hd0); end
                default:    exp_cmds.push_back(8'hff);
            endcase
            if (nand_ok && ((a_op == OP_PROGRAM) || (a_op == OP_ERASE))) exp_cmds.push_back(8'h70);
            check_nand(exp_cmds, image, nand_ok);
        end

        // ---------------- 5. NAND 셀 ----------------
        if (!a_bad_len) check_flash(flash_changes, image);

        // ---------------- 6. 커버리지로 ----------------
        res.err_code = exp_code;
        res.corr     = m_corr_cnt;
        res.uncorr   = m_uncorr_cnt;
        n_ops++;
        n_by_op[a_op]++;
        n_by_err[exp_code]++;
        result_ap.write(res);
    endfunction

    function void check_nand(logic [7:0] exp_cmds [$], logic [7:0] image [$], bit nand_ok);
        nand_txn     t;
        logic [7:0]  exp_addr [$];
        string       s;

        chk("NAND transactions for one operation", nand_q.size(), 1);
        if (nand_q.size() == 0) return;
        t = nand_q.pop_front();
        nand_q.delete();

        chk("NAND command count", t.cmds.size(), exp_cmds.size());
        foreach (exp_cmds[i])
            if (i < t.cmds.size()) chk("NAND command byte", t.cmds[i], exp_cmds[i]);

        // 주소 : READ/PROGRAM 은 column 2 (항상 0) + row 3, ERASE 는 row 3, RESET 은 없음
        if ((a_op == OP_PROGRAM) || (a_op == OP_READ)) begin
            exp_addr.push_back(8'h00);
            exp_addr.push_back(8'h00);
        end
        if (a_op != OP_RESET) begin
            exp_addr.push_back(a_row[7:0]);
            exp_addr.push_back(a_row[15:8]);
            exp_addr.push_back(a_row[23:16]);
        end
        chk("NAND address cycle count", t.addrs.size(), exp_addr.size());
        foreach (exp_addr[i])
            if (i < t.addrs.size()) chk("NAND address byte", t.addrs[i], exp_addr[i]);

        case (a_op)
            OP_PROGRAM: begin
                chk("NAND data-in byte count", t.wdata.size(), image.size());
                foreach (image[i])
                    if (i < t.wdata.size()) chk("NAND data-in byte", t.wdata[i], image[i]);
                chk("NAND status read count", t.rdata.size(), nand_ok ? 1 : 0);
            end
            OP_READ: begin
                chk("NAND data-in on READ", t.wdata.size(), 0);
                chk("NAND data-out byte count", t.rdata.size(), nand_ok ? raw_before.size() : 0);
                if (nand_ok)
                    foreach (raw_before[i])
                        if (i < t.rdata.size()) chk("NAND data-out byte", t.rdata[i], raw_before[i]);
            end
            OP_ERASE: begin
                chk("NAND data-in on ERASE", t.wdata.size(), 0);
                chk("NAND status read count", t.rdata.size(), nand_ok ? 1 : 0);
            end
            default: begin
                chk("NAND data on RESET", t.wdata.size() + t.rdata.size(), 0);
            end
        endcase
    endfunction

    function void check_flash(bit changes, logic [7:0] image [$]);
        logic [7:0] exp;
        foreach (raw_before[i]) begin
            exp = raw_before[i];
            if (changes) begin
                if (a_op == OP_ERASE)          exp = 8'hff;
                else if (a_op == OP_PROGRAM)   exp = raw_before[i] & image[i];     // 1 -> 0 만 된다
            end
            chk("flash cell content", flash_byte(i), exp);
        end
    endfunction

    // =========================================================================
    // DMA / NAND 모니터에서 오는 것
    // =========================================================================
    function void write_mem(mem_item it);
        if (busy) mem_q.push_back(it);
        else `uvm_error("SB", "DMA transfer while the controller is idle")
    endfunction

    function void write_nand(nand_txn t);
        string s;
        s = t.convert2string();
        `uvm_info("SB", s, UVM_HIGH)

        // 리셋 뒤 첫 트랜잭션은 PHY 가 스스로 보내는 FFh 여야 한다.
        // (리셋으로 끊긴 반쪽짜리가 먼저 올 수 있어서, FFh 하나짜리가 올 때까지는 버린다)
        if (!first_nand_seen) begin
            if ((t.cmds.size() == 1) && (t.cmds[0] == 8'hff) && (t.addrs.size() == 0)) begin
                first_nand_seen = 1;
                n_checks++;
            end
            return;
        end

        if (expect_abort_txn) begin
            chk("PHY cleanup after watchdog ends with FFh", t.cmds[t.cmds.size()-1], 8'hff);
            expect_abort_txn = 0;
            return;
        end

        nand_q.push_back(t);
    endfunction

    // =========================================================================
    // 끝
    // =========================================================================
    function void check_phase(uvm_phase phase);
        string msg;
        if (busy)                 `uvm_error("SB", "test ended while an operation was still running")
        if (nand_q.size() != 0)   `uvm_error("SB", "NAND transaction left over that no operation accounts for")
        if (expect_abort_txn)     `uvm_error("SB", "PHY never cleaned up after the watchdog abort")
        if (!first_nand_seen)     `uvm_error("SB", "PHY never sent the power-on FFh")
        if (n_ops == 0)           `uvm_error("SB", "no operation was checked")
        if (cfg.bd_vif.viol_cnt() != 0) begin
            msg = $sformatf("NAND model reported %0d timing/protocol violations", cfg.bd_vif.viol_cnt());
            `uvm_error("SB", msg)
        end
    endfunction

    function void report_phase(uvm_phase phase);
        string msg;
        msg = $sformatf("ops=%0d (program=%0d read=%0d erase=%0d reset=%0d)  words: programmed=%0d read=%0d  checks=%0d",
                        n_ops, n_by_op[0], n_by_op[1], n_by_op[2], n_by_op[3],
                        n_words_prog, n_words_read, n_checks);
        `uvm_info("SB", msg, UVM_NONE)
        msg = $sformatf("results: ok=%0d bad_len=%0d nand_fail=%0d timeout=%0d ecc=%0d",
                        n_by_err[0], n_by_err[1], n_by_err[2], n_by_err[3], n_by_err[4]);
        `uvm_info("SB", msg, UVM_NONE)
    endfunction
endclass
