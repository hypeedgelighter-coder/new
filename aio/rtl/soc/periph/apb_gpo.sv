// =============================================================================
// apb_gpo : APB Completer (Slave) - 출력 전용 GPIO
//
//   0x00 ODR (RW) : 출력 값. 읽으면 방금 쓴 값이 그대로 돌아온다.
// =============================================================================
module apb_gpo #(
    parameter int WIDTH = 8
)(
    input  logic              clk,
    input  logic              rst_n,

    input  logic              psel,
    input  logic              penable,
    input  logic              pwrite,
    input  logic [31:0]       paddr,
    input  logic [31:0]       pwdata,
    output logic [31:0]       prdata,
    output logic              pready,

    output logic [WIDTH-1:0]  gpo_pin
);

    logic [WIDTH-1:0] odr;
    logic             wr_en;

    assign pready = 1'b1;
    assign wr_en  = psel && penable && pwrite && pready;

    always_ff @(posedge clk)
    begin
        if(!rst_n) odr <= '0;
        else if(wr_en && (paddr[7:0] == 8'h00)) odr <= pwdata[WIDTH-1:0];
    end

    always_comb
    begin
        prdata = 32'h0000_0000;
        case(paddr[7:0])
            8'h00   : prdata = {{(32-WIDTH){1'b0}}, odr};   // ODR
            default : prdata = 32'h0000_0000;
        endcase
    end

    assign gpo_pin = odr;

endmodule
