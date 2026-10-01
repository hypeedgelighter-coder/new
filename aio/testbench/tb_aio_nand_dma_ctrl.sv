`timescale 1ns/1ps

module tb_aio_nand_dma_ctrl;
    localparam integer MAX_WORDS = 16;
    localparam integer MEM_WORDS = 1024;
    localparam integer NAND_PAGES = 8;

    logic clk = 1'b0;
    logic resetn = 1'b0;
    always #5 clk = ~clk;

    logic psel, penable, pwrite;
    logic [11:0] paddr;
    logic [31:0] pwdata, prdata;
    logic pready, pslverr, irq;

    logic mem_req_valid, mem_req_ready, mem_req_write;
    logic [31:0] mem_req_addr, mem_req_wdata;
    logic [3:0] mem_req_wstrb;
    logic mem_rsp_valid;
    logic [31:0] mem_rsp_rdata;
    logic mem_rsp_ready;

    logic nand_cmd_valid, nand_cmd_ready;
    logic [1:0] nand_cmd;
    logic [23:0] nand_row;
    logic [15:0] nand_words;
    logic nand_w_valid, nand_w_ready, nand_w_last;
    logic [31:0] nand_w_data;
    logic [6:0] nand_w_ecc;
    logic nand_r_valid, nand_r_ready, nand_r_last;
    logic [31:0] nand_r_data;
    logic [6:0] nand_r_ecc;
    logic nand_done, nand_fail;

    logic [31:0] host_mem [0:MEM_WORDS-1];
    logic [31:0] flash_data [0:NAND_PAGES-1][0:MAX_WORDS-1];
    logic [6:0]  flash_ecc  [0:NAND_PAGES-1][0:MAX_WORDS-1];

    logic force_mem_stall;
    logic force_nand_cmd_stall;
    logic inject_nand_fail;
    logic read_pending;
    logic [31:0] read_pending_data;
    integer nand_mode;
    integer nand_page;
    integer nand_count;
    integer nand_index;
    integer tests_run;
    integer i, j;

    aio_nand_dma_ctrl #(
        .MAX_PAGE_WORDS(MAX_WORDS)
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
        .nand_cmd_valid(nand_cmd_valid), .nand_cmd_ready(nand_cmd_ready),
        .nand_cmd(nand_cmd), .nand_row(nand_row), .nand_words(nand_words),
        .nand_w_valid(nand_w_valid), .nand_w_ready(nand_w_ready),
        .nand_w_data(nand_w_data), .nand_w_ecc(nand_w_ecc),
        .nand_w_last(nand_w_last),
        .nand_r_valid(nand_r_valid), .nand_r_ready(nand_r_ready),
        .nand_r_data(nand_r_data), .nand_r_ecc(nand_r_ecc),
        .nand_r_last(nand_r_last), .nand_done(nand_done),
        .nand_fail(nand_fail)
    );

    function automatic [6:0] ecc32(input logic [31:0] value);
        logic [37:0] code;
        integer p;
        integer d;
        integer k;
        begin
            code = '0;
            d = 0;
            for (p = 1; p <= 38; p = p + 1) begin
                if ((p != 1) && (p != 2) && (p != 4) &&
                    (p != 8) && (p != 16) && (p != 32)) begin
                    code[p-1] = value[d];
                    d = d + 1;
                end
            end
            for (k = 0; k < 6; k = k + 1) begin
                code[(1 << k)-1] = 1'b0;
                for (p = 1; p <= 38; p = p + 1)
                    if ((p & (1 << k)) != 0)
                        code[(1 << k)-1] = code[(1 << k)-1] ^ code[p-1];
                ecc32[k] = code[(1 << k)-1];
            end
            ecc32[6] = ^code;
        end
    endfunction

    // Host memory model: single outstanding read and randomized backpressure.
    always @(posedge clk) begin
        if (!resetn) begin
            mem_req_ready <= 1'b0;
            mem_rsp_valid <= 1'b0;
            mem_rsp_rdata <= '0;
            read_pending <= 1'b0;
            read_pending_data <= '0;
        end else begin
            mem_req_ready <= !force_mem_stall && ($urandom_range(0, 3) != 0);

            if (mem_rsp_valid && mem_rsp_ready)
                mem_rsp_valid <= 1'b0;

            if (read_pending && !mem_rsp_valid && ($urandom_range(0, 2) != 0)) begin
                mem_rsp_valid <= 1'b1;
                mem_rsp_rdata <= read_pending_data;
                read_pending <= 1'b0;
            end

            if (mem_req_valid && mem_req_ready) begin
                if (mem_req_write) begin
                    if (mem_req_wstrb[0]) host_mem[mem_req_addr[11:2]][7:0]
                        <= mem_req_wdata[7:0];
                    if (mem_req_wstrb[1]) host_mem[mem_req_addr[11:2]][15:8]
                        <= mem_req_wdata[15:8];
                    if (mem_req_wstrb[2]) host_mem[mem_req_addr[11:2]][23:16]
                        <= mem_req_wdata[23:16];
                    if (mem_req_wstrb[3]) host_mem[mem_req_addr[11:2]][31:24]
                        <= mem_req_wdata[31:24];
                end else begin
                    assert (!read_pending)
                        else $fatal(1, "DMA issued more than one outstanding read");
                    read_pending <= 1'b1;
                    read_pending_data <= host_mem[mem_req_addr[11:2]];
                end
            end
        end
    end

    // NAND behavioral model with randomized stream backpressure.
    always @(posedge clk) begin
        if (!resetn) begin
            nand_cmd_ready <= 1'b0;
            nand_w_ready <= 1'b0;
            nand_r_valid <= 1'b0;
            nand_r_data <= '0;
            nand_r_ecc <= '0;
            nand_r_last <= 1'b0;
            nand_done <= 1'b0;
            nand_fail <= 1'b0;
            nand_mode <= 0;
            nand_page <= 0;
            nand_count <= 0;
            nand_index <= 0;
        end else begin
            nand_done <= 1'b0;
            nand_cmd_ready <= !force_nand_cmd_stall && (nand_mode == 0) &&
                              ($urandom_range(0, 3) != 0);
            nand_w_ready <= (nand_mode == 1) && ($urandom_range(0, 3) != 0);

            if (nand_cmd_valid && nand_cmd_ready) begin
                nand_page <= nand_row % NAND_PAGES;
                nand_count <= nand_words;
                nand_index <= 0;
                nand_fail <= inject_nand_fail;
                inject_nand_fail <= 1'b0;
                case (nand_cmd)
                    2'd0: nand_mode <= 1; // PROGRAM
                    2'd1: nand_mode <= 2; // READ
                    2'd2: begin           // ERASE
                        for (j = 0; j < MAX_WORDS; j = j + 1) begin
                            flash_data[nand_row % NAND_PAGES][j] <= 32'hffff_ffff;
                            flash_ecc[nand_row % NAND_PAGES][j] <= ecc32(32'hffff_ffff);
                        end
                        nand_mode <= 0;
                        nand_done <= 1'b1;
                    end
                    default: begin
                        nand_mode <= 0;
                        nand_fail <= 1'b1;
                        nand_done <= 1'b1;
                    end
                endcase
            end

            if ((nand_mode == 1) && nand_w_valid && nand_w_ready) begin
                flash_data[nand_page][nand_index] <= nand_w_data;
                flash_ecc[nand_page][nand_index] <= nand_w_ecc;
                if (nand_w_last) begin
                    nand_mode <= 0;
                    nand_done <= 1'b1;
                end else begin
                    nand_index <= nand_index + 1;
                end
            end

            if (nand_r_valid && nand_r_ready) begin
                nand_r_valid <= 1'b0;
                if (nand_r_last) begin
                    nand_mode <= 0;
                    nand_done <= 1'b1;
                end else begin
                    nand_index <= nand_index + 1;
                end
            end

            if ((nand_mode == 2) && !nand_r_valid &&
                ($urandom_range(0, 3) != 0)) begin
                nand_r_valid <= 1'b1;
                nand_r_data <= flash_data[nand_page][nand_index];
                nand_r_ecc <= flash_ecc[nand_page][nand_index];
                nand_r_last <= (nand_index == nand_count - 1);
            end
        end
    end

    task automatic apb_write(input logic [11:0] addr, input logic [31:0] data);
        begin
            @(posedge clk);
            psel <= 1'b1;
            penable <= 1'b0;
            pwrite <= 1'b1;
            paddr <= addr;
            pwdata <= data;
            @(posedge clk);
            penable <= 1'b1;
            @(posedge clk);
            assert (pready && !pslverr) else $fatal(1, "APB write failed @%03x", addr);
            psel <= 1'b0;
            penable <= 1'b0;
            pwrite <= 1'b0;
        end
    endtask

    task automatic apb_read(input logic [11:0] addr, output logic [31:0] data);
        begin
            @(posedge clk);
            psel <= 1'b1;
            penable <= 1'b0;
            pwrite <= 1'b0;
            paddr <= addr;
            @(posedge clk);
            penable <= 1'b1;
            #1 data = prdata;
            @(posedge clk);
            assert (pready && !pslverr) else $fatal(1, "APB read failed @%03x", addr);
            psel <= 1'b0;
            penable <= 1'b0;
        end
    endtask

    task automatic launch(input logic [1:0] op, input integer page,
                          input integer byte_addr, input integer words,
                          input integer timeout_cycles);
        begin
            apb_write(12'h008, page);
            apb_write(12'h00c, byte_addr);
            apb_write(12'h010, words);
            apb_write(12'h014, timeout_cycles);
            apb_write(12'h000, {23'h0, 1'b1, 5'h0, op, 1'b1});
        end
    endtask

    task automatic wait_done(output logic [31:0] status);
        integer polls;
        begin
            status = 0;
            polls = 0;
            while (!status[1] && (polls < 1000)) begin
                apb_read(12'h004, status);
                polls = polls + 1;
            end
            assert (status[1]) else $fatal(1, "controller completion timeout");
            tests_run = tests_run + 1;
        end
    endtask

    task automatic expect_word(input logic [31:0] actual,
                               input logic [31:0] expected,
                               input string label_text);
        begin
            assert (actual === expected)
                else $fatal(1, "%s actual=%08x expected=%08x", label_text, actual, expected);
        end
    endtask

    logic [31:0] rd;
    logic [31:0] status;
    integer src_word;
    integer dst_word;

    initial begin
        psel = 0;
        penable = 0;
        pwrite = 0;
        paddr = 0;
        pwdata = 0;
        force_mem_stall = 0;
        force_nand_cmd_stall = 0;
        inject_nand_fail = 0;
        tests_run = 0;
        src_word = 'h10;
        dst_word = 'h80;
        for (i = 0; i < MEM_WORDS; i = i + 1)
            host_mem[i] = 32'h0;
        for (i = 0; i < NAND_PAGES; i = i + 1)
            for (j = 0; j < MAX_WORDS; j = j + 1) begin
                flash_data[i][j] = 32'hffff_ffff;
                flash_ecc[i][j] = ecc32(32'hffff_ffff);
            end

        repeat (5) @(posedge clk);
        resetn = 1'b1;
        repeat (3) @(posedge clk);

        $display("[TEST] reset and register identity");
        apb_read(12'h0fc, rd);
        expect_word(rd, 32'h4149_4f31, "ID register");
        apb_write(12'h024, 1);

        for (i = 0; i < MAX_WORDS; i = i + 1)
            host_mem[src_word+i] = 32'hcafe_0000 ^ (i * 32'h0101_1021);

        $display("[TEST] program page through DMA + generated ECC");
        launch(2'd0, 1, src_word*4, MAX_WORDS, 2000);
        wait_done(status);
        assert (!status[3] && irq) else $fatal(1, "program status/IRQ failure: %08x", status);
        for (i = 0; i < MAX_WORDS; i = i + 1) begin
            expect_word(flash_data[1][i], host_mem[src_word+i], "programmed NAND data");
            assert (flash_ecc[1][i] == ecc32(host_mem[src_word+i]))
                else $fatal(1, "ECC mismatch at word %0d", i);
        end

        $display("[TEST] clean page read through NAND + DMA");
        launch(2'd1, 1, dst_word*4, MAX_WORDS, 2000);
        wait_done(status);
        assert (!status[3] && !status[4]) else $fatal(1, "clean read status: %08x", status);
        for (i = 0; i < MAX_WORDS; i = i + 1)
            expect_word(host_mem[dst_word+i], host_mem[src_word+i], "clean DMA readback");

        $display("[TEST] one-bit NAND error is corrected and counted");
        flash_data[1][5] = flash_data[1][5] ^ 32'h0000_0080;
        launch(2'd1, 1, (dst_word+MAX_WORDS)*4, MAX_WORDS, 2000);
        wait_done(status);
        apb_read(12'h018, rd);
        expect_word(rd, 1, "corrected word count");
        for (i = 0; i < MAX_WORDS; i = i + 1)
            expect_word(host_mem[dst_word+MAX_WORDS+i], host_mem[src_word+i],
                        "single-bit corrected readback");

        $display("[TEST] two-bit NAND error is reported as uncorrectable");
        flash_data[1][5] = flash_data[1][5] ^ 32'h0000_0080;
        flash_data[1][3] = flash_data[1][3] ^ 32'h0000_0003;
        launch(2'd1, 1, (dst_word+2*MAX_WORDS)*4, MAX_WORDS, 2000);
        wait_done(status);
        assert (status[4]) else $fatal(1, "uncorrectable flag missing: %08x", status);
        apb_read(12'h01c, rd);
        expect_word(rd, 1, "uncorrectable word count");
        apb_read(12'h020, rd);
        expect_word(rd, 4, "ECC error code");
        flash_data[1][3] = flash_data[1][3] ^ 32'h0000_0003;

        $display("[TEST] erase operation returns the page to all ones");
        launch(2'd2, 1, 0, MAX_WORDS, 2000);
        wait_done(status);
        for (i = 0; i < MAX_WORDS; i = i + 1)
            expect_word(flash_data[1][i], 32'hffff_ffff, "erased NAND word");

        $display("[TEST] NAND-reported failure propagates to APB status");
        inject_nand_fail = 1'b1;
        launch(2'd2, 2, 0, MAX_WORDS, 2000);
        wait_done(status);
        assert (status[3]) else $fatal(1, "NAND failure status missing");
        apb_read(12'h020, rd);
        expect_word(rd, 2, "NAND failure error code");

        $display("[TEST] stalled NAND command triggers watchdog timeout");
        force_nand_cmd_stall = 1'b1;
        launch(2'd2, 3, 0, MAX_WORDS, 12);
        wait_done(status);
        force_nand_cmd_stall = 1'b0;
        assert (status[3]) else $fatal(1, "timeout status missing");
        apb_read(12'h020, rd);
        expect_word(rd, 3, "timeout error code");

        $display("[TEST] invalid page length is rejected before bus traffic");
        launch(2'd0, 0, 0, MAX_WORDS+1, 100);
        wait_done(status);
        assert (status[3]) else $fatal(1, "invalid-length status missing");
        apb_read(12'h020, rd);
        expect_word(rd, 1, "bad length error code");

        $display("============================================================");
        $display("PASS: %0d end-to-end scenarios completed", tests_run);
        $display("============================================================");
        repeat (5) @(posedge clk);
        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "global simulation timeout");
    end
endmodule
