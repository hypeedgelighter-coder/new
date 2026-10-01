// =============================================================================
// rv32_btype_pkg : B-type (opcode 110_0011)
//   if(rs1 cmp rs2) PC += imm.
//   imm 이 2byte 단위라 최하위 비트가 없고 항상 0 이다.
// =============================================================================
package rv32_btype_pkg;

    import rv32_common_pkg::*;

    // ---------------- 분기 조건 funct3 : instr[14:12] ----------------
    // 010, 011 은 RISC-V 스펙상 비어 있다.
    typedef enum logic [2:0]{
        BEQ  = 3'b000,
        BNE  = 3'b001,
        BLT  = 3'b100,
        BGE  = 3'b101,
        BLTU = 3'b110,  // zero-extends 비교
        BGEU = 3'b111   // zero-extends 비교
        } branch_funct3_e;

    // ---------------- immediate ----------------
    // imm[12|10:5|4:1|11] 로 흩어져 있다. 최하위 비트는 항상 0
    //  20bit + 1bit + 6bit + 4bit + 1bit
    function automatic logic [31:0] imm_b(input logic [31:0] instr);
        return {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    endfunction

endpackage
