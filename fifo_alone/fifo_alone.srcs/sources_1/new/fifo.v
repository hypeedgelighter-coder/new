`timescale 1ns / 1ps


module fifo (
    input clk,
    input reset,
    input [7:0] wdata,
    input pop,
    input push,
    output [7:0] rdata,
    output full,
    output empty

);
    wire [1:0] w_waddr, w_raddr;


    fifo_register U_FIFO_REGISTER (
        .clk  (clk),
        .reset(reset),
        .waddr(w_waddr),
        .raddr(w_raddr),
        .wdata(wdata),
        .rdata(rdata)
    );

    fifo_controller U_FIFO_CONTROLLER (
        .clk  (clk),
        .reset(reset),
        .push (push),
        .pop  (pop),
        .waddr(w_waddr),
        .raddr(w_raddr),
        .full (full),
        .empty(empty)

    );


endmodule

module fifo_register (
    input clk,
    input reset,
    input [1:0] waddr,
    input [1:0] raddr,
    input [7:0] wdata,
    output reg [7:0] rdata
);

    reg [7:0] register_file[0:3];


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            register_file <= 0;
        end else begin
            register_file[waddr] <= wdata;
            rdata <= register_file[raddr];
        end

    end


endmodule

module fifo_controller (
    input clk,
    input reset,
    input push,
    input pop,
    output [1:0] waddr,
    output [1:0] raddr,
    output full,
    output empty

);
    reg [1:0] waddr_reg, waddr_next;
    reg [1:0] raddr_reg, raddr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;

    assign full  = full_reg;
    assign empty = empty_reg;
    assign waddr = waddr_reg;
    assign raddr = raddr_reg;


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            waddr_reg <= 0;
            raddr_reg <= 0;
            full_reg  <= 0;
            empty_reg <= 0;
        end else begin
            waddr_reg <= waddr_next;
            raddr_reg <= raddr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always @(*) begin
        waddr_next = waddr_reg;
        raddr_next = raddr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        if (push & ~full_reg) begin
            waddr_next = waddr_reg + 1;
            empty_next = 0;
            if (waddr_next == raddr_reg) full_next = 1;
        end
        if (pop & ~empty) begin
            raddr_next = raddr_reg + 1;
            full_next  = 0;
            if (raddr_next == waddr_reg) empty_next = 1;
        end
        if (push & pop & ~full_reg & ~empty_reg) begin
            waddr_next = waddr_reg + 1;
            raddr_next = raddr_reg + 1;
            full_next  = 0;
            empty_next = 0;
        end

    end

endmodule
