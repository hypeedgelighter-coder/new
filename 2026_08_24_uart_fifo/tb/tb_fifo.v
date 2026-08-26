`timescale 1ns / 1ps

//=====================================================================
// tb_fifo  -  fifo 단독 무작위 테스트벤치
//
//  대상 : fifo.v 의 fifo (register_file + fifo_control_unit 포함)
//
//  [무작위로 만드는 것]
//    매 클럭 push / pop / w_data 를 무작위로. 둘이 동시에 들어오는 경우,
//    full 인데 push, empty 인데 pop 같은 경계도 저절로 섞여 들어온다.
//    깊이를 8(AWIDTH=3)로 줄여서 full/empty 를 자주 때린다.
//
//  [검사 방법]  테스트벤치가 큐를 하나 따로 들고 매 클럭 비교
//    1) empty / full 플래그가 실제 개수와 맞는가
//    2) empty 가 아니면 r_data 가 큐의 맨 앞 바이트인가
//    3) 넣은 순서대로 나오는가 (순서 뒤바뀜 / 유실 / 중복 없음)
//
//  이 FIFO 가 정한 동시 push+pop 규칙까지 그대로 확인한다.
//    full  일 때 : push 는 버리고 pop 만
//    empty 일 때 : pop 은 무시하고 push 만
//    그 외       : 둘 다 (개수 유지)
//=====================================================================
module tb_fifo ();

    localparam integer AWIDTH  = 3;
    localparam integer DEPTH   = 1 << AWIDTH;
    localparam integer N_CYCLE = 8000;

    reg        clk = 1'b0;
    reg        reset;
    reg        push, pop;
    reg  [7:0] w_data;
    wire [7:0] r_data;
    wire       empty, full;

    // 참조 큐
    reg [7:0] q  [0:DEPTH-1];
    integer   qw, qr, qn;

    // 순서 검증용 : 넣은 순서 / 뺀 순서를 따로 기록
    reg [7:0] wr_log [0:20000];
    reg [7:0] rd_log [0:20000];
    integer   n_wr, n_rd;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on;

    always #5 clk = ~clk;

    fifo #(
        .AWIDTH(AWIDTH),
        .DWIDTH(8)
    ) DUT (
        .clk   (clk),
        .reset (reset),
        .push  (push),
        .pop   (pop),
        .w_data(w_data),
        .r_data(r_data),
        .empty (empty),
        .full  (full)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20) $display("  FAIL [%0t] %0s", $time, tag);
            end
        end
    endtask

    //-----------------------------------------------------------------
    //  매 클럭 : 먼저 지금 상태를 확인하고, 그 다음 이번 엣지의 동작을 반영
    //-----------------------------------------------------------------
    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            chk(empty === (qn == 0),     "empty flag mismatch");
            chk(full  === (qn == DEPTH), "full flag mismatch");
            if (qn != 0) chk(r_data === q[qr], "r_data is not the head");

            case ({push, pop})
                2'b01: begin
                    if (qn != 0) begin
                        rd_log[n_rd] = q[qr];
                        n_rd = n_rd + 1;
                        qr   = (qr + 1) % DEPTH;
                        qn   = qn - 1;
                    end
                end
                2'b10: begin
                    if (qn != DEPTH) begin
                        q[qw] = w_data;
                        wr_log[n_wr] = w_data;
                        n_wr = n_wr + 1;
                        qw   = (qw + 1) % DEPTH;
                        qn   = qn + 1;
                    end
                end
                2'b11: begin
                    if (qn == DEPTH) begin       // full : push 버리고 pop 만
                        rd_log[n_rd] = q[qr];
                        n_rd = n_rd + 1;
                        qr   = (qr + 1) % DEPTH;
                        qn   = qn - 1;
                    end else if (qn == 0) begin  // empty : pop 무시하고 push 만
                        q[qw] = w_data;
                        wr_log[n_wr] = w_data;
                        n_wr = n_wr + 1;
                        qw   = (qw + 1) % DEPTH;
                        qn   = qn + 1;
                    end else begin               // 둘 다 (개수 유지)
                        rd_log[n_rd] = q[qr];
                        n_rd = n_rd + 1;
                        qr   = (qr + 1) % DEPTH;
                        q[qw] = w_data;
                        wr_log[n_wr] = w_data;
                        n_wr = n_wr + 1;
                        qw   = (qw + 1) % DEPTH;
                    end
                end
                default: ;
            endcase
        end
    end

    initial begin
        seed0  = 32'h0F1F0_123;
        seed   = seed0;
        errors = 0;
        checks = 0;
        qw = 0; qr = 0; qn = 0;
        n_wr = 0; n_rd = 0;

        monitor_on = 1'b0;
        reset      = 1'b1;
        push       = 1'b0;
        pop        = 1'b0;
        w_data     = 8'h00;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        chk(empty === 1'b1, "not empty after reset");
        chk(full  === 1'b0, "full after reset");

        //---------------- 무작위 push / pop ----------------
        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            push   = (({$random(seed)} % 2) == 0);
            pop    = (({$random(seed)} % 2) == 0);
            w_data = {$random(seed)} % 256;
        end

        //---------------- 남은 것을 전부 빼서 순서 확인 ----------------
        @(negedge clk);
        push = 1'b0;
        pop  = 1'b1;
        repeat (DEPTH + 4) @(negedge clk);
        pop = 1'b0;
        @(negedge clk);
        monitor_on = 1'b0;

        chk(empty === 1'b1, "not empty after draining");
        chk(n_rd == n_wr,   "written and read counts differ");

        // 넣은 순서와 뺀 순서가 같은지 (유실/중복/뒤바뀜 검사)
        for (i = 0; i < n_rd; i = i + 1)
            chk(rd_log[i] === wr_log[i], "FIFO order broken");

        $display("  pushed=%0d  popped=%0d", n_wr, n_rd);
        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_fifo : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_fifo : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_fifo : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
