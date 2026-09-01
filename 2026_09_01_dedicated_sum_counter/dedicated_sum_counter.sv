`timescale 1ns / 1ps

//=============================================================================
//  dedicated CPU : 1 + 2 + 3 + ... + 10 = 55
//
//  S0 : a = 0, sum = 0
//  S1 : while (a < 10) {
//  S2 :     a   = a + 1
//  S3 :     sum = sum + a
//       }
//  S4 : out = sum   (halt)
//=============================================================================

module dedicated_sum_counter (
    input  logic       clk,
    input  logic       rst_n,
    output logic [7:0] out
);

    // control unit <-> datapath
    logic A_srcSel, A_Load;
    logic Sum_srcSel, Sum_Load;
    logic ALU_srcSel, out_Control;
    logic A_lt10;  // a < 10 이면 1

    control_unit U_CU (
        .clk        (clk),
        .rst_n      (rst_n),
        .lt10       (A_lt10),
        .A_srcSel   (A_srcSel),
        .A_Load     (A_Load),
        .Sum_srcSel (Sum_srcSel),
        .Sum_Load   (Sum_Load),
        .ALU_srcSel (ALU_srcSel),
        .out_Control(out_Control)
    );

    datapath U_DP (
        .clk        (clk),
        .rst_n      (rst_n),
        .A_srcSel   (A_srcSel),
        .A_Load     (A_Load),
        .Sum_srcSel (Sum_srcSel),
        .Sum_Load   (Sum_Load),
        .ALU_srcSel (ALU_srcSel),
        .out_Control(out_Control),
        .A_lt10     (A_lt10),
        .out        (out)
    );

endmodule


//-----------------------------------------------------------------------------
//  control unit : 5 state Moore FSM
//-----------------------------------------------------------------------------
module control_unit (
    input  logic clk,
    input  logic rst_n,
    input  logic lt10,
    output logic A_srcSel,
    output logic A_Load,
    output logic Sum_srcSel,
    output logic Sum_Load,
    output logic ALU_srcSel,
    output logic out_Control
);

    typedef enum logic [2:0] {
        S0,  // a = 0, sum = 0
        S1,  // while (a < 10)
        S2,  // a   = a + 1
        S3,  // sum = sum + a
        S4   // out = sum, halt
    } state_e;

    state_e state, next;

    // state register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) state <= S0;
        else state <= next;
    end

    // next state logic
    always_comb begin
        next = state;
        case (state)
            S0: next = S1;
            S1: next = lt10 ? S2 : S4;  // a < 10 이면 loop, 아니면 종료
            S2: next = S3;
            S3: next = S1;
            S4: next = S4;  // halt
            default: next = S0;
        endcase
    end

    // output logic (truth table)
    //         A_srcSel Sum_srcSel A_Load Sum_Load ALU_srcSel out_Control
    //  S0 :      0          0        1       1         x          0
    //  S1 :      x          x        0       0         x          0
    //  S2 :      1          x        1       0         0          0
    //  S3 :      x          1        0       1         1          0
    //  S4 :      x          x        0       0         x          1
    always_comb begin
        // don't care 는 latch 방지를 위해 default 0 으로 깔아둔다
        A_srcSel    = 1'b0;
        Sum_srcSel  = 1'b0;
        A_Load      = 1'b0;
        Sum_Load    = 1'b0;
        ALU_srcSel  = 1'b0;
        out_Control = 1'b0;
        case (state)
            S0: begin  // a <= 0, sum <= 0
                A_srcSel   = 1'b0;  // 상수 0 선택
                Sum_srcSel = 1'b0;  // 상수 0 선택
                A_Load     = 1'b1;
                Sum_Load   = 1'b1;
            end
            S1: begin  // 비교만 한다. register write 없음
            end
            S2: begin  // a <= a + 1
                A_srcSel   = 1'b1;  // ALU 결과 선택
                A_Load     = 1'b1;
                ALU_srcSel = 1'b0;  // ALU B 입력 = 상수 1
            end
            S3: begin  // sum <= sum + a
                Sum_srcSel = 1'b1;  // ALU 결과 선택
                Sum_Load   = 1'b1;
                ALU_srcSel = 1'b1;  // ALU B 입력 = reg_Sum
            end
            S4: begin  // out = sum
                out_Control = 1'b1;
            end
        endcase
    end

endmodule


//-----------------------------------------------------------------------------
//  datapath : reg_A, reg_Sum, mux 3개, ALU, lt10 비교기, out buffer
//-----------------------------------------------------------------------------
module datapath (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       A_srcSel,
    input  logic       A_Load,
    input  logic       Sum_srcSel,
    input  logic       Sum_Load,
    input  logic       ALU_srcSel,
    input  logic       out_Control,
    output logic       A_lt10,
    output logic [7:0] out
);

    logic [7:0] A_srcMuxOut, Sum_srcMuxOut, ALU_srcMuxOut;
    logic [7:0] regA_q, regSum_q, alu_y;

    // ---- A 쪽 : 0 또는 ALU 결과 -------------------------------------------
    mux_2x1 U_A_srcMux (
        .sel(A_srcSel),
        .d0 (8'd0),
        .d1 (alu_y),
        .y  (A_srcMuxOut)
    );

    cpu_reg U_reg_A (
        .clk  (clk),
        .rst_n(rst_n),
        .load (A_Load),
        .d    (A_srcMuxOut),
        .q    (regA_q)
    );

    lt10 U_lt10 (
        .data(regA_q),
        .out (A_lt10)
    );

    // ---- Sum 쪽 : 0 또는 ALU 결과 -----------------------------------------
    mux_2x1 U_Sum_srcMux (
        .sel(Sum_srcSel),
        .d0 (8'd0),
        .d1 (alu_y),
        .y  (Sum_srcMuxOut)
    );

    cpu_reg U_reg_Sum (
        .clk  (clk),
        .rst_n(rst_n),
        .load (Sum_Load),
        .d    (Sum_srcMuxOut),
        .q    (regSum_q)
    );

    // ---- ALU : A + (1 또는 Sum) -------------------------------------------
    mux_2x1 U_ALU_srcMux (
        .sel(ALU_srcSel),
        .d0 (8'd1),      // a = a + 1
        .d1 (regSum_q),  // sum = sum + a
        .y  (ALU_srcMuxOut)
    );

    cpu_alu U_ALU (
        .a(regA_q),
        .b(ALU_srcMuxOut),
        .y(alu_y)
    );

    // ---- out buffer -------------------------------------------------------
    assign out = out_Control ? regSum_q : 8'd0;

endmodule


//-----------------------------------------------------------------------------
//  8bit 2x1 mux
//-----------------------------------------------------------------------------
module mux_2x1 (
    input  logic       sel,
    input  logic [7:0] d0,
    input  logic [7:0] d1,
    output logic [7:0] y
);

    always_comb begin
        case (sel)
            1'b0: y = d0;
            1'b1: y = d1;
        endcase
    end

endmodule


//-----------------------------------------------------------------------------
//  load enable 이 있는 8bit register
//-----------------------------------------------------------------------------
module cpu_reg (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       load,
    input  logic [7:0] d,
    output logic [7:0] q
);

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) q <= 8'd0;
        else if (load) q <= d;  // load 가 0 이면 현재 값 유지
    end

endmodule


//-----------------------------------------------------------------------------
//  비교기 : data <  10 이면 out = 1  -> control unit S1 -> S2 (loop 계속)
//           data >= 10 이면 out = 0  -> control unit S1 -> S4 (종료)
//-----------------------------------------------------------------------------
module lt10 (
    input  logic [7:0] data,
    output logic       out
);

    assign out = (data < 8'd10);

endmodule


//-----------------------------------------------------------------------------
//  ALU : 덧셈만 수행
//-----------------------------------------------------------------------------
module cpu_alu (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] y
);

    always_comb begin
        y = a + b;
    end

endmodule
