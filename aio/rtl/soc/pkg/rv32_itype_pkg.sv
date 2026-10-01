// =============================================================================
// rv32_itype_pkg : I-type (opcode 001_0011) + IL-type (opcode 000_0011)
//   둘 다 imm[11:0] = instr[31:20] 인 같은 immediate 포맷을 쓴다.
//   JALR (110_0111) 도 형식은 I-type 이라 imm_i 를 그대로 쓴다.
// =============================================================================
package rv32_itype_pkg;

    import rv32_common_pkg::*;

    // ---------------- 산술 I-type funct3 : instr[14:12] ----------------
    typedef enum logic [2:0]{
        F3_ADDI      = 3'b000,
        F3_SLLI      = 3'b001,
        F3_SLTI      = 3'b010,
        F3_SLTIU     = 3'b011,
        F3_XORI      = 3'b100,
        F3_SRLI_SRAI = 3'b101,
        F3_ORI       = 3'b110,
        F3_ANDI      = 3'b111
        } itype_funct3_e;

    // ---------------- Load 크기 funct3 (IL-type) ----------------
    typedef enum logic [2:0]{
        LB  = 3'b000,   // 부호확장 byte
        LH  = 3'b001,   // 부호확장 half word
        LW  = 3'b010,   // word
        LBU = 3'b100,   // zero-extends byte
        LHU = 3'b101    // zero-extends half word
        } load_funct3_e;

    // ---------------- immediate ----------------
    // imm[11:0] = instr[31:20], 부호확장
    function automatic logic [31:0] imm_i(input logic [31:0] instr);
        return {{20{instr[31]}}, instr[31:20]};
    endfunction

    // ---------------- ALU control ----------------
    // SRLI / SRAI 만 instr[30] 이 funct7[5] 다.
    // 나머지 I-type 은 instr[30] 이 imm 의 일부라서 그대로 쓰면 안 된다.
    function automatic logic [3:0] alu_ctrl_i(input logic [31:0] instr);
        return (instr[14:12] == F3_SRLI_SRAI) ? {instr[30], instr[14:12]}
                                              : {1'b0,      instr[14:12]};
    endfunction

endpackage
