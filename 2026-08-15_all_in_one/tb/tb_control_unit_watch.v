`timescale 1ns / 1ps

//=====================================================================
// tb_control_unit_watch  -  control_unit_watch 단독 무작위 테스트벤치
//
//  대상 : main_control_unit.v 안의 control_unit_watch
//
//  시계 설정용. L/R 로 편집 자리를 옮기고 U/D 로 값 증감 펄스를 낸다.
//    edit_sel : 0=초, 1=분, 2=시
//    L : 왼쪽으로 (0 -> 2 로 랩)      R : 오른쪽으로 (2 -> 0 로 랩)
//    U/D : 1클럭 폭 o_up / o_down     C : 1클럭 폭 o_clear
//    UART 'S'/'M'/'H' 로 자리를 바로 고를 수도 있다
//
//  [무작위로 만드는 것]
//    8개 입력을 매 클럭 무작위 펄스로. 동시에 겹치는 경우도 나온다.
//    (겹치면 L > R > U > D > C > S > M > H 순으로 하나만 먹어야 한다)
//
//  [검사]
//    1) 참조 모델과 edit_sel / o_clear / o_up / o_down 을 매 클럭 비교
//    2) o_up / o_down / o_clear 는 항상 1클럭 폭
//    3) edit_sel 은 절대 3 이 되면 안 된다 (0,1,2 만 유효)
//    4) 딱 집어서 : L 을 세 번 누르면 제자리로, R 도 세 번이면 제자리로
//=====================================================================
module tb_control_unit_watch ();

    localparam integer N_CYCLE = 8000;

    reg  clk = 1'b0;
    reg  reset;
    reg  btn_L, btn_R, btn_U, btn_D, btn_C;
    reg  i_sel_sec, i_sel_min, i_sel_hour;
    wire [1:0] edit_sel;
    wire o_clear, o_up, o_down;

    // 참조 모델
    localparam [2:0] R_IDLE = 3'd0, R_LEFT = 3'd1, R_RIGHT = 3'd2,
                     R_UP   = 3'd3, R_DOWN = 3'd4;
    reg [2:0] r_state, r_nstate;
    reg r_u, r_u_n, r_d, r_d_n, r_cl, r_cl_n;
    reg [1:0] r_sel, r_sel_n;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on;
    reg     p_up, p_dn, p_cl;
    reg     busy;
    reg [1:0] sel0;

    always #5 clk = ~clk;

    control_unit_watch DUT (
        .clk       (clk),
        .reset     (reset),
        .btn_L     (btn_L),
        .btn_R     (btn_R),
        .btn_U     (btn_U),
        .btn_D     (btn_D),
        .btn_C     (btn_C),
        .i_sel_sec (i_sel_sec),
        .i_sel_min (i_sel_min),
        .i_sel_hour(i_sel_hour),
        .edit_sel  (edit_sel),
        .o_clear   (o_clear),
        .o_up      (o_up),
        .o_down    (o_down)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  dut(sel=%0d u=%b d=%b c=%b) ref(sel=%0d u=%b d=%b c=%b)",
                             $time, tag, edit_sel, o_up, o_down, o_clear,
                             r_sel, r_u, r_d, r_cl);
            end
        end
    endtask

    //---------------- 참조 모델 ----------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_state <= R_IDLE;
            r_u <= 1'b0; r_d <= 1'b0; r_cl <= 1'b0; r_sel <= 2'd0;
        end else begin
            r_state <= r_nstate;
            r_u <= r_u_n; r_d <= r_d_n; r_cl <= r_cl_n; r_sel <= r_sel_n;
        end
    end

    always @(*) begin
        r_nstate = r_state;
        r_u_n = r_u; r_d_n = r_d; r_cl_n = r_cl; r_sel_n = r_sel;
        case (r_state)
            R_IDLE: begin
                r_cl_n = 1'b0;
                r_u_n  = 1'b0;
                r_d_n  = 1'b0;
                if (btn_L)            r_nstate = R_LEFT;
                else if (btn_R)       r_nstate = R_RIGHT;
                else if (btn_U)       r_nstate = R_UP;
                else if (btn_D)       r_nstate = R_DOWN;
                else if (btn_C)       r_cl_n   = 1'b1;
                else if (i_sel_sec)   r_sel_n  = 2'd0;
                else if (i_sel_min)   r_sel_n  = 2'd1;
                else if (i_sel_hour)  r_sel_n  = 2'd2;
            end
            R_LEFT:  begin r_sel_n = (r_sel == 2'd0) ? 2'd2 : r_sel - 2'd1;
                           r_nstate = R_IDLE; end
            R_RIGHT: begin r_sel_n = (r_sel == 2'd2) ? 2'd0 : r_sel + 2'd1;
                           r_nstate = R_IDLE; end
            R_UP:    begin r_u_n = 1'b1; r_nstate = R_IDLE; end
            R_DOWN:  begin r_d_n = 1'b1; r_nstate = R_IDLE; end
            default: r_nstate = R_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            chk(edit_sel === r_sel, "edit_sel mismatch");
            chk(o_up     === r_u,   "o_up mismatch");
            chk(o_down   === r_d,   "o_down mismatch");
            chk(o_clear  === r_cl,  "o_clear mismatch");
            chk(edit_sel !== 2'd3,  "edit_sel reached 3");
            chk(!(o_up   === 1'b1 && p_up === 1'b1), "o_up wider than 1 clk");
            chk(!(o_down === 1'b1 && p_dn === 1'b1), "o_down wider than 1 clk");
            chk(!(o_clear=== 1'b1 && p_cl === 1'b1), "o_clear wider than 1 clk");
            p_up = o_up; p_dn = o_down; p_cl = o_clear;
        end
    end

    task all_low;
        begin
            btn_L = 1'b0; btn_R = 1'b0; btn_U = 1'b0; btn_D = 1'b0; btn_C = 1'b0;
            i_sel_sec = 1'b0; i_sel_min = 1'b0; i_sel_hour = 1'b0;
        end
    endtask

    task pulse_L; begin @(negedge clk); all_low; btn_L = 1'b1;
                        @(negedge clk); all_low; repeat (4) @(negedge clk); end endtask
    task pulse_R; begin @(negedge clk); all_low; btn_R = 1'b1;
                        @(negedge clk); all_low; repeat (4) @(negedge clk); end endtask

    initial begin
        seed0  = 32'h3A7C_4001;
        seed   = seed0;
        errors = 0;
        checks = 0;
        p_up = 1'b0; p_dn = 1'b0; p_cl = 1'b0;

        monitor_on = 1'b0;
        reset      = 1'b1;
        all_low;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        chk(edit_sel === 2'd0, "edit_sel is not 0 after reset");

        //---------------- 1) 무작위 펄스 ----------------
        //  이 모듈에 들어오는 신호는 전부 btn_debounce / ascii_decoder 가
        //  만든 1클럭 폭 펄스다. 두 클럭 연속으로 붙어 들어오는 일은 없으므로
        //  펄스를 준 다음 클럭은 반드시 비운다.
        //  (서로 다른 입력이 같은 클럭에 겹치는 경우는 그대로 남겨 둔다)
        busy = 1'b0;
        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            if (busy) begin
                all_low;
                busy = 1'b0;
            end else begin
                btn_L      = (({$random(seed)} % 18) == 0);
                btn_R      = (({$random(seed)} % 18) == 0);
                btn_U      = (({$random(seed)} % 14) == 0);
                btn_D      = (({$random(seed)} % 14) == 0);
                btn_C      = (({$random(seed)} % 30) == 0);
                i_sel_sec  = (({$random(seed)} % 30) == 0);
                i_sel_min  = (({$random(seed)} % 30) == 0);
                i_sel_hour = (({$random(seed)} % 30) == 0);
                busy = btn_L | btn_R | btn_U | btn_D | btn_C |
                       i_sel_sec | i_sel_min | i_sel_hour;
            end
        end
        @(negedge clk);
        all_low;
        repeat (5) @(negedge clk);

        //---------------- 2) 세 번 옮기면 제자리 ----------------
        sel0 = edit_sel;
        pulse_L; pulse_L; pulse_L;
        chk(edit_sel === sel0, "three LEFTs did not return");
        pulse_R; pulse_R; pulse_R;
        chk(edit_sel === sel0, "three RIGHTs did not return");

        // 한 칸씩 이동 방향 확인 (0 -> 2 로 랩)
        while (edit_sel !== 2'd0) pulse_R;
        pulse_L;
        chk(edit_sel === 2'd2, "LEFT from 0 did not wrap to 2");
        pulse_R;
        chk(edit_sel === 2'd0, "RIGHT from 2 did not wrap to 0");

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_control_unit_watch : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_control_unit_watch : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_control_unit_watch : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
