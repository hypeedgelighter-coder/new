`timescale 1ns / 1ps



module compare (
    input logic [2:0] comp_controller,
    input logic [31:0] rs1,
    input logic [31:0] rs2,
    output logic b_type_sel

);

    always_comb begin
        case (comp_controller)
            3'b000:
            if (rs1 == rs2) begin
                b_type_sel = 1'b1;
            end else b_type_sel = 1'b0;
            3'b001:
            if (rs1 != rs2) begin
                b_type_sel = 1'b1;
            end else b_type_sel = 1'b0;
            3'b100:
            if (rs1 < rs2) begin
                b_type_sel = 1'b1;
            end else b_type_sel = 1'b0;
            3'b101:
            if (rs1 >= rs2) begin
                b_type_sel = 1'b1;
            end else b_type_sel = 1'b0;
            3'b110:
            if (rs1 < rs2) begin
                b_type_sel = 1'b1;
            end else b_type_sel = 1'b0;
            3'b111:
            if (rs1 >= rs2) begin
                b_type_sel = 1'b1;
            end else b_type_sel = 1'b0;

        endcase
    end
endmodule
