// =============================================================================
// apb_pkg : aio_soc 의 APB 슬레이브 번호와 메모리 맵
//
//   cpu/rtl/pkg/apb_pkg.sv 에서 출발했다. GPI / GPIO / FND 를 빼고
//   NAND 컨트롤러를 넣었다.
//
//   [메모리 맵]
//     0x0000_0000 ~              명령어 ROM (CPU 에 직결. 데이터 버스로는 못 읽는다)
//     0x1000_0000 ~ 0x1000_0FFF  RAM   (4KB. NAND 컨트롤러의 DMA 도 이 RAM 을 본다)
//     0x2000_0100 ~ 0x2000_01FF  GPO   (LED / 테스트벤치에 단계 알리기)
//     0x2000_0300 ~ 0x2000_03FF  UART
//     0x3000_0000 ~ 0x3000_0FFF  NAND 컨트롤러 (aio_nand_top)
//     그 외                      디코드 에러 (슬레이브 없음)
// =============================================================================
package apb_pkg;

    localparam int N_SLAVE = 4;

    // psel 비트 번호
    localparam int SLV_RAM  = 0;
    localparam int SLV_GPO  = 1;
    localparam int SLV_UART = 2;
    localparam int SLV_NAND = 3;

    // 각 영역의 시작 주소
    localparam logic [31:0] RAM_BASE  = 32'h1000_0000;
    localparam logic [31:0] GPO_BASE  = 32'h2000_0100;
    localparam logic [31:0] UART_BASE = 32'h2000_0300;
    localparam logic [31:0] NAND_BASE = 32'h3000_0000;

    // ---------------- 레지스터 오프셋 ----------------
    // GPO
    localparam logic [7:0] GPO_ODR   = 8'h00;  // RW : 출력 핀

    // UART
    localparam logic [7:0] UART_SR    = 8'h00; // RO : 상태
    localparam logic [7:0] UART_TXD   = 8'h04; // WO : 쓰면 송신 시작
    localparam logic [7:0] UART_RXD   = 8'h08; // RO : 읽으면 rx_valid 가 내려간다

    // UART_SR 비트
    localparam int UART_SR_RX_VALID   = 0;
    localparam int UART_SR_RX_OVERRUN = 1;
    localparam int UART_SR_TX_BUSY    = 2;

    // NAND 컨트롤러 레지스터는 sw/aio_nand_regs.h 와 docs/design_spec.md 참고

endpackage
