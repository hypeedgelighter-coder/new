`timescale 1ns / 1ps

//=====================================================================
// FIFO
//
//  [기존 대비 바뀐 점]
//   내부 포인터 제어 모듈 이름이 control_unit 이었다. 다이어그램의
//   최상위 Control Unit 과 이름이 겹쳐서 한 프로젝트에 못 넣는다.
//   -> fifo_control_unit 으로 이름 변경.
//   깊이도 파라미터(AWIDTH)로 뺐다. ASCII Sender 가 한 번에 최대 7바이트
//   (STOPWATCH/WATCH "SS.mm\r\n" / "HH:MM\r\n", DHT11 "HH TT\r\n".
//   SR04 만 "DDD\r\n" 5바이트) 를 밀어넣기 때문에 TX FIFO 는 4단(기존)
//   으로는 계속 full 이 걸린다. full/empty 를 별도 플래그로 두어
//   2**AWIDTH 칸을 전부 쓰므로, 7바이트가 한 번에 들어가는 최소 깊이인
//   8단(AWIDTH=3)으로 쓴다.
//=====================================================================
module fifo #(
    parameter AWIDTH = 3,  // 주소폭 -> 깊이 = 2**AWIDTH
    parameter DWIDTH = 8
) (
    input               clk,
    input               reset,
    input               push,
    input               pop,
    input  [DWIDTH-1:0] w_data,
    output [DWIDTH-1:0] r_data,
    output              empty,
    output              full
);
    wire [AWIDTH-1:0] w_wptr, w_rptr;

    register_file #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH)
    ) U_REGISTER_FILE (
        .clk   (clk),
        .waddr (w_wptr),
        .raddr (w_rptr),
        .we    (push & ~full),
        .w_data(w_data),
        .r_data(r_data)
    );

    fifo_control_unit #(
        .AWIDTH(AWIDTH)
    ) U_FIFO_CONTROL_UNIT (
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
    parameter AWIDTH = 3,
    parameter DWIDTH = 8
) (
    input               clk,
    input  [AWIDTH-1:0] waddr,
    input  [AWIDTH-1:0] raddr,
    input               we,
    input  [DWIDTH-1:0] w_data,
    output [DWIDTH-1:0] r_data
);
    localparam DEPTH = 2 ** AWIDTH;

    reg [DWIDTH-1:0] mem[0:DEPTH-1];

    always @(posedge clk) begin
        if (we) mem[waddr] <= w_data;
    end

    assign r_data = mem[raddr];  // 조합 읽기 -> empty 가 0 이면 head 가 바로 보인다
endmodule


module fifo_control_unit #(
    parameter AWIDTH = 3
) (
    input               clk,
    input               reset,
    input               push,
    input               pop,
    output [AWIDTH-1:0] wptr,
    output [AWIDTH-1:0] rptr,
    output              full,
    output              empty
);
    reg [AWIDTH-1:0] wptr_reg, wptr_next;
    reg [AWIDTH-1:0] rptr_reg, rptr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            empty_reg <= 1'b1;
            full_reg  <= 1'b0;
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

        case ({push, pop})
            2'b00: begin
                // 아무것도 안 함
            end
            2'b01: begin  // pop only
                if (!empty_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                    if (wptr_reg == rptr_next) empty_next = 1'b1;
                end
            end
            2'b10: begin  // push only
                if (!full_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                    if (wptr_next == rptr_reg) full_next = 1'b1;
                end
            end
            2'b11: begin  // push & pop 동시
                if (full_reg) begin
                    // 꽉 찼으면 push 는 버리고 pop 만
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else if (empty_reg) begin
                    // 비었으면 pop 은 무시하고 push 만
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    // 개수 유지 -> empty/full 변화 없음
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end
endmodule
