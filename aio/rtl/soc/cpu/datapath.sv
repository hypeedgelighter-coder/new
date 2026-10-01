`define SIMULATION

// =============================================================================
// PC 전용 연산 유닛(pc_alu)의 op 인코딩.
// 원래는 rtl/pkg/ 밑에 두는 게 맞지만, 같은 파일 맨 위에 두면
// pc_unit / pc_alu 보다 먼저 컴파일되는 것이 보장된다.
// =============================================================================
package rv32_pc_pkg;

    typedef enum logic [1:0] {
        PC_NEXT4  = 2'b00,  // PC + 4         : 순차 실행 (R/I/S/IL/U/B not-taken)
        PC_TARGET = 2'b01,  // PC + imm       : B taken / JAL
        PC_JALR   = 2'b10   // (rs1+imm) & ~1 : JALR
    } pc_op_e;

endpackage

module datapath
    import rv32_pkg::*;
    (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        pc_enable,  // 멀티사이클 : 명령의 마지막 단계에서만 PC 갱신
    input  logic        rf_we,
    input  logic        alusrc_sel,
    input  logic [3:0]  alu_control,
    input  logic [31:0] instr_code,
    input  logic [31:0] drdata,
    input  logic [2:0]  rf_srcsel,
    input  logic        branch,
    input  logic        jal,
    input  logic        jalr,
    output logic [31:0] instr_addr,
    output logic [31:0] daddr,
    output logic [31:0] dwdata
);

    logic [31:0] alu_result, rf_rd1, rf_rd2;
    logic [31:0] imm_extend, alusrc_muxout, wb_muxout;
    logic        b_taken;
    // PC 관련 값은 전부 pc_unit 안에서 만들어져 나온다.
    logic [31:0] pc_plus4, pc_target;

    assign daddr  = alu_result;
    assign dwdata = rf_rd2;


    reg_file U0_REG_FILE(
        .clk(clk),
        .rst_n(rst_n),
        .ra1(instr_code[19:15]),
        .ra2(instr_code[24:20]),
        .wa(instr_code[11:7]),
        .wd(wb_muxout),
        .we(rf_we),
        .rd1(rf_rd1),
        .rd2(rf_rd2)
    );

    imm_extend U1_IMM_EXTENDER(
        .instr_code(instr_code),
        .imm_extend(imm_extend)
    );

    mux_2x1 U2_ALUSRC_MUX(
        .sel(alusrc_sel),
        .in0(rf_rd2),
        .in1(imm_extend),
        .mux_out(alusrc_muxout)
    );
    alu U3_ALU(
        .rs1(rf_rd1),
        .rs2(alusrc_muxout),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .b_taken(b_taken)
    );

    // ---------------- PC 전용 연산 유닛 ----------------
    // PC 계산에 메인 ALU(U3_ALU)를 빌려 쓰지 않는다.
    // JALR 의 rs1 + imm 까지 pc_unit 안의 pc_alu 가 직접 만든다.
    //   - pc_plus4  : 순차 실행용 + JAL/JALR 의 복귀 주소
    //   - pc_target : PC + imm (B/JAL/AUIPC) 또는 rs1 + imm (JALR)
    // 이 둘은 "같은 사이클에 동시에" 필요하다 (JAL : rd = PC+4 이면서 PC = PC+imm)
    // 그래서 가산기 하나로 돌려 쓸 수 없고, 두 값 다 밖으로 뽑아 준다.
    pc_unit U4_PC(
        .clk(clk),
        .rst_n(rst_n),
        .en(pc_enable),     // 0 인 동안 PC 가 멈춰 있다
        .imm_extend(imm_extend),
        .rs1(rf_rd1),       // JALR 의 base
        .branch(branch),
        .b_taken(b_taken),
        .jal(jal),
        .jalr(jalr),
        .pc(instr_addr),
        .pc_plus4(pc_plus4),
        .pc_target(pc_target)
    );

    // ---------------- Register File 에 써 넣을 값 선택 (RFWdSrcSel) ----------------
    mux_5x1 U5_RFWD_SRC_MUX(
        .sel(rf_srcsel),
        .in0(alu_result),   // WB_ALU   : R, I-type
        .in1(drdata),       // WB_MEM   : Load
        .in2(imm_extend),   // WB_IMM   : LUI
        .in3(pc_target),    // WB_PCIMM : AUIPC (jalr=0 이므로 PC + imm 이다)
        .in4(pc_plus4),     // WB_PC4   : JAL, JALR 복귀 주소
        .mux_out(wb_muxout)
    );
    endmodule

module reg_file(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [4:0]  ra1,
    input  logic [4:0]  ra2,
    input  logic [4:0]  wa,
    input  logic [31:0] wd,
    input  logic        we,
    output logic [31:0] rd1,
    output logic [31:0] rd2
);

    logic [31:0] ram_file [1:31];


    always_ff @(posedge clk)
    begin
        if(!rst_n)
        begin
        `ifdef SIMULATION
            for(int i = 1;i<32;i++) begin
                ram_file[i] <= i; end
        `else
            for(int i = 1;i<32;i++) begin
                ram_file[i] <= 0; end
        `endif
        end
        else
        begin
            // x0 는 하드와이어 0 이라 절대 쓰지 않는다.
            // JAL/JALR 이 rd=x0 으로 "복귀 주소 버리기"를 쓰기 때문에 꼭 필요하다.
            if(we && (wa != 5'd0))
            begin
                ram_file[wa] <= wd;
            end
        end
    end

    assign rd1 = (ra1 != 0) ? ram_file[ra1] : 32'd0;
    assign rd2 = (ra2 != 0) ? ram_file[ra2] : 32'd0;

    endmodule

// =============================================================================== ALU
module alu
    import rv32_pkg::*;
    (
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    input  logic [3:0]  alu_control,
    output logic [31:0] alu_result,
    output logic        b_taken
);

    always_comb
    begin
        alu_result = 32'h0000_0000;
        case(alu_control)
            // {funct7[5], funct3}
            ALU_ADD  : alu_result = rs1 + rs2; // ADD, ADDI
            ALU_SUB  : alu_result = rs1 - rs2; // SUB
            ALU_XOR  : alu_result = rs1 ^ rs2; // XOR, XORI
            ALU_OR   : alu_result = rs1 | rs2; // OR,  ORI
            ALU_AND  : alu_result = rs1 & rs2; // AND, ANDI
            // shamt 은 하위 5bit 만 쓴다 (SLLI/SRLI/SRAI 의 imm[4:0])
            ALU_SLL  : alu_result = rs1 << rs2[4:0];            // Shift Left Logical
            ALU_SRL  : alu_result = rs1 >> rs2[4:0];            // Shift Right Logical
            ALU_SRA  : alu_result = $signed(rs1) >>> rs2[4:0];  // Shift Right Arithmetic (msb_extend)
            ALU_SLT  : alu_result = ($signed(rs1) < $signed(rs2)) ? 32'd1 : 32'd0; // Set Less Than
            ALU_SLTU : alu_result = (rs1 < rs2) ? 32'd1 : 32'd0; // Set Less Than(U), (zero-extends)
            default  : alu_result = 32'h0000_0000;
        endcase
    end

    // Comparator. alu_control[2:0] 이 B-type 의 funct3 다.
    // 이 결과는 datapath 에서 branch 와 AND 된 뒤에만 쓰인다.
    always_comb
    begin
        b_taken = 1'b0;
        case(alu_control[2:0])
            BEQ     : b_taken = (rs1 == rs2);
            BNE     : b_taken = (rs1 != rs2);
            BLT     : b_taken = ($signed(rs1) <  $signed(rs2));
            BGE     : b_taken = ($signed(rs1) >= $signed(rs2));
            BLTU    : b_taken = (rs1 <  rs2);
            BGEU    : b_taken = (rs1 >= rs2);
            default : b_taken = 1'b0;   // funct3 010, 011 은 스펙상 없음
        endcase
    end

    endmodule

// =============================================================================== MUX 2X1
module mux_2x1(
    input  logic        sel,
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    output logic [31:0] mux_out
);

    assign mux_out = (sel) ? in1 : in0;

endmodule

// =============================================================================== MUX 5X1
// RFWdSrcSel 용. ALU / Memory / imm / PC+imm / PC+4 중 하나를 고른다.
module mux_5x1
    import rv32_pkg::*;
    (
    input  logic [2:0]  sel,
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    input  logic [31:0] in2,
    input  logic [31:0] in3,
    input  logic [31:0] in4,
    output logic [31:0] mux_out
);

    always_comb
    begin
        case(sel)
            WB_ALU   : mux_out = in0;
            WB_MEM   : mux_out = in1;
            WB_IMM   : mux_out = in2;
            WB_PCIMM : mux_out = in3;
            WB_PC4   : mux_out = in4;
            default  : mux_out = in0;
        endcase
    end

endmodule

// =============================================================================== imm extender
// 각 타입의 immediate 조립은 타입별 패키지가 들고 있다.
// 여기서는 opcode 로 "어느 포맷인지" 만 고른다.
module imm_extend
    import rv32_pkg::*;(
    input  logic [31:0] instr_code,
    output logic [31:0] imm_extend
);

    opcode_e opcode;

    assign opcode = opcode_e'(instr_code[6:0]);

    always_comb
    begin
        case(opcode)
            OP_STYPE            : imm_extend = imm_s(instr_code);   // rv32_stype_pkg
            OP_ITYPE, OP_ILTYPE,
            OP_JALR             : imm_extend = imm_i(instr_code);   // rv32_itype_pkg
            OP_BTYPE            : imm_extend = imm_b(instr_code);   // rv32_btype_pkg
            OP_LUI, OP_AUIPC    : imm_extend = imm_u(instr_code);   // rv32_utype_pkg
            OP_JAL              : imm_extend = imm_j(instr_code);   // rv32_jtype_pkg
            default             : imm_extend = 32'h0000_0000;
        endcase
    end


endmodule

// =============================================================================== PC ALU
// PC 계산 전용 연산 유닛. 메인 ALU 와 완전히 분리되어 있다.
//
// 왜 가산기가 두 개인가 :
//   JAL   은 rd = PC+4   를 쓰면서 동시에 PC = PC+imm 으로 뛴다.
//   AUIPC 는 rd = PC+imm 을 쓰면서 동시에 PC = PC+4   로 간다.
//   두 경우 다 PC+4 와 PC+imm 이 같은 사이클에 둘 다 필요하므로
//   가산기 하나를 시분할해서는 만들 수 없다.
//
// 왜 그래도 가산기가 두 개뿐인가 :
//   PC+imm (B/JAL/AUIPC) 과 rs1+imm (JALR) 은 절대 같은 사이클에 안 나온다.
//   그래서 base 만 먹스로 골라 주면 덧셈기 하나를 공유할 수 있다.
module pc_alu
    import rv32_pc_pkg::*;
    (
    input  logic [31:0] pc,
    input  logic [31:0] rs1,        // JALR 의 base
    input  logic [31:0] imm,
    input  pc_op_e      pc_op,
    output logic [31:0] pc_plus4,   // 항상 유효 (복귀 주소로도 나간다)
    output logic [31:0] pc_target,  // 항상 유효 (AUIPC 가 그대로 가져다 쓴다)
    output logic [31:0] pc_next
);

    logic [31:0] pc_base;

    // 가산기 1 : +4 전용 증분기. 상수 덧셈이라 캐리 체인만 있으면 된다.
    assign pc_plus4  = pc + 32'd4;

    // 가산기 2 : base + imm
    //   PC_JALR -> base = rs1  (rs1 + imm)
    //   그 외   -> base = PC   (PC + imm, B/JAL/AUIPC 공용)
    assign pc_base   = (pc_op == PC_JALR) ? rs1 : pc;
    assign pc_target = pc_base + imm;

    // 최종 선택
    always_comb
    begin
        case(pc_op)
            PC_NEXT4  : pc_next = pc_plus4;
            PC_TARGET : pc_next = pc_target;
            // RISC-V 스펙 : JALR 은 계산 결과의 최하위 비트를 0 으로 만든다
            PC_JALR   : pc_next = {pc_target[31:1], 1'b0};
            default   : pc_next = pc_plus4;
        endcase
    end

    endmodule

// =============================================================================== Program Counter
// PC 레지스터 + PC ALU 를 한 덩어리로 묶은 유닛.
module pc_unit
    import rv32_pc_pkg::*;
    (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,         // 0 이면 PC 를 그 자리에 붙잡아 둔다
    input  logic [31:0] imm_extend,
    input  logic [31:0] rs1,
    input  logic        branch,     // B-type 이다
    input  logic        b_taken,    // ALU 비교기 결과
    input  logic        jal,
    input  logic        jalr,
    output logic [31:0] pc,
    output logic [31:0] pc_plus4,   // WB_PC4   : JAL/JALR 복귀 주소
    output logic [31:0] pc_target   // WB_PCIMM : AUIPC
);

    logic [31:0] register_pc;
    logic [31:0] pc_next;
    pc_op_e      pc_op;

    assign pc = register_pc;

    // ---------------- 다음 PC 를 어떤 방식으로 만들지 고른다 ----------------
    // branch 로 게이팅하지 않으면 funct3 가 겹치는 R/I-type 연산에서도
    // b_taken 이 떠서 엉뚱하게 분기해버린다 (예 : ADD 의 alu_control 0000 == BEQ)
    // JAL/JALR 은 조건 없는 점프라 b_taken 을 보지 않는다.
    always_comb
    begin
        if(jalr)                            pc_op = PC_JALR;
        else if(jal || (branch && b_taken)) pc_op = PC_TARGET;
        else                                pc_op = PC_NEXT4;
    end

    pc_alu U0_PC_ALU(
        .pc(register_pc),
        .rs1(rs1),
        .imm(imm_extend),
        .pc_op(pc_op),
        .pc_plus4(pc_plus4),
        .pc_target(pc_target),
        .pc_next(pc_next)
    );

    // en 이 0 인 동안 PC 가 멈춰 있어야 instr_code / rf_rd1 / rf_rd2 /
    // alu_result / drdata 가 그 명령이 끝날 때까지 그대로 유지된다.
    always_ff @(posedge clk)
    begin
        if(!rst_n) register_pc <= 32'd0;
        else if(en)
        begin
            register_pc <= pc_next;
        end
    end

    endmodule
