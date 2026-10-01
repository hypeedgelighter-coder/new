`timescale 1ns/1ps

// =============================================================================
// tb_aio_uvm : UVM 테스트벤치 최상위
//
//   DUT      : aio_nand_top (코어 + ONFI PHY)
//   상대     : nand_model (핀 레벨 NAND)
//   클래스들 : aio_uvm_pkg. interface 넷을 config_db 로 넘겨받아 DUT 를 만진다.
//
//   빨리 돌리려고 페이지를 16 word 로 줄였고, PHY 의 R/B# timeout 과 stall 판정도
//   짧게 잡았다 (예외 경로를 몇 천 클럭 안에 볼 수 있게).
// =============================================================================
module tb_aio_uvm;
    import uvm_pkg::*;
    import aio_uvm_pkg::*;

    localparam int MAX_WORDS    = 16;
    localparam int PPB          = 64;
    localparam int BLOCKS       = 4;
    localparam int RB_TIMEOUT_W = 13;       // 8192 클럭
    localparam int STALL_W      = 8;        // 256 클럭

    logic clk = 1'b0;
    always #5 clk = ~clk;

    apb_if      apb  (clk);
    mem_if      mem  (clk, apb.presetn);
    nand_pin_if pins (clk);
    aio_bd_if   bd   ();

    logic [7:0] dq_o;
    logic       dq_oe;
    logic [7:0] nand_status;
    logic       phy_init_done;
    wire  [7:0] nand_dq;
    wire        nand_rb_n;

    assign nand_dq = dq_oe ? dq_o : 8'hzz;
    pullup (nand_rb_n);

    assign pins.dq   = nand_dq;
    assign pins.rb_n = nand_rb_n;

    aio_nand_top #(
        .MAX_PAGE_WORDS(MAX_WORDS),
        .RB_TIMEOUT_W  (RB_TIMEOUT_W),
        .STALL_W       (STALL_W)
    ) dut (
        .pclk         (clk),
        .presetn      (apb.presetn),
        .psel         (apb.psel),
        .penable      (apb.penable),
        .pwrite       (apb.pwrite),
        .paddr        (apb.paddr),
        .pwdata       (apb.pwdata),
        .prdata       (apb.prdata),
        .pready       (apb.pready),
        .pslverr      (apb.pslverr),
        .irq          (apb.irq),
        .mem_req_valid(mem.req_valid),
        .mem_req_ready(mem.req_ready),
        .mem_req_write(mem.req_write),
        .mem_req_addr (mem.req_addr),
        .mem_req_wdata(mem.req_wdata),
        .mem_req_wstrb(mem.req_wstrb),
        .mem_rsp_valid(mem.rsp_valid),
        .mem_rsp_rdata(mem.rsp_rdata),
        .mem_rsp_ready(mem.rsp_ready),
        .write_protect(bd.write_protect),
        .phy_init_done(phy_init_done),
        .nand_status  (nand_status),
        .nand_ce_n    (pins.ce_n),
        .nand_cle     (pins.cle),
        .nand_ale     (pins.ale),
        .nand_we_n    (pins.we_n),
        .nand_re_n    (pins.re_n),
        .nand_wp_n    (pins.wp_n),
        .nand_dq_o    (dq_o),
        .nand_dq_oe   (dq_oe),
        .nand_dq_i    (nand_dq),
        .nand_rb_n    (nand_rb_n)
    );

    nand_model #(
        .PAGES_PER_BLOCK(PPB),
        .BLOCKS         (BLOCKS)
    ) u_nand (
        .ce_n(pins.ce_n), .cle(pins.cle), .ale(pins.ale),
        .we_n(pins.we_n), .re_n(pins.re_n), .wp_n(pins.wp_n),
        .dq(nand_dq), .rb_n(nand_rb_n)
    );

    initial begin
        string test_name;
        int    fd;

        apb.presetn      = 1'b0;
        bd.write_protect = 1'b0;

        uvm_config_db #(virtual apb_if)::set(null, "*", "apb_vif", apb);
        uvm_config_db #(virtual mem_if)::set(null, "*", "mem_vif", mem);
        uvm_config_db #(virtual nand_pin_if)::set(null, "*", "nand_vif", pins);
        uvm_config_db #(virtual aio_bd_if)::set(null, "*", "bd_vif", bd);
        uvm_config_db #(int)::set(null, "*", "max_words", MAX_WORDS);
        uvm_config_db #(int)::set(null, "*", "pages_per_block", PPB);
        uvm_config_db #(int)::set(null, "*", "blocks", BLOCKS);
        uvm_config_db #(int)::set(null, "*", "stall_cycles", 1 << STALL_W);

        // 테스트 이름 : uvm_test.txt 가 있으면 그걸 쓰고, 없으면 +UVM_TESTNAME 또는 기본값
        test_name = "aio_smoke_test";
        fd = $fopen("uvm_test.txt", "r");
        if (fd != 0) begin
            void'($fscanf(fd, "%s", test_name));
            $fclose(fd);
        end
        run_test(test_name);
    end

    // 시뮬레이션이 영영 안 끝나는 일을 막는다
    initial begin
        #200_000_000;
        $display("UVM_FATAL tb_aio_uvm : global simulation timeout");
        $fatal(1, "global simulation timeout");
    end
endmodule
