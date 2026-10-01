// =============================================================================
// rv32_pkg : 타입별 패키지를 하나로 묶은 통합 패키지
//
//   모듈은 이 파일 하나만 import 하면 된다.
//       module xxx import rv32_pkg::*; ( ... );
//
//   [컴파일 순서]
//   패키지는 참조되기 전에 반드시 먼저 분석돼야 한다. 순서는 Makefile 의
//   PKG_ORDER 가 고정한다 (wildcard 알파벳순은 의존 순서와 맞지 않는다).
//       rv32_common_pkg -> 타입별 6 개 -> rv32_pkg -> 나머지 RTL
//
//   [주의] Vivado 2020.2 는 "export pkg::*;" 를 파싱만 하고 실제로 재노출하지
//   않는다. 그래서 typedef / localparam / function 래퍼로 직접 alias 한다.
// =============================================================================
package rv32_pkg;

    import rv32_common_pkg::*;
    import rv32_rtype_pkg::*;
    import rv32_itype_pkg::*;
    import rv32_stype_pkg::*;
    import rv32_btype_pkg::*;
    import rv32_utype_pkg::*;
    import rv32_jtype_pkg::*;

    // ========================= common =========================
    typedef rv32_common_pkg::opcode_e  opcode_e;
    typedef rv32_common_pkg::alu_op_e  alu_op_e;
    typedef rv32_common_pkg::wb_src_e  wb_src_e;

    localparam opcode_e OP_RTYPE  = rv32_common_pkg::OP_RTYPE;
    localparam opcode_e OP_STYPE  = rv32_common_pkg::OP_STYPE;
    localparam opcode_e OP_ITYPE  = rv32_common_pkg::OP_ITYPE;
    localparam opcode_e OP_ILTYPE = rv32_common_pkg::OP_ILTYPE;
    localparam opcode_e OP_BTYPE  = rv32_common_pkg::OP_BTYPE;
    localparam opcode_e OP_LUI    = rv32_common_pkg::OP_LUI;
    localparam opcode_e OP_AUIPC  = rv32_common_pkg::OP_AUIPC;
    localparam opcode_e OP_JAL    = rv32_common_pkg::OP_JAL;
    localparam opcode_e OP_JALR   = rv32_common_pkg::OP_JALR;

    localparam alu_op_e ALU_ADD   = rv32_common_pkg::ALU_ADD;
    localparam alu_op_e ALU_SUB   = rv32_common_pkg::ALU_SUB;
    localparam alu_op_e ALU_SLL   = rv32_common_pkg::ALU_SLL;
    localparam alu_op_e ALU_SLT   = rv32_common_pkg::ALU_SLT;
    localparam alu_op_e ALU_SLTU  = rv32_common_pkg::ALU_SLTU;
    localparam alu_op_e ALU_XOR   = rv32_common_pkg::ALU_XOR;
    localparam alu_op_e ALU_SRL   = rv32_common_pkg::ALU_SRL;
    localparam alu_op_e ALU_SRA   = rv32_common_pkg::ALU_SRA;
    localparam alu_op_e ALU_OR    = rv32_common_pkg::ALU_OR;
    localparam alu_op_e ALU_AND   = rv32_common_pkg::ALU_AND;

    localparam wb_src_e WB_ALU    = rv32_common_pkg::WB_ALU;
    localparam wb_src_e WB_MEM    = rv32_common_pkg::WB_MEM;
    localparam wb_src_e WB_IMM    = rv32_common_pkg::WB_IMM;
    localparam wb_src_e WB_PCIMM  = rv32_common_pkg::WB_PCIMM;
    localparam wb_src_e WB_PC4    = rv32_common_pkg::WB_PC4;

    // ========================= R-type =========================
    typedef rv32_rtype_pkg::rtype_funct3_e rtype_funct3_e;

    localparam rtype_funct3_e F3_ADD_SUB = rv32_rtype_pkg::F3_ADD_SUB;
    localparam rtype_funct3_e F3_SLL     = rv32_rtype_pkg::F3_SLL;
    localparam rtype_funct3_e F3_SLT     = rv32_rtype_pkg::F3_SLT;
    localparam rtype_funct3_e F3_SLTU    = rv32_rtype_pkg::F3_SLTU;
    localparam rtype_funct3_e F3_XOR     = rv32_rtype_pkg::F3_XOR;
    localparam rtype_funct3_e F3_SRL_SRA = rv32_rtype_pkg::F3_SRL_SRA;
    localparam rtype_funct3_e F3_OR      = rv32_rtype_pkg::F3_OR;
    localparam rtype_funct3_e F3_AND     = rv32_rtype_pkg::F3_AND;

    localparam logic [6:0] FUNCT7_BASE = rv32_rtype_pkg::FUNCT7_BASE;
    localparam logic [6:0] FUNCT7_ALT  = rv32_rtype_pkg::FUNCT7_ALT;

    function automatic logic [3:0] alu_ctrl_r(input logic [31:0] instr);
        return rv32_rtype_pkg::alu_ctrl_r(instr);
    endfunction

    // ========================= I-type / IL-type =========================
    typedef rv32_itype_pkg::itype_funct3_e itype_funct3_e;
    typedef rv32_itype_pkg::load_funct3_e  load_funct3_e;

    localparam itype_funct3_e F3_ADDI      = rv32_itype_pkg::F3_ADDI;
    localparam itype_funct3_e F3_SLLI      = rv32_itype_pkg::F3_SLLI;
    localparam itype_funct3_e F3_SLTI      = rv32_itype_pkg::F3_SLTI;
    localparam itype_funct3_e F3_SLTIU     = rv32_itype_pkg::F3_SLTIU;
    localparam itype_funct3_e F3_XORI      = rv32_itype_pkg::F3_XORI;
    localparam itype_funct3_e F3_SRLI_SRAI = rv32_itype_pkg::F3_SRLI_SRAI;
    localparam itype_funct3_e F3_ORI       = rv32_itype_pkg::F3_ORI;
    localparam itype_funct3_e F3_ANDI      = rv32_itype_pkg::F3_ANDI;

    localparam load_funct3_e LB  = rv32_itype_pkg::LB;
    localparam load_funct3_e LH  = rv32_itype_pkg::LH;
    localparam load_funct3_e LW  = rv32_itype_pkg::LW;
    localparam load_funct3_e LBU = rv32_itype_pkg::LBU;
    localparam load_funct3_e LHU = rv32_itype_pkg::LHU;

    function automatic logic [31:0] imm_i(input logic [31:0] instr);
        return rv32_itype_pkg::imm_i(instr);
    endfunction

    function automatic logic [3:0] alu_ctrl_i(input logic [31:0] instr);
        return rv32_itype_pkg::alu_ctrl_i(instr);
    endfunction

    // ========================= S-type =========================
    typedef rv32_stype_pkg::store_funct3_e store_funct3_e;

    localparam store_funct3_e SB = rv32_stype_pkg::SB;
    localparam store_funct3_e SH = rv32_stype_pkg::SH;
    localparam store_funct3_e SW = rv32_stype_pkg::SW;

    function automatic logic [31:0] imm_s(input logic [31:0] instr);
        return rv32_stype_pkg::imm_s(instr);
    endfunction

    // ========================= B-type =========================
    typedef rv32_btype_pkg::branch_funct3_e branch_funct3_e;

    localparam branch_funct3_e BEQ  = rv32_btype_pkg::BEQ;
    localparam branch_funct3_e BNE  = rv32_btype_pkg::BNE;
    localparam branch_funct3_e BLT  = rv32_btype_pkg::BLT;
    localparam branch_funct3_e BGE  = rv32_btype_pkg::BGE;
    localparam branch_funct3_e BLTU = rv32_btype_pkg::BLTU;
    localparam branch_funct3_e BGEU = rv32_btype_pkg::BGEU;

    function automatic logic [31:0] imm_b(input logic [31:0] instr);
        return rv32_btype_pkg::imm_b(instr);
    endfunction

    // ========================= U-type =========================
    function automatic logic [31:0] imm_u(input logic [31:0] instr);
        return rv32_utype_pkg::imm_u(instr);
    endfunction

    // ========================= J-type / JL-type =========================
    function automatic logic [31:0] imm_j(input logic [31:0] instr);
        return rv32_jtype_pkg::imm_j(instr);
    endfunction

    function automatic logic [31:0] jalr_target(input logic [31:0] alu_result);
        return rv32_jtype_pkg::jalr_target(alu_result);
    endfunction

endpackage
