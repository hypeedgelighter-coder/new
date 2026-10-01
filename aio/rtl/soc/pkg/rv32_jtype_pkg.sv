// =============================================================================
// rv32_jtype_pkg : J-type (JAL 110_1111) + JL-type (JALR 110_0111)
//   JAL  : rd = PC+4;  PC = PC  + imm   (imm 은 J 포맷)
//   JALR : rd = PC+4;  PC = rs1 + imm   (imm 은 I 포맷 -> rv32_itype_pkg::imm_i)
//   둘 다 2byte 단위라 목적지의 최하위 비트는 0 이다.
// =============================================================================
package rv32_jtype_pkg;

    import rv32_common_pkg::*;

    // ---------------- immediate (JAL) ----------------
    // imm[20|10:1|11|19:12] 로 흩어져 있다. 최하위 비트는 항상 0
    //  12bit + 8bit + 1bit + 10bit + 1bit
    function automatic logic [31:0] imm_j(input logic [31:0] instr);
        return {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
    endfunction

    // ---------------- JALR 목적지 ----------------
    // ALU 가 계산한 rs1 + imm 에서 최하위 비트를 0 으로 떨어뜨린다 (스펙)
    function automatic logic [31:0] jalr_target(input logic [31:0] alu_result);
        return {alu_result[31:1], 1'b0};
    endfunction

endpackage
