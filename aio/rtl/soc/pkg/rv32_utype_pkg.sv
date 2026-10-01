// =============================================================================
// rv32_utype_pkg : U-type (LUI 011_0111 / AUIPC 001_0111)
//   LUI   : rd = imm
//   AUIPC : rd = PC + imm
//   imm[31:12] 만 들고 하위 12bit 는 0 이다. 이미 32bit 라 부호확장이 없다.
// =============================================================================
package rv32_utype_pkg;

    import rv32_common_pkg::*;

    // ---------------- immediate ----------------
    // imm[31:12] = instr[31:12], 하위 12bit 는 0
    function automatic logic [31:0] imm_u(input logic [31:0] instr);
        return {instr[31:12], 12'b0};
    endfunction

endpackage
