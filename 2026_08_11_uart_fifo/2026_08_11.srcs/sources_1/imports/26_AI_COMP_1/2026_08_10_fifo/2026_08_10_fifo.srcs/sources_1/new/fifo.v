`timescale 1ns / 1ps

module fifo (

    input push,
    input pop,
    input clk,
    input reset,
    input [7:0] w_data,
    output [7:0] r_data,
    output empty,
    output full
);

    wire [1:0] w_wptr, w_rptr;


    register_file #(
        .WIDTH(2),
        .BITWIDTH(8)
    ) U_REGISTER_FILE (
        .clk(clk),
        .waddr(w_wptr),
        .raddr(w_rptr),
        .we(push & ~full),
        .w_data(w_data),
        .r_data(r_data)
    );

    control_unit #(
        .WIDTH(2)
    ) U_CONTROL_UNIT (
        .clk  (clk),
        .reset(reset),
        .push (push),
        .pop  (pop),
        .wptr (w_wptr),
        .rptr (w_rptr),
        .full (full),
        .empty(empty)
    );
endmodule

module register_file #(
    parameter WIDTH = 2,
    BITWIDTH = 8
) (
    input clk,
    input [(WIDTH-1):0] waddr,
    input [(WIDTH-1):0] raddr,
    input we,
    input [(BITWIDTH-1):0] w_data,
    output [(BITWIDTH-1):0] r_data
);
    parameter DEPTH = 2 ** WIDTH;
    reg [7:0] register_file[0:DEPTH-1];


    always @(posedge clk) begin
        if (we) register_file[waddr] = w_data;
    end



    assign r_data = register_file[raddr];
endmodule



module control_unit #(
    parameter WIDTH = 2
) (
    input clk,
    input reset,
    input push,
    input pop,
    output [WIDTH-1:0] wptr,
    output [WIDTH-1:0] rptr,
    output full,
    output empty

);
    reg [WIDTH-1:0] wptr_reg, wptr_next;
    reg [WIDTH-1:0] rptr_reg, rptr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            wptr_reg <= 0;
            rptr_reg <= 0;
            empty_reg = 1;
            full_reg  = 0;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            empty_reg <= empty_next;
            full_reg  <= full_next;
        end

    end



    always @(*) begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        empty_next = empty_reg;
        full_next  = full_reg;

        case ({
            push, pop
        })
            2'b00: begin

            end
            2'b01: begin
                //pop
                if (!empty) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 0;
                    if (wptr_reg == rptr_next) empty_next = 1;
                end
            end
            2'b10: begin
                //push only
                if (!full) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 0;
                    if (wptr_next == rptr_reg) full_next = 1;
                end
            end
            2'b11: begin
                if (full) begin
                    rptr_next = rptr + 1;
                    full_next = 0;
                end else if (empty) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase


    end

endmodule
