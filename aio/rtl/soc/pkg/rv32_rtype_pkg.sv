// =============================================================================
// rv32_rtype_pkg : R-type (opcode 011_0011)
//   rd = rs1 op rs2.  immediate 가 없다.
//   ADD/SUB, SRL/SRA 는 funct3 가 같고 funct7[5] (instr[30]) 로 갈린다.
// =============================================================================
package rv32_rtype_pkg;

    import rv32_common_pkg::*;

    // ---------------- funct3 : instr[14:12] ----------------
    typedef enum logic [2:0]{
        F3_ADD_SUB = 3'b000,
        F3_SLL     = 3'b001,
        F3_SLT     = 3'b010,
        F3_SLTU    = 3'b011,
        F3_XOR     = 3'b100,
        F3_SRL_SRA = 3'b101,
        F3_OR      = 3'b110,
        F3_AND     = 3'b111
        } rtype_funct3_e;

    // ---------------- funct7 : instr[31:25] ----------------
    localparam logic [6:0] FUNCT7_BASE = 7'b000_0000;   // ADD, SRL
    localparam logic [6:0] FUNCT7_ALT  = 7'b010_0000;   // SUB, SRA

    // R-type 은 funct7[5] 를 그대로 alu_control 최상위 비트로 쓴다
    function automatic logic [3:0] alu_ctrl_r(input logic [31:0] instr);
        return {instr[30], instr[14:12]};
    endfunction

endpackage
