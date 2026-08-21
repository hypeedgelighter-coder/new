`timescale 1ns / 1ps

//=====================================================================
// tb_fifo_control_unit  -  fifo_control_unit 단독 무작위 테스트벤치
//
//  대상 : fifo.v 의 fifo_control_unit
//         (FIFO 의 쓰기/읽기 포인터와 full/empty 플래그만 담당)
//
//  [무작위로 만드는 것]
//    매 클럭 push / pop 무작위. 깊이를 8 로 줄여서 full/empty 경계를
//    자주 밟게 한다.
//
//  [검사 방법]
//    테스트벤치가 개수(count)만 따로 세는 참조 모델을 들고,
//    매 클럭 wptr / rptr / full / empty 네 개를 전부 비교한다.
//
//    포인터는 "몇 번 올라갔는지"로 예측한다. 랩어라운드까지 포함해서
//    개수와 포인터가 어긋나면 (예: full 인데 push 를 먹어서 포인터가
//    한 바퀴 돌아 empty 로 보이는 고전적 버그) 바로 잡힌다.
//=====================================================================
module tb_fifo_control_unit ();

    localparam integer AWIDTH  = 3;
    localparam integer DEPTH   = 1 << AWIDTH;
    localparam integer N_CYCLE = 8000;

    reg               clk = 1'b0;
    reg               reset;
    reg               push, pop;
    wire [AWIDTH-1:0] wptr, rptr;
    wire              full, empty;

    integer gw, gr, gn;  // 참조 모델 : 쓰기 포인터 / 읽기 포인터 / 개수

    integer seed, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on;

    always #5 clk = ~clk;

    fifo_control_unit #(
        .AWIDTH(AWIDTH)
    ) DUT (
        .clk  (clk),
        .reset(reset),
        .push (push),
        .pop  (pop),
        .wptr (wptr),
        .rptr (rptr),
        .full (full),
        .empty(empty)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  (wptr=%0d/%0d rptr=%0d/%0d n=%0d f=%b e=%b)",
                             $time, tag, wptr, gw, rptr, gr, gn, full, empty);
            end
        end
    endtask

    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            chk(wptr  === gw[AWIDTH-1:0], "wptr mismatch");
            chk(rptr  === gr[AWIDTH-1:0], "rptr mismatch");
            chk(full  === (gn == DEPTH),  "full flag mismatch");
            chk(empty === (gn == 0),      "empty flag mismatch");

            case ({push, pop})
                2'b01: if (gn != 0)     begin gr = (gr + 1) % DEPTH; gn = gn - 1; end
                2'b10: if (gn != DEPTH) begin gw = (gw + 1) % DEPTH; gn = gn + 1; end
                2'b11: begin
                    if (gn == DEPTH)     begin gr = (gr + 1) % DEPTH; gn = gn - 1; end
                    else if (gn == 0)    begin gw = (gw + 1) % DEPTH; gn = gn + 1; end
                    else begin
                        gw = (gw + 1) % DEPTH;
                        gr = (gr + 1) % DEPTH;
                    end
                end
                default: ;
            endcase
        end
    end

    initial begin
        seed0  = 32'h3141_5926;
        seed   = seed0;
        errors = 0;
        checks = 0;
        gw = 0; gr = 0; gn = 0;

        monitor_on = 1'b0;
        reset      = 1'b1;
        push       = 1'b0;
        pop        = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        //---------------- 1) 무작위 push / pop ----------------
        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            push = (({$random(seed)} % 2) == 0);
            pop  = (({$random(seed)} % 2) == 0);
        end

        //---------------- 2) 꽉 채우고 넘겨 보기 ----------------
        @(negedge clk);
        push = 1'b0; pop = 1'b1;
        repeat (DEPTH + 4) @(negedge clk);   // 일단 다 비우고
        push = 1'b1; pop = 1'b0;
        repeat (DEPTH + 6) @(negedge clk);   // 깊이보다 많이 넣는다
        chk(full === 1'b1, "not full after overfill");
        push = 1'b0; pop = 1'b1;
        repeat (DEPTH + 6) @(negedge clk);   // 깊이보다 많이 뺀다
        chk(empty === 1'b1, "not empty after overdrain");
        push = 1'b0; pop = 1'b0;
        @(negedge clk);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_fifo_control_unit : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_fifo_control_unit : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_fifo_control_unit : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
