// =============================================================================
// rv32_stype_pkg : S-type (opcode 010_0011)
//   M[rs1 + imm] = rs2.  rd 가 없어서 imm 이 instr[31:25] 와 instr[11:7] 로 쪼개져 있다.
// =============================================================================
package rv32_stype_pkg;

    import rv32_common_pkg::*;

    // ---------------- Store 크기 funct3 : instr[14:12] ----------------
    typedef enum logic [2:0]{
        SB = 3'b000,    // Store Byte
        SH = 3'b001,    // Store Half Word
        SW = 3'b010     // Store Word
        } store_funct3_e;

    // ---------------- immediate ----------------
    // imm[11:5] = instr[31:25], imm[4:0] = instr[11:7], 부호확장
    function automatic logic [31:0] imm_s(input logic [31:0] instr);
        return {{20{instr[31]}}, instr[31:25], instr[11:7]};
    endfunction

endpackage
