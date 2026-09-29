`timescale 1ns / 1ps


module control_unit (
    input logic [31:0] instr_code,
    output logic [4:0] instr_code_rs1,
    output logic [4:0] instr_code_rs2,
    output logic [4:0] instr_code_rd,
    output logic [3:0] alu_controller,
    output logic [11:0] instr_code_imm,
    output logic [19:0] instr_code_imm_long,
    output logic alu_src_sel,
    output logic [2:0] comp_controller,
    output logic [2:0] strb,
    output logic [2:0] mux_sel_pc,
    output logic mem,
    output logic wb
);

    logic [6:0] op_code;
    assign op_code = instr_code[6:0];

    always_comb begin
        case (op_code)
            7'b011_0011: begin  //RTYPE
                instr_code_rs1 = instr_code[19:15];
                instr_code_rs2 = instr_code[24:20];
                instr_code_rd = instr_code[11:7];
                alu_controller = {instr_code[30], instr_code[14:12]};
                alu_src_sel = 1'b0;
                mem = 1'b0;
                mux_sel_pc = 3'b000;
                wb=1'b1;
            end
            7'b110_0011: begin  //BTYPE
                instr_code_rs1 = instr_code[19:15];
                instr_code_rs2 = instr_code[24:20];
                instr_code_imm = {
                    instr_code[31],
                    instr_code[7],
                    instr_code[30:25],
                    instr_code[11:8]
                };
                comp_controller = instr_code[14:12];
                mem = 1'b0;
                mux_sel_pc = 3'b001;
                wb=1'b0;
            end
            7'b010_0011: begin  //STYPE
                instr_code_rs1 = instr_code[19:15];
                instr_code_rs2 = instr_code[24:20];
                instr_code_imm = {instr_code[31:25], instr_code[11:7]};
                strb = instr_code[14:12];
                mem = 1'b1;
                mux_sel_pc = 3'b010;
            end
            7'b000_0011: begin  //ILTYPE
                instr_code_rs1 = instr_code[19:15];
                instr_code_imm = {instr_code[31:0]};
                strb = instr_code[14:12];
                mem = 1'b1;
                mux_sel_pc = 3'b010;
            end
            7'b001_0011: begin  //ITYPE
                if (instr_code[14:12] == !(3'b101 | 3'b001)) begin
                    alu_controller = {1'b0, instr_code[14:12]};
                    instr_code_imm = instr_code[31:20];
                    instr_code_rs1 = instr_code[19:15];
                    instr_code_rd = instr_code[11:7];
                    alu_src_sel = 1'b1;
                    mem = 1'b0;
                    mux_sel_pc = 3'b010;
                end else begin
                    alu_controller = {instr_code[30], instr_code[14:12]};
                    instr_code_rs1 = instr_code[19:15];
                    instr_code_rs2 = instr_code[24:20];
                    instr_code_rd = instr_code[11:7];
                    alu_src_sel = 1'b1;
                    mem = 1'b0;
                    mux_sel_pc = 3'b010;
                end
            end
            7'b011_0111: begin  //LUITYPE
                instr_code_imm_long = {instr_code[31:12]};
                instr_code_rd = instr_code[11:7];
                mem = 1'b0;
                mux_sel_pc = 3'b011;
            end
            7'b001_0111: begin  //AUIPCTYPE
                instr_code_imm_long = {instr_code[31:12]};
                instr_code_rd = instr_code[11:7];
                mem = 1'b0;
                mux_sel_pc = 3'b011;
            end
            7'b110_1111: begin  //JALTYPE
                instr_code_imm_long = {
                    instr_code[31],
                    instr_code[19:12],
                    instr_code[20],
                    instr_code[30:21]
                };
                instr_code_rd = instr_code[11:7];
                mem = 1'b0;
                mux_sel_pc = 3'b100;
            end
        endcase
    end

endmodule
