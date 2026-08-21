`timescale 1ns / 1ps

//=====================================================================
// tb_fnd_controller  -  fnd_controller 단독 무작위 테스트벤치
//
//  대상 : fnd_controller.v 의 fnd_controller
//         (fnd_scan_tick + counter_4 + decoder_2x4 + mux_4x1 + seg_decoder)
//
//  4자리 digit 과 dot 을 받아 자리를 빠르게 번갈아 켜는 다이나믹 스캔.
//  시뮬에서는 SCAN_COUNT=4 로 줄여 자리당 4클럭.
//
//  [무작위로 만드는 것]
//    digit 4개와 dot_on 을 무작위 값으로, 무작위 간격(1~20클럭)마다 바꾼다.
//    자리가 바뀌는 도중에 값이 바뀌는 상황까지 자연스럽게 섞인다.
//
//  [검사 방법]  매 클럭 다음 세 가지를 본다
//    1) fnd_com 이 정확히 한 자리만 0 (액티브 로우) 인가
//    2) 그 자리에 해당하는 digit 의 세그먼트 코드가 fnd_data 로 나오는가
//    3) dp(비트7) : dot_on 이고 100의 자리일 때만 0(점등) 인가
//       -> 예전에 mux_8x1 의 sel 폭이 모자라 dot 이 잘려나갔던 버그가
//          여기서 잡힌다
//    4) 자리 스캔이 SCAN_COUNT 클럭마다 0->1->2->3->0 순서로 도는가
//=====================================================================
module tb_fnd_controller ();

    localparam integer SCAN    = 4;
    localparam integer N_CYCLE = 4000;

    reg        clk = 1'b0;
    reg        reset;
    reg  [3:0] digit_1, digit_10, digit_100, digit_1000;
    reg        dot_on;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;

    reg [7:0] tbl[0:15];

    integer seed, seed0;
    integer errors, checks;
    integer i, hold;
    integer sel, prev_sel, slot_cnt;
    reg     armed;
    reg [3:0] exp_digit;
    reg [7:0] exp_seg;
    reg       monitor_on;

    always #5 clk = ~clk;

    fnd_controller #(
        .SCAN_COUNT(SCAN)
    ) DUT (
        .clk       (clk),
        .reset     (reset),
        .digit_1   (digit_1),
        .digit_10  (digit_10),
        .digit_100 (digit_100),
        .digit_1000(digit_1000),
        .dot_on    (dot_on),
        .fnd_com   (fnd_com),
        .fnd_data  (fnd_data)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  com=%b data=%h exp=%h sel=%0d",
                             $time, tag, fnd_com, fnd_data, exp_seg, sel);
            end
        end
    endtask

    function integer com2sel(input [3:0] com);
        begin
            case (com)
                4'b1110: com2sel = 0;
                4'b1101: com2sel = 1;
                4'b1011: com2sel = 2;
                4'b0111: com2sel = 3;
                default: com2sel = -1;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            sel = com2sel(fnd_com);
            chk(sel >= 0, "fnd_com is not one-cold");

            if (sel >= 0) begin
                case (sel)
                    0: exp_digit = digit_1;
                    1: exp_digit = digit_10;
                    2: exp_digit = digit_100;
                    default: exp_digit = digit_1000;
                endcase
                exp_seg = tbl[exp_digit];
                if (dot_on && sel == 2) exp_seg[7] = 1'b0;  // dp 점등
                chk(fnd_data === exp_seg, "fnd_data mismatch");

                // 자리 스캔 순서/주기
                if (armed) begin
                    if (sel != prev_sel) begin
                        chk(slot_cnt == SCAN, "scan slot length != SCAN_COUNT");
                        chk(sel == (prev_sel + 1) % 4, "scan order broken");
                        slot_cnt = 1;
                    end else begin
                        slot_cnt = slot_cnt + 1;
                    end
                end else begin
                    armed    = 1'b1;
                    slot_cnt = 1;
                end
                prev_sel = sel;
            end
        end
    end

    initial begin
        seed0  = 32'h0F0D_C711;
        seed   = seed0;
        errors = 0;
        checks = 0;
        armed  = 1'b0;

        tbl[0]  = 8'hc0; tbl[1]  = 8'hf9; tbl[2]  = 8'ha4; tbl[3]  = 8'hb0;
        tbl[4]  = 8'h99; tbl[5]  = 8'h92; tbl[6]  = 8'h82; tbl[7]  = 8'hf8;
        tbl[8]  = 8'h80; tbl[9]  = 8'h90; tbl[10] = 8'h88; tbl[11] = 8'h83;
        tbl[12] = 8'hc6; tbl[13] = 8'ha1; tbl[14] = 8'hff; tbl[15] = 8'h7f;

        monitor_on = 1'b0;
        reset      = 1'b1;
        digit_1    = 0; digit_10 = 0; digit_100 = 0; digit_1000 = 0;
        dot_on     = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        i = 0;
        while (i < N_CYCLE) begin
            digit_1    = {$random(seed)} % 16;
            digit_10   = {$random(seed)} % 16;
            digit_100  = {$random(seed)} % 16;
            digit_1000 = {$random(seed)} % 16;
            dot_on     = {$random(seed)} % 2;
            hold       = 1 + ({$random(seed)} % 20);  // 무작위 간격으로 바꾼다
            repeat (hold) @(negedge clk);
            i = i + hold;
        end

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_fnd_controller : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_fnd_controller : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_fnd_controller : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
