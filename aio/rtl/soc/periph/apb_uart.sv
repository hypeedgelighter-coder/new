// =============================================================================
// apb_uart : APB Completer (Slave) - UART
//
//   0x00 SR  (RO) : [0] rx_valid   수신 데이터 있음
//                   [1] rx_overrun 안 읽고 놔뒀다가 덮어썼다
//                   [2] tx_busy    송신 중
//   0x04 TXD (WO) : 쓰면 송신 시작. tx_busy 면 그 쓰기는 버린다.
//   0x08 RXD (RO) : 읽으면 rx_valid / rx_overrun 이 내려간다.
//
//   [소프트웨어에서 쓰는 법]
//       송신 : while (*SR & 0x4);      *TXD = c;
//       수신 : while (!(*SR & 0x1));   c = *RXD;
//
//   UART 코어(baud_tick_gen / uart_tx / uart_rx)는 uart_core.sv 에 있다.
//   2026_08_05_UART 것을 그대로 가져와 리셋만 이 CPU 에 맞춰
//   동기 active-low 로 바꿨다. 16배 오버샘플링이다.
// =============================================================================
module apb_uart #(
    parameter int SYS_CLK = 100_000_000,
    parameter int BAUD    = 9_600
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,

    input  logic        rx,
    output logic        tx
);

    logic       baud_tick;
    logic       tx_start, tx_busy, tx_done;
    logic [7:0] rx_data;
    logic       rx_done;

    logic [7:0] rx_buf;
    logic       rx_valid;
    logic       rx_overrun;

    logic       wr_en, rd_en;

    assign pready = 1'b1;
    assign wr_en  = psel && penable &&  pwrite && pready;
    assign rd_en  = psel && penable && !pwrite && pready;

    // ---------------- 송신 ----------------
    // tx_start 는 한 사이클짜리 펄스여야 한다. 한 번의 APB 전송에서 ACCESS 는
    // pready 와 함께 딱 한 사이클이므로 wr_en 을 그대로 써도 된다.
    assign tx_start = wr_en && (paddr[7:0] == 8'h04) && !tx_busy;

    // ---------------- 수신 버퍼 ----------------
    // 1 바이트짜리 홀딩 레지스터. 안 읽은 채 다음 바이트가 오면 overrun.
    always_ff @(posedge clk)
    begin
        if(!rst_n)
        begin
            rx_buf     <= 8'h00;
            rx_valid   <= 1'b0;
            rx_overrun <= 1'b0;
        end
        else if(rx_done)
        begin
            rx_buf   <= rx_data;
            rx_valid <= 1'b1;
            if(rx_valid) rx_overrun <= 1'b1;   // 못 읽어간 걸 덮어썼다
        end
        // RXD 를 읽어 가면 플래그를 내린다.
        // 같은 사이클에 rx_done 이 겹치면 새로 들어온 쪽이 이긴다.
        else if(rd_en && (paddr[7:0] == 8'h08))
        begin
            rx_valid   <= 1'b0;
            rx_overrun <= 1'b0;
        end
    end

    always_comb
    begin
        prdata = 32'h0000_0000;
        case(paddr[7:0])
            8'h00   : prdata = {29'b0, tx_busy, rx_overrun, rx_valid};  // SR
            8'h08   : prdata = {24'b0, rx_buf};                         // RXD
            default : prdata = 32'h0000_0000;
        endcase
    end

    // ---------------- UART 코어 ----------------
    baud_tick_gen #(
        .SYS_CLK   (SYS_CLK),
        .BAUD      (BAUD),
        .OVERSAMPLE(16)
    ) U0_BAUD_TICK_GEN(
        .clk        (clk),
        .rst_n      (rst_n),
        .o_baud_tick(baud_tick)
    );

    uart_tx U1_UART_TX(
        .clk        (clk),
        .rst_n      (rst_n),
        .i_baud_tick(baud_tick),
        .tx_start   (tx_start),
        .tx_data    (pwdata[7:0]),
        .tx_busy    (tx_busy),
        .tx_done    (tx_done),
        .tx         (tx)
    );

    uart_rx U2_UART_RX(
        .clk        (clk),
        .rst_n      (rst_n),
        .rx         (rx),
        .i_baud_tick(baud_tick),
        .rx_data    (rx_data),
        .rx_done    (rx_done)
    );

endmodule
