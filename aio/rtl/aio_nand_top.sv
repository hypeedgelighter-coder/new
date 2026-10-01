`timescale 1ns/1ps

// =============================================================================
// aio_nand_top : NAND 컨트롤러 IP 의 최상위 (코어 + PHY)
//
//      APB3  ----->+---------------------+  트랜잭션  +---------------+
//      irq   <-----|  aio_nand_dma_ctrl  |<---------->| nand_onfi_phy |<===> NAND 핀
//      DMA   <---->|  (레지스터 / DMA /  |  cmd/w/r   | (커맨드 시퀀스 |
//                  |   page buffer/ECC)  |  done/fail |  + 핀 타이밍)  |
//                  +---------------------+            +---------------+
//
//   코어는 "무엇을 옮길지" 만 알고, PHY 는 "핀을 어떻게 흔들지" 만 안다.
//   경계가 valid/ready 트랜잭션이라서, NAND 가 Toggle DDR 로 바뀌어도
//   PHY 만 갈아 끼우면 된다.
//
//   DQ 는 여기서 3-state 로 묶지 않고 o / oe / i 로 내보낸다. 3-state 버퍼는
//   칩 최상위(패드)에 하나만 있어야 한다. (FPGA 라면 IOBUF, ASIC 이라면 pad cell)
// =============================================================================
module aio_nand_top #(
    parameter int ADDR_WIDTH       = 32,
    parameter int MAX_PAGE_WORDS   = 64,
    parameter int WORD_COUNT_WIDTH = 16,
    parameter int T_SU             = 1,
    parameter int T_PW             = 3,
    parameter int T_HD             = 2,
    parameter int T_WAIT           = 16,
    parameter int RB_TIMEOUT_W     = 24,
    parameter int STALL_W          = 10
) (
    input  logic                  pclk,
    input  logic                  presetn,

    // ---------------- APB3 slave ----------------
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [11:0]           paddr,
    input  logic [31:0]           pwdata,
    output logic [31:0]           prdata,
    output logic                  pready,
    output logic                  pslverr,
    output logic                  irq,

    // ---------------- DMA memory master ----------------
    output logic                  mem_req_valid,
    input  logic                  mem_req_ready,
    output logic                  mem_req_write,
    output logic [ADDR_WIDTH-1:0] mem_req_addr,
    output logic [31:0]           mem_req_wdata,
    output logic [3:0]            mem_req_wstrb,
    input  logic                  mem_rsp_valid,
    input  logic [31:0]           mem_rsp_rdata,
    output logic                  mem_rsp_ready,

    // ---------------- 상태 / 제어 ----------------
    input  logic                  write_protect,
    output logic                  phy_init_done,
    output logic [7:0]            nand_status,

    // ---------------- NAND 핀 ----------------
    output logic                  nand_ce_n,
    output logic                  nand_cle,
    output logic                  nand_ale,
    output logic                  nand_we_n,
    output logic                  nand_re_n,
    output logic                  nand_wp_n,
    output logic [7:0]            nand_dq_o,
    output logic                  nand_dq_oe,
    input  logic [7:0]            nand_dq_i,
    input  logic                  nand_rb_n
);
    logic                        cmd_valid, cmd_ready;
    logic [1:0]                  cmd;
    logic [23:0]                 row;
    logic [WORD_COUNT_WIDTH-1:0] words;
    logic                        w_valid, w_ready, w_last;
    logic [31:0]                 w_data;
    logic [6:0]                  w_ecc;
    logic                        r_valid, r_ready, r_last;
    logic [31:0]                 r_data;
    logic [6:0]                  r_ecc;
    logic                        done, fail;

    aio_nand_dma_ctrl #(
        .ADDR_WIDTH      (ADDR_WIDTH),
        .MAX_PAGE_WORDS  (MAX_PAGE_WORDS),
        .WORD_COUNT_WIDTH(WORD_COUNT_WIDTH)
    ) u_ctrl (
        .pclk          (pclk),
        .presetn       (presetn),
        .psel          (psel),
        .penable       (penable),
        .pwrite        (pwrite),
        .paddr         (paddr),
        .pwdata        (pwdata),
        .prdata        (prdata),
        .pready        (pready),
        .pslverr       (pslverr),
        .irq           (irq),
        .mem_req_valid (mem_req_valid),
        .mem_req_ready (mem_req_ready),
        .mem_req_write (mem_req_write),
        .mem_req_addr  (mem_req_addr),
        .mem_req_wdata (mem_req_wdata),
        .mem_req_wstrb (mem_req_wstrb),
        .mem_rsp_valid (mem_rsp_valid),
        .mem_rsp_rdata (mem_rsp_rdata),
        .mem_rsp_ready (mem_rsp_ready),
        .nand_cmd_valid(cmd_valid),
        .nand_cmd_ready(cmd_ready),
        .nand_cmd      (cmd),
        .nand_row      (row),
        .nand_words    (words),
        .nand_w_valid  (w_valid),
        .nand_w_ready  (w_ready),
        .nand_w_data   (w_data),
        .nand_w_ecc    (w_ecc),
        .nand_w_last   (w_last),
        .nand_r_valid  (r_valid),
        .nand_r_ready  (r_ready),
        .nand_r_data   (r_data),
        .nand_r_ecc    (r_ecc),
        .nand_r_last   (r_last),
        .nand_done     (done),
        .nand_fail     (fail)
    );

    nand_onfi_phy #(
        .WORD_COUNT_WIDTH(WORD_COUNT_WIDTH),
        .T_SU            (T_SU),
        .T_PW            (T_PW),
        .T_HD            (T_HD),
        .T_WAIT          (T_WAIT),
        .RB_TIMEOUT_W    (RB_TIMEOUT_W),
        .STALL_W         (STALL_W)
    ) u_phy (
        .clk          (pclk),
        .rst_n        (presetn),
        .cmd_valid    (cmd_valid),
        .cmd_ready    (cmd_ready),
        .cmd          (cmd),
        .row          (row),
        .words        (words),
        .w_valid      (w_valid),
        .w_ready      (w_ready),
        .w_data       (w_data),
        .w_ecc        (w_ecc),
        .w_last       (w_last),
        .r_valid      (r_valid),
        .r_ready      (r_ready),
        .r_data       (r_data),
        .r_ecc        (r_ecc),
        .r_last       (r_last),
        .done         (done),
        .fail         (fail),
        .write_protect(write_protect),
        .init_done    (phy_init_done),
        .nand_status  (nand_status),
        .nand_ce_n    (nand_ce_n),
        .nand_cle     (nand_cle),
        .nand_ale     (nand_ale),
        .nand_we_n    (nand_we_n),
        .nand_re_n    (nand_re_n),
        .nand_wp_n    (nand_wp_n),
        .nand_dq_o    (nand_dq_o),
        .nand_dq_oe   (nand_dq_oe),
        .nand_dq_i    (nand_dq_i),
        .nand_rb_n    (nand_rb_n)
    );
endmodule
