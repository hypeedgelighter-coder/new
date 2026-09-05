`timescale 1ns / 1ps

//=====================================================================
// FIFO : register file + read/write pointer controller
//   - DEPTH word 를 저장하는 동기식 FIFO
//   - rdata 는 조합 출력(FWFT) : 비어있지 않으면 항상 head 값을 보여준다
//   - full / empty 를 외부로 출력한다 (원본에는 없어서 검증이 불가능했음)
//=====================================================================
module fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  push,
    input  logic                  pop,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  full,
    output logic                  empty
);
    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic [ADDR_WIDTH-1:0] waddr, raddr;
    logic                  wr_en;

    // [FIX] full 일 때는 쓰지 않는다.
    //       원본 reg_file 은 매 clk 마다 무조건 write 해서 데이터가 깨졌다.
    assign wr_en = push & ~full;

    reg_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
    ) U_REG_FILE (
        .clk  (clk),
        .wr_en(wr_en),
        .wdata(wdata),
        .waddr(waddr),
        .raddr(raddr),
        .rdata(rdata)
    );

    // [FIX] register_contorller -> register_controller (오타)
    register_controller #(
        .DEPTH(DEPTH)
    ) U_REG_CONTROLLER (
        .clk  (clk),
        .rst_n(rst_n),
        .push (push),
        .pop  (pop),
        .waddr(waddr),
        .raddr(raddr),
        .full (full),
        .empty(empty)
    );

endmodule


//---------------------------------------------------------------------
// register file : 동기 write / 비동기 read
//---------------------------------------------------------------------
module reg_file #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 32
) (
    input  logic                    clk,
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [$clog2(DEPTH)-1:0] waddr,
    input  logic [$clog2(DEPTH)-1:0] raddr,
    output logic [DATA_WIDTH-1:0]   rdata
);
    logic [DATA_WIDTH-1:0] register_file[0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (wr_en) begin           // [FIX] wr_en 조건 추가
            register_file[waddr] <= wdata;
        end
    end

    assign rdata = register_file[raddr];

endmodule


//---------------------------------------------------------------------
// pointer controller
//   [FIX] full / empty 를 조합 변수로 두면 매 평가마다 값이 날아가고
//         latch 가 추론된다. 반드시 flip-flop(상태)으로 유지해야 한다.
//---------------------------------------------------------------------
module register_controller #(
    parameter int DEPTH = 32
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     push,
    input  logic                     pop,
    output logic [$clog2(DEPTH)-1:0] waddr,
    output logic [$clog2(DEPTH)-1:0] raddr,
    output logic                     full,
    output logic                     empty
);
    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic [ADDR_WIDTH-1:0] c_waddr, n_waddr;
    logic [ADDR_WIDTH-1:0] c_raddr, n_raddr;
    logic                  c_full, n_full;
    logic                  c_empty, n_empty;

    assign waddr = c_waddr;
    assign raddr = c_raddr;
    assign full  = c_full;
    assign empty = c_empty;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            c_waddr <= '0;
            c_raddr <= '0;
            c_full  <= 1'b0;
            c_empty <= 1'b1;   // [FIX] reset 직후는 empty = 1 (원본은 X 였음)
        end else begin
            c_waddr <= n_waddr;
            c_raddr <= n_raddr;
            c_full  <= n_full;
            c_empty <= n_empty;
        end
    end

    always_comb begin
        // 기본값 = 현재 상태 유지
        n_waddr = c_waddr;
        n_raddr = c_raddr;
        n_full  = c_full;
        n_empty = c_empty;

        case ({push, pop})
            2'b10: begin  // push only
                if (!c_full) begin
                    n_waddr = c_waddr + 1'b1;
                    n_empty = 1'b0;
                    if (n_waddr == c_raddr) n_full = 1'b1;
                end
            end

            2'b01: begin  // pop only
                if (!c_empty) begin
                    n_raddr = c_raddr + 1'b1;
                    n_full  = 1'b0;
                    if (n_raddr == c_waddr) n_empty = 1'b1;
                end
            end

            2'b11: begin  // push & pop
                if (c_empty) begin          // 읽을 데이터가 없으니 push 만
                    n_waddr = c_waddr + 1'b1;
                    n_empty = 1'b0;
                    if (n_waddr == c_raddr) n_full = 1'b1;
                end else if (c_full) begin  // 넣을 자리가 없으니 pop 만
                    n_raddr = c_raddr + 1'b1;
                    n_full  = 1'b0;
                    if (n_raddr == c_waddr) n_empty = 1'b1;
                end else begin              // 둘 다 수행, 점유량은 그대로
                    n_waddr = c_waddr + 1'b1;  // [FIX] 원본은 c_raddr + 1 이었음
                    n_raddr = c_raddr + 1'b1;
                end
            end

            default: ;  // 2'b00 : idle
        endcase
    end

endmodule
