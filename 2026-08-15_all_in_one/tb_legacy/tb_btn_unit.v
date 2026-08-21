`timescale 1ns / 1ps

//=====================================================================
// tb_btn_unit  -  버튼 디바운스 묶음 검증
//
//  btn_debounce 는 1ms 마다 버튼을 샘플해서 8번 연속 1이어야 눌린 것으로
//  인정하고, 그 상승엣지에서 1클럭 폭 펄스를 낸다.
//  시뮬에서는 SAMPLE_COUNT 를 10 으로 줄여 8샘플 = 80클럭이면 인정된다.
//
//  검사 항목
//   1) 깨끗하게 누르면 펄스가 정확히 1회
//   2) 계속 누르고 있어도 추가 펄스가 안 나옴
//   3) 짧은 채터링(30클럭 단위 떨림)은 무시됨
//   4) 4채널이 서로 간섭하지 않음
//=====================================================================
module tb_btn_unit ();

    localparam integer P_SAMPLE = 10;  // 8샘플 = 80클럭

    reg  clk, reset;
    reg  i_l, i_r, i_u, i_d;
    wire o_l, o_r, o_u, o_d;

    integer err;
    integer cnt_l, cnt_r, cnt_u, cnt_d;

    btn_unit #(
        .SAMPLE_COUNT(P_SAMPLE)
    ) DUT (
        .clk    (clk),
        .reset  (reset),
        .i_btn_l(i_l),
        .i_btn_r(i_r),
        .i_btn_u(i_u),
        .i_btn_d(i_d),
        .o_btn_l(o_l),
        .o_btn_r(o_r),
        .o_btn_u(o_u),
        .o_btn_d(o_d)
    );

    always #5 clk = ~clk;

    // 출력 펄스 개수 세기
    always @(posedge clk) begin
        if (o_l) cnt_l = cnt_l + 1;
        if (o_r) cnt_r = cnt_r + 1;
        if (o_u) cnt_u = cnt_u + 1;
        if (o_d) cnt_d = cnt_d + 1;
    end

    task ok(input cond);
        begin
            if (cond) $write("  OK   : ");
            else begin
                $write("  FAIL : ");
                err = err + 1;
            end
        end
    endtask

    // which : 0=L 1=R 2=U 3=D
    task press(input integer which, input integer hold);
        begin
            case (which)
                0: i_l = 1'b1;
                1: i_r = 1'b1;
                2: i_u = 1'b1;
                3: i_d = 1'b1;
            endcase
            repeat (hold) @(posedge clk);
            case (which)
                0: i_l = 1'b0;
                1: i_r = 1'b0;
                2: i_u = 1'b0;
                3: i_d = 1'b0;
            endcase
            repeat (hold) @(posedge clk);
        end
    endtask

    // 30클럭 High / 30클럭 Low 반복.
    // 샘플이 10클럭마다이므로 연속 1이 최대 3번 -> 8번을 못 채워 무시돼야 한다.
    task chatter;
        integer k;
        begin
            for (k = 0; k < 5; k = k + 1) begin
                i_l = 1'b1;
                repeat (30) @(posedge clk);
                i_l = 1'b0;
                repeat (30) @(posedge clk);
            end
            repeat (100) @(posedge clk);
        end
    endtask

    initial begin
        clk   = 1'b0;
        reset = 1'b1;
        {i_l, i_r, i_u, i_d} = 4'b0000;
        cnt_l = 0; cnt_r = 0; cnt_u = 0; cnt_d = 0;
        err   = 0;

        repeat (10) @(posedge clk);
        reset = 1'b0;
        repeat (200) @(posedge clk);
        cnt_l = 0; cnt_r = 0; cnt_u = 0; cnt_d = 0;

        $display("\n===== tb_btn_unit =====");

        //---------------- 1) 채터링 무시 ----------------
        $display("\n[1] 짧은 채터링은 무시되는가");
        chatter;
        ok(cnt_l === 0); $display("채터링만으로는 펄스가 나오지 않는다");

        //---------------- 2) 정상 1회 누름 ----------------
        $display("\n[2] 깨끗하게 한 번 누르면 펄스 1회");
        cnt_l = 0;
        press(0, 200);
        ok(cnt_l === 1); $display("btn_L 펄스 1회");

        //---------------- 3) 길게 눌러도 1회 ----------------
        $display("\n[3] 길게 눌러도 펄스는 1회");
        cnt_l = 0;
        i_l = 1'b1;
        repeat (2000) @(posedge clk);
        ok(cnt_l === 1); $display("2000클럭 누르고 있어도 펄스 1회");
        i_l = 1'b0;
        repeat (200) @(posedge clk);

        //---------------- 4) 두 번 누르면 두 번 ----------------
        $display("\n[4] 두 번 누르면 펄스 2회");
        cnt_l = 0;
        press(0, 200);
        press(0, 200);
        ok(cnt_l === 2); $display("btn_L 펄스 2회");

        //---------------- 5) 채널 독립 ----------------
        $display("\n[5] 4채널이 서로 간섭하지 않는가");
        cnt_l = 0; cnt_r = 0; cnt_u = 0; cnt_d = 0;
        press(1, 200);
        ok(cnt_r === 1 && cnt_l === 0 && cnt_u === 0 && cnt_d === 0); $display("btn_R 만 눌렀을 때 R 만 반응");
        press(2, 200);
        ok(cnt_u === 1 && cnt_r === 1 && cnt_l === 0 && cnt_d === 0); $display("btn_U 만 눌렀을 때 U 만 반응");
        press(3, 200);
        ok(cnt_d === 1 && cnt_u === 1 && cnt_l === 0); $display("btn_D 만 눌렀을 때 D 만 반응");

        //---------------- 6) 리셋 ----------------
        $display("\n[6] 리셋 중에는 펄스가 안 나오는가");
        cnt_l = 0;
        i_l   = 1'b1;
        reset = 1'b1;
        repeat (500) @(posedge clk);
        ok(cnt_l === 0); $display("리셋 유지 중 펄스 없음");
        reset = 1'b0;
        i_l   = 1'b0;
        repeat (200) @(posedge clk);

        if (err == 0) $display("\n===== tb_btn_unit : ALL PASS =====\n");
        else $display("\n===== tb_btn_unit : %0d FAIL =====\n", err);
        $finish;
    end

endmodule
