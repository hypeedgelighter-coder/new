// =============================================================================
// rv32i_cpu : datapath + control_unit + bus_access
//
//   메모리는 이제 이 안에 없다. 밖으로 나가는 것은 APB 마스터에게 줄
//   단순 버스 신호뿐이다.
//
//       bus_addr / bus_wdata / bus_wstrb / bus_we / transfer  ->
//                                                    <- bus_rdata / ready
//
//   그림의 CPU 상자에서 나오는 Addr(bus_addr) / wData(bus_wdata) /
//   transfer / bus_we / rData(bus_rdata) / READY 가 그대로 이 포트들이다.
//   bus_wstrb 만 그림에 없는데, SB/SH 를 살리려고 APB4 의 PSTRB 를 같이
//   내보낸다. 자세한 사연은 bus_access.sv 주석에 있다.
//
//   명령어 ROM 은 여전히 버스를 타지 않고 직결이다 (하버드 구조).
// =============================================================================
module rv32i_cpu(
    input  logic         clk,
    input  logic         rst_n,

    // ---------------- 명령어 ROM ----------------
    input  logic [31:0]  instr_code,
    output logic [31:0]  instr_addr,

    // ---------------- APB 마스터 ----------------
    output logic [31:0]  bus_addr,
    output logic [31:0]  bus_wdata,
    output logic [3:0]   bus_wstrb,
    output logic         bus_we,
    output logic         transfer,
    input  logic [31:0]  bus_rdata,
    input  logic         ready
    );

    // ---------------- control_unit -> datapath ----------------
    logic       pc_enable;      // 멀티사이클 : 명령의 마지막 단계에서만 PC 갱신
    logic       rf_we;          // wb 단계에서만 1
    logic [3:0] alu_control;    // {funct7[5], funct3}
    logic       alusrc_sel;     // 0 = rs2, 1 = imm
    logic [2:0] rf_srcsel;      // RFWdSrcSel : ALU / MEM / imm / PC+imm / PC+4
    logic       branch;         // B-type   : b_taken 과 AND 되어 PC 를 바꾼다
    logic       jal;            // J-type   : 조건 없이 PC + imm
    logic       jalr;           // JL-type  : 조건 없이 PC = (rs1 + imm) & ~1
    logic [2:0] itype;          // Load / Store 접근 크기 (funct3)

    // ---------------- datapath <-> bus_access ----------------
    logic [31:0] daddr;         // ALU 결과 = rs1 + imm (주소)
    logic [31:0] dwdata;        // rs2 (정렬 전 Store 데이터)
    logic [31:0] drdata;        // 레인 추출 + 부호확장까지 끝난 Load 데이터

    assign bus_addr = daddr;

    datapath U0_DATAPATH(
        .clk         (clk),
        .rst_n       (rst_n),
        .pc_enable   (pc_enable),
        .rf_we       (rf_we),
        .alusrc_sel  (alusrc_sel),
        .alu_control (alu_control),
        .instr_code  (instr_code),
        .drdata      (drdata),
        .rf_srcsel   (rf_srcsel),
        .branch      (branch),
        .jal         (jal),
        .jalr        (jalr),
        .instr_addr  (instr_addr),
        .daddr       (daddr),
        .dwdata      (dwdata)
        );

    control_unit U1_CONTROL_UNIT(
        .clk         (clk),
        .rst_n       (rst_n),
        .instr_code  (instr_code),
        .pc_enable   (pc_enable),
        .alu_control (alu_control),
        .rf_we       (rf_we),
        .alusrc_sel  (alusrc_sel),
        .bus_we      (bus_we),
        .transfer    (transfer),
        .bus_ready   (ready),
        .itype       (itype),
        .rf_srcsel   (rf_srcsel),
        .branch      (branch),
        .jal         (jal),
        .jalr        (jalr)
        );

    // 예전 data_memory 가 들고 있던 바이트 레인 로직이 여기로 왔다.
    bus_access U2_BUS_ACCESS(
        .addr_lsb    (daddr[1:0]),
        .itype       (itype),
        .rs2         (dwdata),
        .rdata_bus   (bus_rdata),
        .wdata_bus   (bus_wdata),
        .wstrb       (bus_wstrb),
        .rdata_cpu   (drdata)
        );

endmodule
