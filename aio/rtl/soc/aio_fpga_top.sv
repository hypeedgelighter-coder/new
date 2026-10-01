// =============================================================================
// aio_fpga_top : Basys3 (xc7a35tcpg236-1) 용 최상위
//
//   aio_soc 를 보드 핀에 연결한다. 여기에만 있는 것은 셋이다.
//     1) 리셋 동기화기   : 버튼은 비동기로 눌리지만 풀릴 때는 클럭에 맞춰 풀려야 한다
//     2) DQ 3-state 버퍼 : 칩 안에는 3-state 가 없다. 패드에 딱 한 군데만 둔다
//     3) 비동기 입력 동기화 : 스위치(write protect)
//
//   [핀]
//     clk          W5    100 MHz
//     btn_rst      U18   가운데 버튼 (누르면 리셋)
//     sw_wp        V17   SW0 = 1 이면 NAND 쓰기 금지
//     uart_tx/rx   A18 / B18
//     led[7:0]     펌웨어가 쓰는 GPO  (0xA5 = 셀프 테스트 통과)
//     led[8]       NAND 컨트롤러 irq
//     led[9]       NAND 초기화(FFh) 완료
//     nand_dq[7:0] Pmod JB
//     nand_*       Pmod JC  (CE# CLE ALE WE# RE# WP# R/B#)
//
//   Basys3 에는 NAND 가 없다. Pmod 에 NAND 를 달지 않으면 R/B# 가 풀업으로 1 에
//   머물러 컨트롤러는 "늘 ready" 로 보고, DQ 에서는 아무 값이나 읽힌다.
//   이 최상위의 목적은 합성 / 배치배선 / 타이밍 분석을 실제 I/O 와 함께 해 보는 것이다.
// =============================================================================
module aio_fpga_top #(
    parameter     ROM_FILE = "fw.hex",
    parameter int BAUD     = 115_200,
    // RE#/WE# 펄스 폭 (클럭 수). 시뮬레이션 기본값은 3 이지만, 배치배선 뒤 I/O 지연을
    // 넣어 보니 3 클럭(30 ns)으로는 읽기 데이터가 서기 전에 잡게 된다.
    // syn/aio_fpga_top.xdc 의 "NAND 입력" 절에 계산이 있다. 그 절의 multicycle 값과 짝이다.
    parameter int T_PW     = 4
)(
    input  logic       clk,
    input  logic       btn_rst,
    input  logic       sw_wp,

    input  logic       uart_rx,
    output logic       uart_tx,
    output logic [9:0] led,

    output logic       nand_ce_n,
    output logic       nand_cle,
    output logic       nand_ale,
    output logic       nand_we_n,
    output logic       nand_re_n,
    output logic       nand_wp_n,
    inout  wire  [7:0] nand_dq,
    input  logic       nand_rb_n
);

    // ---------------- 리셋 동기화 : 비동기 assert, 동기 deassert ----------------
    // 누르는 순간에는 클럭과 상관없이 바로 리셋이 걸린다.
    // 떼는 순간에는 플롭 두 개를 지나서 풀린다. 리셋이 클럭 엣지 근처에서 풀리면
    // 플롭마다 "풀렸다 / 아직이다" 가 갈려 상태기계가 엉뚱한 상태로 출발할 수 있다.
    logic [1:0] rst_sync;
    logic       rst_n;

    always_ff @(posedge clk or posedge btn_rst)
    begin
        if(btn_rst) rst_sync <= 2'b00;
        else        rst_sync <= {rst_sync[0], 1'b1};
    end

    assign rst_n = rst_sync[1];

    // ---------------- 스위치 동기화 ----------------
    logic [1:0] wp_sync;

    always_ff @(posedge clk)
    begin
        wp_sync <= {wp_sync[0], sw_wp};
    end

    // ---------------- SoC ----------------
    logic [7:0] gpo_pin;
    logic       nand_irq;
    logic       nand_init_done;
    logic [7:0] nand_dq_o;
    logic       nand_dq_oe;

    aio_soc #(
        .SYS_CLK (100_000_000),
        .BAUD    (BAUD),
        .ROM_FILE(ROM_FILE),
        .T_PW    (T_PW)
    ) U_SOC(
        .clk           (clk),
        .rst_n         (rst_n),
        .uart_rx       (uart_rx),
        .uart_tx       (uart_tx),
        .gpo_pin       (gpo_pin),
        .write_protect (wp_sync[1]),
        .nand_irq      (nand_irq),
        .nand_init_done(nand_init_done),
        .nand_ce_n     (nand_ce_n),
        .nand_cle      (nand_cle),
        .nand_ale      (nand_ale),
        .nand_we_n     (nand_we_n),
        .nand_re_n     (nand_re_n),
        .nand_wp_n     (nand_wp_n),
        .nand_dq_o     (nand_dq_o),
        .nand_dq_oe    (nand_dq_oe),
        .nand_dq_i     (nand_dq),
        .nand_rb_n     (nand_rb_n)
        );

    // ---------------- DQ 패드 ----------------
    assign nand_dq = nand_dq_oe ? nand_dq_o : 8'hzz;

    assign led = {nand_init_done, nand_irq, gpo_pin};

endmodule
