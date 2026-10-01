// =============================================================================
// aio_soc : RV32I CPU + NAND 컨트롤러를 한 칩으로 묶은 최상위
//
//   cpu/rtl/rv32i_soc.sv 에서 출발했다. GPI / GPIO / FND 를 떼고 NAND 컨트롤러를
//   붙였고, RAM 을 포트 두 개짜리로 바꿔 DMA 가 닿게 했다.
//
//                      +--> RAM (포트 A)  0x1000_0000 <--+
//   ROM --> CPU --> APB Master                           | 같은 메모리
//                      +--> GPO           0x2000_0100    |
//                      +--> UART          0x2000_0300    |
//                      +--> NAND 컨트롤러 0x3000_0000    |
//                             |  DMA ------------------->+ RAM (포트 B)
//                             |
//                             +==== CE# CLE ALE WE# RE# WP# R/B# DQ[7:0] ===> NAND
//
//   [페이지 하나를 쓰는 흐름]
//     1. 펌웨어가 RAM 에 데이터를 채운다                       (APB, 포트 A)
//     2. 펌웨어가 NAND 컨트롤러 레지스터에 row / 주소 / 길이를 쓰고 START
//     3. 컨트롤러가 RAM 에서 직접 읽어 ECC 를 붙인다           (DMA, 포트 B)
//     4. PHY 가 80h - 주소 - 데이터 - 10h 를 핀으로 내보낸다
//     5. 펌웨어는 STATUS.DONE 을 기다린다 (irq 핀도 같이 뜬다)
//   CPU 는 3 ~ 4 동안 데이터를 한 바이트도 만지지 않는다.
//
//   [리셋]
//   CPU 쪽은 동기 리셋, NAND 컨트롤러는 비동기 assert 리셋이다. 같은 rst_n 을
//   쓰되, 풀릴 때는 클럭에 맞춰 풀리도록 밖(aio_fpga_top)에서 동기화해서 넣는다.
//
//   [인터럽트]
//   이 CPU 에는 인터럽트가 없다. nand_irq 는 핀으로만 내보내고 펌웨어는 폴링한다.
// =============================================================================
module aio_soc
    import apb_pkg::*;
    #(
    parameter int SYS_CLK        = 100_000_000,
    parameter int BAUD           = 115_200,
    parameter int RAM_WORDS      = 1024,        // 4KB
    parameter int ROM_WORDS      = 1024,        // 4KB
    parameter     ROM_FILE       = "fw.hex",
    parameter int GPO_WIDTH      = 8,

    // ---- NAND 컨트롤러 ----
    parameter int MAX_PAGE_WORDS = 64,          // 한 번에 옮기는 최대 워드 수 (256 byte)
    parameter int T_SU           = 1,           // 핀 타이밍 (클럭 수). nand_onfi_phy 참고
    parameter int T_PW           = 3,
    parameter int T_HD           = 2,
    parameter int T_WAIT         = 16,
    parameter int RB_TIMEOUT_W   = 24,
    parameter int STALL_W        = 10
    )(
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  uart_rx,
    output logic                  uart_tx,
    output logic [GPO_WIDTH-1:0]  gpo_pin,

    input  logic                  write_protect,    // 1 = NAND 쓰기 금지 (WP# = 0)
    output logic                  nand_irq,
    output logic                  nand_init_done,

    // ---------------- NAND 핀 ----------------
    // DQ 는 o / oe / i 로 나간다. 3-state 버퍼는 패드(aio_fpga_top)에 있다.
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

    // ---------------- CPU <-> 명령어 ROM ----------------
    logic [31:0] instr_addr;
    logic [31:0] instr_code;

    // ---------------- CPU <-> APB Master ----------------
    logic [31:0] bus_addr;
    logic [31:0] bus_wdata;
    logic [3:0]  bus_wstrb;
    logic        bus_we;
    logic        transfer;
    logic [31:0] bus_rdata;
    logic        ready;

    // ---------------- APB ----------------
    logic [31:0]              paddr;
    logic [31:0]              pwdata;
    logic [3:0]               pstrb;
    logic                     pwrite;
    logic                     penable;
    logic [N_SLAVE-1:0]       psel;
    logic [N_SLAVE-1:0]       pready;
    logic [N_SLAVE-1:0][31:0] prdata;

    // ---------------- NAND 컨트롤러 <-> RAM 포트 B (DMA) ----------------
    logic        mem_req_valid;
    logic        mem_req_ready;
    logic        mem_req_write;
    logic [31:0] mem_req_addr;
    logic [31:0] mem_req_wdata;
    logic [3:0]  mem_req_wstrb;
    logic        mem_rsp_valid;
    logic [31:0] mem_rsp_rdata;
    logic        mem_rsp_ready;

    logic        nand_pslverr;      // 이 마스터는 PSLVERR 를 보지 않는다 (APB3 이전 구조)
    logic [7:0]  nand_status;

    // =========================================================================
    // CPU + 명령어 ROM
    // =========================================================================
    rv32i_cpu U0_CPU(
        .clk       (clk),
        .rst_n     (rst_n),
        .instr_code(instr_code),
        .instr_addr(instr_addr),
        .bus_addr  (bus_addr),
        .bus_wdata (bus_wdata),
        .bus_wstrb (bus_wstrb),
        .bus_we    (bus_we),
        .transfer  (transfer),
        .bus_rdata (bus_rdata),
        .ready     (ready)
        );

    instruction_rom #(
        .WORDS    (ROM_WORDS),
        .INIT_FILE(ROM_FILE)
    ) U1_INSTRUCTION_ROM(
        .instr_addr(instr_addr),
        .instr_code(instr_code)
        );

    // =========================================================================
    // APB Requester (Master)
    // =========================================================================
    apb_master U2_APB_MASTER(
        .clk      (clk),
        .rst_n    (rst_n),
        .bus_addr (bus_addr),
        .bus_wdata(bus_wdata),
        .bus_wstrb(bus_wstrb),
        .bus_we   (bus_we),
        .transfer (transfer),
        .bus_rdata(bus_rdata),
        .ready    (ready),
        .paddr    (paddr),
        .pwdata   (pwdata),
        .pstrb    (pstrb),
        .pwrite   (pwrite),
        .penable  (penable),
        .psel     (psel),
        .pready   (pready),
        .prdata   (prdata)
        );

    // =========================================================================
    // APB Completer (Slave) x 4
    // =========================================================================
    apb_dpram #(
        .WORDS(RAM_WORDS)
    ) U3_RAM(
        .clk          (clk),
        .rst_n        (rst_n),
        .psel         (psel   [SLV_RAM]),
        .penable      (penable),
        .pwrite       (pwrite),
        .paddr        (paddr),
        .pwdata       (pwdata),
        .pstrb        (pstrb),
        .prdata       (prdata [SLV_RAM]),
        .pready       (pready [SLV_RAM]),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_addr (mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wstrb(mem_req_wstrb),
        .mem_rsp_valid(mem_rsp_valid),
        .mem_rsp_rdata(mem_rsp_rdata),
        .mem_rsp_ready(mem_rsp_ready)
        );

    apb_gpo #(
        .WIDTH(GPO_WIDTH)
    ) U4_GPO(
        .clk    (clk),
        .rst_n  (rst_n),
        .psel   (psel   [SLV_GPO]),
        .penable(penable),
        .pwrite (pwrite),
        .paddr  (paddr),
        .pwdata (pwdata),
        .prdata (prdata [SLV_GPO]),
        .pready (pready [SLV_GPO]),
        .gpo_pin(gpo_pin)
        );

    apb_uart #(
        .SYS_CLK(SYS_CLK),
        .BAUD   (BAUD)
    ) U5_UART(
        .clk    (clk),
        .rst_n  (rst_n),
        .psel   (psel   [SLV_UART]),
        .penable(penable),
        .pwrite (pwrite),
        .paddr  (paddr),
        .pwdata (pwdata),
        .prdata (prdata [SLV_UART]),
        .pready (pready [SLV_UART]),
        .rx     (uart_rx),
        .tx     (uart_tx)
        );

    aio_nand_top #(
        .ADDR_WIDTH    (32),
        .MAX_PAGE_WORDS(MAX_PAGE_WORDS),
        .T_SU          (T_SU),
        .T_PW          (T_PW),
        .T_HD          (T_HD),
        .T_WAIT        (T_WAIT),
        .RB_TIMEOUT_W  (RB_TIMEOUT_W),
        .STALL_W       (STALL_W)
    ) U6_NAND(
        .pclk         (clk),
        .presetn      (rst_n),
        .psel         (psel   [SLV_NAND]),
        .penable      (penable),
        .pwrite       (pwrite),
        .paddr        (paddr[11:0]),
        .pwdata       (pwdata),
        .prdata       (prdata [SLV_NAND]),
        .pready       (pready [SLV_NAND]),
        .pslverr      (nand_pslverr),
        .irq          (nand_irq),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_addr (mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wstrb(mem_req_wstrb),
        .mem_rsp_valid(mem_rsp_valid),
        .mem_rsp_rdata(mem_rsp_rdata),
        .mem_rsp_ready(mem_rsp_ready),
        .write_protect(write_protect),
        .phy_init_done(nand_init_done),
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
