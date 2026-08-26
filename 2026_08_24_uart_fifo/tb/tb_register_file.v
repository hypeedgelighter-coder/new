`timescale 1ns / 1ps

//=====================================================================
// tb_register_file  -  register_file 단독 무작위 테스트벤치
//
//  대상 : fifo.v 의 register_file
//
//  FIFO 의 저장소. 쓰기는 클럭 동기, 읽기는 조합(주소를 주면 그 자리에서
//  값이 나온다). reset 이 없어서 쓰기 전 주소는 X 다.
//
//  [무작위로 만드는 것]
//    매 클럭 we / waddr / raddr / w_data 를 전부 무작위로.
//    같은 주소에 쓰면서 동시에 읽는 경우도 저절로 섞인다.
//
//  [검사 방법]
//    테스트벤치가 같은 크기의 배열을 하나 들고 그대로 따라 쓴다.
//    한 번이라도 쓴 적 있는 주소를 읽을 때만 값을 비교한다.
//    같은 클럭에 쓰기+읽기가 겹치면 "쓰기 전 값"이 나와야 한다(조합 읽기).
//=====================================================================
module tb_register_file ();

    localparam integer AWIDTH  = 3;
    localparam integer DEPTH   = 1 << AWIDTH;
    localparam integer N_CYCLE = 4000;

    reg               clk = 1'b0;
    reg  [AWIDTH-1:0] waddr, raddr;
    reg               we;
    reg  [       7:0] w_data;
    wire [       7:0] r_data;

    reg [7:0] gmem   [0:DEPTH-1];
    reg       written[0:DEPTH-1];

    integer seed, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on;

    always #5 clk = ~clk;

    register_file #(
        .AWIDTH(AWIDTH),
        .DWIDTH(8)
    ) DUT (
        .clk   (clk),
        .waddr (waddr),
        .raddr (raddr),
        .we    (we),
        .w_data(w_data),
        .r_data(r_data)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  raddr=%0d r_data=%h exp=%h",
                             $time, tag, raddr, r_data, gmem[raddr]);
            end
        end
    endtask

    always @(posedge clk) begin
        if (monitor_on) begin
            // 엣지 직전값 = 쓰기가 반영되기 전 값
            if (written[raddr]) chk(r_data === gmem[raddr], "read data mismatch");
            if (we) begin
                gmem[waddr]    = w_data;
                written[waddr] = 1'b1;
            end
        end
    end

    initial begin
        seed0  = 32'h2222_9999;
        seed   = seed0;
        errors = 0;
        checks = 0;
        monitor_on = 1'b0;

        for (i = 0; i < DEPTH; i = i + 1) written[i] = 1'b0;

        we = 1'b0; waddr = 0; raddr = 0; w_data = 0;
        @(negedge clk);
        monitor_on = 1'b1;

        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            we     = (({$random(seed)} % 3) != 0);  // 2/3 확률로 쓰기
            waddr  = {$random(seed)} % DEPTH;
            raddr  = {$random(seed)} % DEPTH;
            w_data = {$random(seed)} % 256;
        end
        @(negedge clk);
        we = 1'b0;
        @(negedge clk);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_register_file : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_register_file : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #2_000_000;
        $display("  tb_register_file : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
