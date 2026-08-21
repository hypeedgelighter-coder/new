// `timescale 1ns / 1ps



// module fifo (
//     input clk,
//     input reset,
//     input [1:0] waddr,
//     input [7:0] wdata,
//     input [1:0] raddr,
//     output [7:0] rdata

// );

//     reg [7:0] register_file[0:3];

//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             register_file <= 0;
//         end else register_file[waddr] <= wdata;
//     end

//     always @(*) begin
//         rdata = register_file[raddr];
//     end
// endmodule

// module  (
//     input clk,
//     input reset,
//     input push,
//     input pop,
//     output [1:0]waddr,
//     output [1:0]raddr
// );

// reg [1:0]waddr_reg,waddr_next;
// reg [1:0]raddr_reg,raddr_next;
// reg full_reg,full_next;
// reg empty_reg,empty_next;

// assign waddr=waddr_reg;
// assign raddr=raddr_reg;

// always @(posedge clk, posedge reset) begin
//     if(reset)begin
//         waddr_reg<=0;
//         raddr_reg<=0;
//         full_reg=0;
//         empty_reg=0;
//     end else begin 
//         waddr_reg<=waddr_next;
//         raddr_reg<=raddr;
//         full_reg<=full_next;
//         empty_reg<=empty_next;
// end
// end

// always @(*) begin
//     waddr_next=waddr_reg;
//     raddr_next=raddr_reg;
//     full_next=full_reg;
//     empty_next=empty_reg;

//     if(~full&push)begin
//         waddr_next=waddr_reg+1;
//         if(waddr_reg==raddr_next)begin
//             full_next=1;
//         end
//     end 
//     if(~empty&pop)begin
//         raddr_next=raddr_reg+1;
//         if(raddr_next=waddr_reg)begin
//             empty_next=1;
//         end
//     end
//     if(~full&push&~empty&pop)begin
//         waddr_next=waddr_reg+1;
//         raddr_next=raddr_reg+1;
//     end
    
// end
    
// endmodule
