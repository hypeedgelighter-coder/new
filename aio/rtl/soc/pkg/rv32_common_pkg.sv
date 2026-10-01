// =============================================================================
// rv32_common_pkg : 명령어 타입에 걸치지 않는 공통 정의
//   - opcode  : instr[6:0]
//   - ALU control : {funct7[5], funct3}
//   - RFWdSrcSel  : Register File 에 써 넣을 값 선택
// =============================================================================
package rv32_common_pkg;

// ---------------- OPCODE : instr[6:0] ----------------
typedef enum logic [6:0]{
    OP_RTYPE  = 7'b011_0011,    // R-type  : ADD, SUB, SLL, SLT, ...
    OP_STYPE  = 7'b010_0011,    // S-type  : SB, SH, SW
    OP_ITYPE  = 7'b001_0011,    // I-type  : ADDI, SLTI, XORI, ...
    OP_ILTYPE = 7'b000_0011,    // IL-type : LB, LH, LW, LBU, LHU
    OP_BTYPE  = 7'b110_0011,    // B-type  : BEQ, BNE, BLT, BGE, BLTU, BGEU
    OP_LUI    = 7'b011_0111,    // U-type  : rd = imm
    OP_AUIPC  = 7'b001_0111,    // U-type  : rd = PC + imm
    OP_JAL    = 7'b110_1111,    // J-type  : rd = PC+4;  PC += imm
    OP_JALR   = 7'b110_0111     // JL-type : rd = PC+4;  PC  = rs1 + imm
    } opcode_e;

// ---------------- ALU control : {funct7[5], funct3} ----------------
typedef enum logic [3:0]{
    ALU_ADD  = 4'b0_000,
    ALU_SUB  = 4'b1_000,
    ALU_SLL  = 4'b0_001,
    ALU_SLT  = 4'b0_010,
    ALU_SLTU = 4'b0_011,
    ALU_XOR  = 4'b0_100,
    ALU_SRL  = 4'b0_101,
    ALU_SRA  = 4'b1_101,
    ALU_OR   = 4'b0_110,
    ALU_AND  = 4'b0_111
    } alu_op_e;

// ---------------- RFWdSrcSel ----------------
// Register File 에 써 넣을 값을 고르는 MUX 의 선택 신호
typedef enum logic [2:0]{
    WB_ALU   = 3'b000,      // R, I  : ALU 결과
    WB_MEM   = 3'b001,      // IL    : Data Memory 읽은 값
    WB_IMM   = 3'b010,      // LUI   : imm 그대로
    WB_PCIMM = 3'b011,      // AUIPC : PC + imm
    WB_PC4   = 3'b100       // JAL, JALR : PC + 4 (복귀 주소)
    } wb_src_e;

endpackage
