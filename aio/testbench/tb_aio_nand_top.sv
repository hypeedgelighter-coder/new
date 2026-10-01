`timescale 1ns/1ps

// =============================================================================
// tb_aio_nand_top : 코어 + ONFI PHY 를 "핀 레벨 NAND 모델" 에 붙여 돌리는 자기 검증 TB
//
//   tb_aio_nand_dma_ctrl 은 NAND 를 valid/ready 트랜잭션으로 흉내 냈다.
//   여기서는 CLE / ALE / WE# / RE# / R/B# / DQ 가 실제로 움직이고,
//   model/nand_model.sv 가 AC 타이밍까지 검사한다.
//
//   핀 레벨로 내려와야만 보이는 것들을 따로 시험한다.
//     - 지운 페이지(0xFF)가 ECC 에러 없이 읽히는가       (ECC 마스크)
//     - 지우지 않고 덮어쓰면 AND 가 되는가               (NAND 물리 규칙)
//     - WP# 가 걸리면 PROGRAM / ERASE 가 실패로 보고되는가
//     - R/B# 가 안 돌아오면 어떻게 끝나는가              (watchdog, PHY timeout)
//     - 코어가 중간에 떠나면 PHY 가 스스로 정리하는가    (stall -> FFh)
//
//   페이지 배치 : word i = flash byte [5i .. 5i+3] (little endian), ECC = byte [5i+4]
// =============================================================================
module tb_aio_nand_top;
    localparam int MAX_WORDS    = 16;
    localparam int MEM_WORDS    = 1024;
    localparam int PPB          = 64;       // pages per block
    localparam int RB_TIMEOUT_W = 13;       // 8192 cycle. 모델의 tBERS(1200 cycle) 보다 길다
    localparam int STALL_W      = 8;

    localparam logic [1:0] OP_PROGRAM = 2'd0, OP_READ = 2'd1, OP_ERASE = 2'd2, OP_RESET = 2'd3;

    logic clk = 1'b0;
    logic resetn = 1'b0;
    always #5 clk = ~clk;

    // ---------------- APB ----------------
    logic        psel, penable, pwrite;
    logic [11:0] paddr;
    logic [31:0] pwdata, prdata;
    logic        pready, pslverr, irq;

    // ---------------- DMA ----------------
    logic        mem_req_valid, mem_req_ready, mem_req_write;
    logic [31:0] mem_req_addr, mem_req_wdata;
    logic [3:0]  mem_req_wstrb;
    logic        mem_rsp_valid, mem_rsp_ready;
    logic [31:0] mem_rsp_rdata;

    // ---------------- NAND 핀 ----------------
    logic       write_protect;
    logic       phy_init_done;
    logic [7:0] nand_status;
    logic       nand_ce_n, nand_cle, nand_ale, nand_we_n, nand_re_n, nand_wp_n;
    logic [7:0] nand_dq_o;
    logic       nand_dq_oe;
    wire  [7:0] nand_dq;
    wire        nand_rb_n;

    assign nand_dq = nand_dq_oe ? nand_dq_o : 8'hzz;    // 패드의 3-state 버퍼
    pullup (nand_rb_n);                                 // R/B# 는 open-drain

    aio_nand_top #(
        .MAX_PAGE_WORDS(MAX_WORDS),
        .RB_TIMEOUT_W  (RB_TIMEOUT_W),
        .STALL_W       (STALL_W)
    ) dut (
        .pclk(clk), .presetn(resetn),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata),
        .pready(pready), .pslverr(pslverr), .irq(irq),
        .mem_req_valid(mem_req_valid), .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write), .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata), .mem_req_wstrb(mem_req_wstrb),
        .mem_rsp_valid(mem_rsp_valid), .mem_rsp_rdata(mem_rsp_rdata),
        .mem_rsp_ready(mem_rsp_ready),
        .write_protect(write_protect), .phy_init_done(phy_init_done),
        .nand_status(nand_status),
        .nand_ce_n(nand_ce_n), .nand_cle(nand_cle), .nand_ale(nand_ale),
        .nand_we_n(nand_we_n), .nand_re_n(nand_re_n), .nand_wp_n(nand_wp_n),
        .nand_dq_o(nand_dq_o), .nand_dq_oe(nand_dq_oe), .nand_dq_i(nand_dq),
        .nand_rb_n(nand_rb_n)
    );

    nand_model #(
        .PAGES_PER_BLOCK(PPB),
        .BLOCKS         (4)
    ) u_nand (
        .ce_n(nand_ce_n), .cle(nand_cle), .ale(nand_ale),
        .we_n(nand_we_n), .re_n(nand_re_n), .wp_n(nand_wp_n),
        .dq(nand_dq), .rb_n(nand_rb_n)
    );

    // ---------------- host memory (DMA 상대) ----------------
    logic [31:0] host_mem [0:MEM_WORDS-1];
    logic        read_pending;
    logic [31:0] read_pending_data;

    always @(posedge clk) begin
        if (!resetn) begin
            mem_req_ready     <= 1'b0;
            mem_rsp_valid     <= 1'b0;
            mem_rsp_rdata     <= '0;
            read_pending      <= 1'b0;
            read_pending_data <= '0;
        end else begin
            mem_req_ready <= ($urandom_range(0, 3) != 0);       // 무작위 backpressure

            if (mem_rsp_valid && mem_rsp_ready) mem_rsp_valid <= 1'b0;

            if (read_pending && !mem_rsp_valid && ($urandom_range(0, 2) != 0)) begin
                mem_rsp_valid <= 1'b1;
                mem_rsp_rdata <= read_pending_data;
                read_pending  <= 1'b0;
            end

            if (mem_req_valid && mem_req_ready) begin
                if (mem_req_write) begin
                    for (int b = 0; b < 4; b++)
                        if (mem_req_wstrb[b])
                            host_mem[mem_req_addr[11:2]][8*b +: 8] <= mem_req_wdata[8*b +: 8];
                end else begin
                    assert (!read_pending)
                        else $fatal(1, "DMA issued more than one outstanding read");
                    read_pending      <= 1'b1;
                    read_pending_data <= host_mem[mem_req_addr[11:2]];
                end
            end
        end
    end

    // ---------------- 기준 ECC (RTL 과 따로 짠 것) ----------------
    function automatic [6:0] ecc32(input logic [31:0] value);
        logic [37:0] code;
        int d;
        begin
            code = '0;
            d = 0;
            for (int p = 1; p <= 38; p++) begin
                if ((p != 1) && (p != 2) && (p != 4) && (p != 8) && (p != 16) && (p != 32)) begin
                    code[p-1] = value[d];
                    d = d + 1;
                end
            end
            for (int k = 0; k < 6; k++) begin
                code[(1 << k)-1] = 1'b0;
                for (int p = 1; p <= 38; p++)
                    if ((p & (1 << k)) != 0)
                        code[(1 << k)-1] = code[(1 << k)-1] ^ code[p-1];
                ecc32[k] = code[(1 << k)-1];
            end
            ecc32[6] = ^code;
        end
    endfunction

    // flash 에 저장되는 ECC byte : bit7 = 1, 나머지는 0x67 로 XOR (지운 페이지 대책)
    function automatic [7:0] ecc_byte(input logic [31:0] value);
        return {1'b1, ecc32(value) ^ 7'h67};
    endfunction

    function automatic [31:0] flash_word(input int row, input int i);
        return {u_nand.peek(row, 5*i+3), u_nand.peek(row, 5*i+2),
                u_nand.peek(row, 5*i+1), u_nand.peek(row, 5*i+0)};
    endfunction

    function automatic [7:0] flash_ecc(input int row, input int i);
        return u_nand.peek(row, 5*i+4);
    endfunction

    // ---------------- APB BFM ----------------
    task automatic apb_write(input logic [11:0] addr, input logic [31:0] data);
        begin
            @(posedge clk);
            psel <= 1'b1; penable <= 1'b0; pwrite <= 1'b1; paddr <= addr; pwdata <= data;
            @(posedge clk);
            penable <= 1'b1;
            @(posedge clk);
            assert (pready && !pslverr) else $fatal(1, "APB write failed @%03x", addr);
            psel <= 1'b0; penable <= 1'b0; pwrite <= 1'b0;
        end
    endtask

    task automatic apb_read(input logic [11:0] addr, output logic [31:0] data);
        begin
            @(posedge clk);
            psel <= 1'b1; penable <= 1'b0; pwrite <= 1'b0; paddr <= addr;
            @(posedge clk);
            penable <= 1'b1;
            #1 data = prdata;
            @(posedge clk);
            assert (pready && !pslverr) else $fatal(1, "APB read failed @%03x", addr);
            psel <= 1'b0; penable <= 1'b0;
        end
    endtask

    task automatic launch(input logic [1:0] op, input int row, input int byte_addr,
                          input int words, input int timeout_cycles);
        begin
            apb_write(12'h008, row);
            apb_write(12'h00c, byte_addr);
            apb_write(12'h010, words);
            apb_write(12'h014, timeout_cycles);
            apb_write(12'h000, {23'h0, 1'b1, 5'h0, op, 1'b1});     // CLEAR_STATUS + OP + START
        end
    endtask

    int tests_run;

    task automatic wait_done(output logic [31:0] status);
        int polls;
        begin
            status = 0;
            polls  = 0;
            while (!status[1] && (polls < 20000)) begin
                apb_read(12'h004, status);
                polls = polls + 1;
            end
            assert (status[1]) else $fatal(1, "controller completion timeout");
        end
    endtask

    task automatic expect_eq(input logic [31:0] actual, input logic [31:0] expected,
                             input string what);
        begin
            assert (actual === expected)
                else $fatal(1, "%s : actual=%08x expected=%08x", what, actual, expected);
        end
    endtask

    task automatic title(input string what);
        begin
            tests_run = tests_run + 1;
            $display("[TEST %0d] %s", tests_run, what);
        end
    endtask

    // 읽기 한 번 + 결과 레지스터 수집
    task automatic read_page(input int row, input int dst_word,
                             output logic [31:0] status, output logic [31:0] corr,
                             output logic [31:0] uncorr, output logic [31:0] code);
        begin
            launch(OP_READ, row, dst_word*4, MAX_WORDS, 100000);
            wait_done(status);
            apb_read(12'h018, corr);
            apb_read(12'h01c, uncorr);
            apb_read(12'h020, code);
        end
    endtask

    // =========================================================================
    // 시나리오
    // =========================================================================
    localparam int ROW_A = 1*PPB + 3;       // block 1, page 3
    localparam int ROW_B = 2*PPB + 0;       // block 2, page 0
    localparam int SRC   = 'h010;           // host memory word index
    localparam int SRC2  = 'h040;
    localparam int DST   = 'h100;

    logic [31:0] rd, status, corr, uncorr, code;
    logic [31:0] snap [0:MAX_WORDS-1];
    int          n_reset_before;

    initial begin
        psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
        write_protect = 0;
        tests_run = 0;
        for (int i = 0; i < MEM_WORDS; i++) host_mem[i] = 32'h0;

        repeat (5) @(posedge clk);
        resetn = 1'b1;

        // ---------------------------------------------------------------------
        title("power-on : PHY sends FFh by itself and waits for R/B#");
        wait (phy_init_done);
        expect_eq(u_nand.n_reset, 1, "NAND reset count after power-on");
        apb_read(12'h0fc, rd);
        expect_eq(rd, 32'h4149_4f31, "ID register");
        apb_write(12'h024, 1);

        // ---------------------------------------------------------------------
        title("erased page reads back as 0xFFFFFFFF with no ECC error");
        read_page(ROW_A, DST, status, corr, uncorr, code);
        assert (!status[3] && !status[4]) else $fatal(1, "erased page status: %08x", status);
        expect_eq(corr, 0, "erased page corrected count");
        expect_eq(uncorr, 0, "erased page uncorrectable count");
        for (int i = 0; i < MAX_WORDS; i++)
            expect_eq(host_mem[DST+i], 32'hffff_ffff, "erased page data");

        // ---------------------------------------------------------------------
        title("PROGRAM : 80h - addr - data - 10h - status, flash holds data + ECC");
        for (int i = 0; i < MAX_WORDS; i++)
            host_mem[SRC+i] = 32'hcafe_0000 ^ (i * 32'h0101_1021);
        launch(OP_PROGRAM, ROW_A, SRC*4, MAX_WORDS, 100000);
        wait_done(status);
        assert (!status[3] && irq) else $fatal(1, "program status/IRQ: %08x", status);
        for (int i = 0; i < MAX_WORDS; i++) begin
            expect_eq(flash_word(ROW_A, i), host_mem[SRC+i], "programmed flash data");
            expect_eq(flash_ecc(ROW_A, i), ecc_byte(host_mem[SRC+i]), "programmed flash ECC byte");
        end
        expect_eq(u_nand.peek(ROW_A, 5*MAX_WORDS), 8'hff, "byte after the last word is untouched");
        expect_eq(nand_status, 8'he0, "NAND status after PROGRAM");

        // ---------------------------------------------------------------------
        title("READ : 00h - addr - 30h - R/B# - data, clean page");
        read_page(ROW_A, DST, status, corr, uncorr, code);
        assert (!status[3] && !status[4]) else $fatal(1, "clean read status: %08x", status);
        expect_eq(corr, 0, "clean read corrected count");
        for (int i = 0; i < MAX_WORDS; i++)
            expect_eq(host_mem[DST+i], host_mem[SRC+i], "clean readback");

        // ---------------------------------------------------------------------
        title("1-bit cell error in data is corrected");
        u_nand.flip_bit(ROW_A, 5*5 + 0, 7);             // word 5, data bit 7
        read_page(ROW_A, DST, status, corr, uncorr, code);
        assert (!status[3]) else $fatal(1, "1-bit read must not be an error: %08x", status);
        expect_eq(corr, 1, "corrected count");
        for (int i = 0; i < MAX_WORDS; i++)
            expect_eq(host_mem[DST+i], host_mem[SRC+i], "corrected readback");
        u_nand.flip_bit(ROW_A, 5*5 + 0, 7);             // 되돌린다

        // ---------------------------------------------------------------------
        title("1-bit cell error in the ECC byte leaves data intact");
        u_nand.flip_bit(ROW_A, 5*9 + 4, 2);             // word 9 의 ECC byte
        read_page(ROW_A, DST, status, corr, uncorr, code);
        assert (!status[3]) else $fatal(1, "ECC-byte fault must not be an error: %08x", status);
        expect_eq(corr, 1, "corrected count (ECC byte fault)");
        for (int i = 0; i < MAX_WORDS; i++)
            expect_eq(host_mem[DST+i], host_mem[SRC+i], "readback with ECC byte fault");
        u_nand.flip_bit(ROW_A, 5*9 + 4, 2);

        // ---------------------------------------------------------------------
        title("2-bit cell error in one word is reported, not mis-corrected");
        u_nand.flip_bit(ROW_A, 5*3 + 0, 0);
        u_nand.flip_bit(ROW_A, 5*3 + 2, 5);
        read_page(ROW_A, DST, status, corr, uncorr, code);
        assert (status[4] && status[3]) else $fatal(1, "uncorrectable flag missing: %08x", status);
        expect_eq(uncorr, 1, "uncorrectable count");
        expect_eq(code, 4, "ECC error code");
        u_nand.flip_bit(ROW_A, 5*3 + 0, 0);
        u_nand.flip_bit(ROW_A, 5*3 + 2, 5);

        // ---------------------------------------------------------------------
        title("two 1-bit errors in different words are both corrected");
        u_nand.flip_bit(ROW_A, 5*0 + 3, 7);             // word 0 의 최상위 비트
        u_nand.flip_bit(ROW_A, 5*15 + 1, 4);            // 마지막 word
        read_page(ROW_A, DST, status, corr, uncorr, code);
        assert (!status[3]) else $fatal(1, "status: %08x", status);
        expect_eq(corr, 2, "corrected count (two words)");
        for (int i = 0; i < MAX_WORDS; i++)
            expect_eq(host_mem[DST+i], host_mem[SRC+i], "corrected readback (two words)");
        u_nand.flip_bit(ROW_A, 5*0 + 3, 7);
        u_nand.flip_bit(ROW_A, 5*15 + 1, 4);

        // ---------------------------------------------------------------------
        title("programming over a used page only clears bits (AND), it cannot set them");
        for (int i = 0; i < MAX_WORDS; i++) begin
            snap[i]          = flash_word(ROW_A, i);
            host_mem[SRC2+i] = 32'h0f0f_5a5a ^ (i * 32'h1000_0301);
        end
        launch(OP_PROGRAM, ROW_A, SRC2*4, MAX_WORDS, 100000);
        wait_done(status);
        for (int i = 0; i < MAX_WORDS; i++)
            expect_eq(flash_word(ROW_A, i), snap[i] & host_mem[SRC2+i], "overwrite is bitwise AND");

        // ---------------------------------------------------------------------
        title("ERASE : 60h - addr - D0h, the whole block returns to 0xFF");
        launch(OP_PROGRAM, 1*PPB + 40, SRC*4, MAX_WORDS, 100000);  // 같은 블록의 다른 페이지
        wait_done(status);
        launch(OP_ERASE, ROW_A, 0, MAX_WORDS, 100000);
        wait_done(status);
        assert (!status[3]) else $fatal(1, "erase status: %08x", status);
        for (int i = 0; i < 5*MAX_WORDS; i++) begin
            expect_eq(u_nand.peek(ROW_A, i), 8'hff, "erased page byte");
            expect_eq(u_nand.peek(1*PPB + 40, i), 8'hff, "erased neighbour page byte");
        end
        expect_eq(u_nand.n_erase, 1, "NAND erase count");

        // ---------------------------------------------------------------------
        title("NAND reports FAIL in its status byte");
        u_nand.fail_next_prog = 1'b1;
        launch(OP_PROGRAM, ROW_B, SRC*4, MAX_WORDS, 100000);
        wait_done(status);
        assert (status[3]) else $fatal(1, "NAND failure status missing");
        apb_read(12'h020, rd);
        expect_eq(rd, 2, "NAND failure error code");
        expect_eq(nand_status[0], 1, "NAND status FAIL bit");

        // ---------------------------------------------------------------------
        title("WP# asserted : PROGRAM and ERASE are refused and reported");
        launch(OP_PROGRAM, ROW_B, SRC*4, MAX_WORDS, 100000);        // 먼저 정상으로 한 번 쓴다
        wait_done(status);
        assert (!status[3]) else $fatal(1, "program before WP: %08x", status);
        write_protect = 1'b1;
        launch(OP_ERASE, ROW_B, 0, MAX_WORDS, 100000);
        wait_done(status);
        assert (status[3]) else $fatal(1, "erase under WP must fail");
        apb_read(12'h020, rd);
        expect_eq(rd, 2, "WP error code");
        expect_eq(nand_status[7], 0, "NAND status WP bit");
        for (int i = 0; i < MAX_WORDS; i++)
            expect_eq(flash_word(ROW_B, i), host_mem[SRC+i], "data survives a refused erase");
        write_protect = 1'b0;

        // ---------------------------------------------------------------------
        title("core watchdog fires mid-stream : PHY notices the stall and resets the NAND");
        n_reset_before = u_nand.n_reset;
        launch(OP_READ, ROW_B, DST*4, MAX_WORDS, 400);              // 400 cycle 로는 못 끝낸다
        wait_done(status);
        assert (status[3]) else $fatal(1, "timeout status missing");
        apb_read(12'h020, rd);
        expect_eq(rd, 3, "timeout error code");
        wait (dut.u_phy.cmd_ready);                                 // PHY 가 IDLE 로 돌아올 때까지
        repeat (4) @(posedge clk);
        expect_eq(u_nand.n_reset, n_reset_before + 1, "PHY cleanup reset");
        read_page(ROW_B, DST, status, corr, uncorr, code);          // 그 뒤에 정상 동작해야 한다
        assert (!status[3]) else $fatal(1, "read after recovery: %08x", status);
        for (int i = 0; i < MAX_WORDS; i++)
            expect_eq(host_mem[DST+i], host_mem[SRC+i], "readback after recovery");

        // ---------------------------------------------------------------------
        title("R/B# never returns : PHY gives up after its own timeout");
        u_nand.stuck_busy = 1'b1;
        launch(OP_READ, ROW_B, DST*4, MAX_WORDS, 100000);
        wait_done(status);
        assert (status[3]) else $fatal(1, "stuck busy must end in error");
        apb_read(12'h020, rd);
        expect_eq(rd, 2, "stuck busy error code (PHY fail)");
        u_nand.stuck_busy = 1'b0;

        title("RESET op (FFh) brings the stuck NAND back");
        launch(OP_RESET, 0, 0, MAX_WORDS, 100000);
        wait_done(status);
        assert (!status[3]) else $fatal(1, "reset op status: %08x", status);
        read_page(ROW_B, DST, status, corr, uncorr, code);
        assert (!status[3]) else $fatal(1, "read after reset: %08x", status);
        for (int i = 0; i < MAX_WORDS; i++)
            expect_eq(host_mem[DST+i], host_mem[SRC+i], "readback after reset");

        // ---------------------------------------------------------------------
        title("invalid page length is rejected before any NAND activity");
        launch(OP_PROGRAM, 0, 0, MAX_WORDS+1, 1000);
        wait_done(status);
        assert (status[3]) else $fatal(1, "invalid-length status missing");
        apb_read(12'h020, rd);
        expect_eq(rd, 1, "bad length error code");

        // ---------------------------------------------------------------------
        expect_eq(u_nand.viol_cnt, 0, "NAND timing/protocol violations");

        $display("============================================================");
        $display("PASS: %0d pin-level scenarios completed, 0 NAND timing violations", tests_run);
        $display("      NAND ops seen by the model : reset=%0d read=%0d program=%0d erase=%0d wp_blocked=%0d",
                 u_nand.n_reset, u_nand.n_read, u_nand.n_prog, u_nand.n_erase, u_nand.n_wp_blocked);
        $display("============================================================");
        repeat (5) @(posedge clk);
        $finish;
    end

    initial begin
        #50_000_000;
        $fatal(1, "global simulation timeout");
    end
endmodule
