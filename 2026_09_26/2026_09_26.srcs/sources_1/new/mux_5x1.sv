module mux_5x1 (
    input logic [2:0] mux_sel_pc,
    input logic b_type_sel,
    input logic [31:0] instr_code_addr_basic,
    input logic [31:0] instr_code_addr_btype,
    input logic [31:0] instr_code_addr_imm,
    input logic [31:0] instr_code_addr_jtype,
    input logic [31:0] instr_code_addr_utype,
    output logic [31:0] c
);

    always_comb begin
        case (mux_sel_pc)
            3'b000: c = instr_code_addr_basic;
            3'b001:
            if (b_type_sel) begin
                c = instr_code_addr_btype;
            end else c = instr_code_addr_basic;
            3'b010: c = instr_code_addr_imm;
            3'b011: c = instr_code_addr_jtype;
            3'b100: c = instr_code_addr_utype;
        endcase
    end
endmodule
