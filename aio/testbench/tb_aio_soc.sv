`timescale 1ns/1ps

// =============================================================================
// tb_aio_soc : SoC 전체를 펌웨어로 돌리는 테스트벤치
//
//   자극은 ROM 에 든 펌웨어(sw/main.c)가 만든다. 테스트벤치가 미는 것은
//   클럭과 리셋뿐이고, 나머지는 지켜보기만 한다.
//
//     - UART TX 를 받아 글자로 찍는다            -> "AIO EBPR12 PASS"
//     - GPO 를 보고 있다가 펌웨어가 요청하면 NAND 셀을 뒤집는다 (fault injection)
//         0x11 : 1 bit   /   0x12 : 같은 워드에 2 bit
//     - GPO = 0xA5 면 통과, 0xEn 이면 n 단계에서 실패
//     - 끝날 때 NAND 모델의 타이밍 위반이 0 인지 확인한다
//
//   펌웨어(CPU)와 하드웨어(컨트롤러 + PHY)와 NAND 가 한 번에 맞물려 도는지를
//   보는 것이 목적이다. 구석 상황은 tb_aio_nand_top 과 UVM 쪽에서 본다.
// =============================================================================
module tb_aio_soc;
    // UART 를 시뮬레이션 안에서 빨리 끝내려고 보드레이트를 크게 잡는다.
    //   DIV = SYS_CLK / (BAUD * 16) = 1  ->  1 bit = 16 클럭
    localparam int SYS_CLK = 100_000_000;
    localparam int BAUD    =   6_250_000;
    localparam int BIT_CYC = 16;

    // sw/main.c 와 맞춘 값
    localparam int PAGE_WORDS = 64;
    localparam int PPB        = 64;
    localparam int TEST_ROW   = 1*PPB + 3;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic       uart_tx;
    logic [7:0] gpo_pin;
    logic       nand_irq, nand_init_done;
    logic       nand_ce_n, nand_cle, nand_ale, nand_we_n, nand_re_n, nand_wp_n;
    logic [7:0] nand_dq_o;
    logic       nand_dq_oe;
    wire  [7:0] nand_dq;
    wire        nand_rb_n;

    assign nand_dq = nand_dq_oe ? nand_dq_o : 8'hzz;
    pullup (nand_rb_n);

`ifndef ROM_FILE
    `define ROM_FILE "fw.hex"
`endif

    aio_soc #(
        .SYS_CLK       (SYS_CLK),
        .BAUD          (BAUD),
        .ROM_FILE      (`ROM_FILE),
        .MAX_PAGE_WORDS(PAGE_WORDS),
        .T_PW          (4),             // aio_fpga_top 과 같은 값으로 돌린다
        .RB_TIMEOUT_W  (16)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .uart_rx(1'b1), .uart_tx(uart_tx),
        .gpo_pin(gpo_pin),
        .write_protect(1'b0),
        .nand_irq(nand_irq), .nand_init_done(nand_init_done),
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

    // ---------------- UART 수신기 ----------------
    logic [7:0] uart_byte;
    string      uart_line;
    string      uart_all;

    initial begin
        uart_line = "";
        uart_all  = "";
        forever begin
            @(negedge uart_tx);                             // start bit
            repeat (BIT_CYC + BIT_CYC/2) @(posedge clk);    // bit0 한가운데
            for (int i = 0; i < 8; i++) begin
                uart_byte[i] = uart_tx;                     // LSB first
                repeat (BIT_CYC) @(posedge clk);
            end
            if (uart_byte == 8'h0a) begin
                $display("[%0t] UART: %s", $time, uart_line);
                uart_line = "";
            end else begin
                uart_line = {uart_line, string'(uart_byte)};
                uart_all  = {uart_all,  string'(uart_byte)};
            end
        end
    end

    // ---------------- DMA / APB 활동 세기 (보고용) ----------------
    int n_dma_rd, n_dma_wr, n_apb_nand;
    always @(posedge clk) begin
        if (rst_n) begin
            if (dut.mem_req_valid && dut.mem_req_ready) begin
                if (dut.mem_req_write) n_dma_wr++;
                else                   n_dma_rd++;
            end
            if (dut.psel[3] && dut.penable) n_apb_nand++;
        end
    end

    // ---------------- 펌웨어 요청에 따라 셀 뒤집기 ----------------
    always @(gpo_pin) begin
        case (gpo_pin)
            8'h11: begin
                u_nand.flip_bit(TEST_ROW, 5*5 + 0, 7);      // word 5, bit 7
                $display("[%0t] TB  : injected 1-bit fault (word 5)", $time);
            end
            8'h12: begin
                u_nand.flip_bit(TEST_ROW, 5*3 + 0, 0);      // word 3, bit 0
                u_nand.flip_bit(TEST_ROW, 5*3 + 2, 5);      // word 3, bit 21
                $display("[%0t] TB  : injected 2-bit fault (word 3)", $time);
            end
            default: ;
        endcase
    end

    // ---------------- CPU multicycle 제약의 근거 ----------------
    // syn/aio_fpga_top.xdc 는 "PC / 레지스터 파일에서 출발한 값은 3 클럭 뒤에야
    // 잡힌다" 고 STA 에 알려 준다. 그 말이 참이려면, PC 가 바뀐 직후 2 클럭 동안은
    // PC 도, 레지스터 파일도, APB 마스터도 아무것도 잡으면 안 된다.
    // 제약은 STA 가 검증해 주지 않는다. 제약이 참인지는 여기서 본다.
    wire cpu_pc_en = dut.U0_CPU.pc_enable;      // 이 클럭 끝에 PC 가 바뀐다
    wire cpu_quiet = !dut.U0_CPU.pc_enable && !dut.U0_CPU.rf_we && !dut.U0_CPU.transfer;
    int  n_instr;

    property p_cpu_multicycle;
        @(posedge clk) disable iff (!rst_n)
        cpu_pc_en |=> cpu_quiet ##1 cpu_quiet;
    endproperty

    a_cpu_multicycle : assert property (p_cpu_multicycle)
        else $error("CPU captured something within 2 cycles of a PC update : the multicycle constraint in the XDC is no longer valid");

    // 레지스터 파일은 PC 가 바뀌는 클럭(wb)에만 쓰여야 한다. 따로 쓰이면 위 검사가 놓친다.
    a_rf_we_with_pc_en : assert property (@(posedge clk) disable iff (!rst_n)
                                          dut.U0_CPU.rf_we |-> dut.U0_CPU.pc_enable)
        else $error("rf_we without pc_enable");

    always @(posedge clk) if (rst_n && cpu_pc_en) n_instr++;

    // ---------------- 판정 ----------------
    initial begin
        n_dma_rd = 0; n_dma_wr = 0; n_apb_nand = 0; n_instr = 0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        wait ((gpo_pin == 8'ha5) || (gpo_pin[7:4] == 4'he));
        repeat (20 * BIT_CYC) @(posedge clk);               // 마지막 글자가 다 나갈 때까지

        if (gpo_pin != 8'ha5)
            $fatal(1, "firmware reported failure at step %0d (uart: %s%s)",
                   gpo_pin[3:0], uart_all, uart_line);
        if (uart_all != "AIO EBPR12 PASS")
            $fatal(1, "unexpected UART output: '%s'", uart_all);
        if (u_nand.viol_cnt != 0)
            $fatal(1, "%0d NAND timing/protocol violations", u_nand.viol_cnt);

        $display("============================================================");
        $display("PASS: firmware self-test on aio_soc (uart = '%s')", uart_all);
        $display("      NAND ops : reset=%0d erase=%0d program=%0d read=%0d",
                 u_nand.n_reset, u_nand.n_erase, u_nand.n_prog, u_nand.n_read);
        $display("      DMA      : %0d word read from RAM, %0d word written to RAM", n_dma_rd, n_dma_wr);
        $display("      APB      : %0d accesses to the NAND controller registers", n_apb_nand);
        $display("      CPU      : %0d instructions, multicycle assumption held on every one", n_instr);
        $display("      NAND timing violations : 0");
        $display("============================================================");
        $finish;
    end

    initial begin
        #200_000_000;
        $fatal(1, "global simulation timeout (uart so far: %s%s)", uart_all, uart_line);
    end
endmodule
