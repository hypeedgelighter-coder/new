`timescale 1ns / 1ps

//=====================================================================
// tb_main_control_unit  -  main_control_unit 단독 무작위 테스트벤치
//
//  대상 : main_control_unit.v 의 main_control_unit
//
//  이 블록이 하는 일은 세 가지다.
//    1) sw[3:1] 을 우선순위 인코딩해서 현재 모드를 정한다
//         sw[1]=시계 > sw[2]=SR04 > sw[3]=DHT11, 전부 0 이면 스톱워치
//    2) 버튼 펄스와 UART 명령 펄스를 OR 로 합친다
//    3) 합친 것을 "현재 모드에 해당하는 블록으로만" 내보낸다 (게이팅)
//
//  [검사 방법]
//    안에 들어있는 FSM 두 개(control_unit_stopwatch / control_unit_watch)
//    자체는 각자의 테스트벤치에서 따로 본다. 여기서는 그 FSM 을 참조용으로
//    한 벌 더 인스턴스해 놓고, 테스트벤치가 직접 계산한 "게이팅된 입력"을
//    먹인 뒤 출력이 DUT 와 같은지 매 클럭 비교한다.
//    -> FSM 로직을 베끼지 않고 배선/게이팅만 정확히 검사할 수 있다.
//
//  [무작위로 만드는 것]
//    - sw_mode(3비트) 를 무작위 시점에 무작위 값으로 (동시에 여러 개 ON 포함)
//    - sw_disp 무작위
//    - 버튼 4개 + UART 명령 12개를 무작위 1클럭 펄스로
//      (모드가 아닌 곳으로 새는지 보려면 아무 때나 눌러 봐야 한다)
//=====================================================================
module tb_main_control_unit ();

    localparam integer N_CYCLE = 12000;

    reg clk = 1'b0;
    reg reset;
    reg [3:1] sw_mode;
    reg sw_disp;
    reg btn_l, btn_r, btn_u, btn_d;
    reg u_run, u_stop, u_clear, u_mode;
    reg u_up, u_down, u_left, u_right;
    reg u_sel_s, u_sel_m, u_sel_h, u_start;

    wire [1:0] mode_sel;
    wire       disp_mode;
    wire       sw_run_stop, sw_clear, sw_count_mode;
    wire [1:0] wt_edit_sel;
    wire       wt_clear, wt_up, wt_down;
    wire       sr04_start, dht_start;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on, busy;

    always #5 clk = ~clk;

    main_control_unit DUT (
        .clk          (clk),
        .reset        (reset),
        .sw_mode      (sw_mode),
        .sw_disp      (sw_disp),
        .btn_l        (btn_l),
        .btn_r        (btn_r),
        .btn_u        (btn_u),
        .btn_d        (btn_d),
        .u_run        (u_run),
        .u_stop       (u_stop),
        .u_clear      (u_clear),
        .u_mode       (u_mode),
        .u_up         (u_up),
        .u_down       (u_down),
        .u_left       (u_left),
        .u_right      (u_right),
        .u_sel_s      (u_sel_s),
        .u_sel_m      (u_sel_m),
        .u_sel_h      (u_sel_h),
        .u_start      (u_start),
        .mode_sel     (mode_sel),
        .disp_mode    (disp_mode),
        .sw_run_stop  (sw_run_stop),
        .sw_clear     (sw_clear),
        .sw_count_mode(sw_count_mode),
        .wt_edit_sel  (wt_edit_sel),
        .wt_clear     (wt_clear),
        .wt_up        (wt_up),
        .wt_down      (wt_down),
        .sr04_start   (sr04_start),
        .dht_start    (dht_start)
    );

    //-----------------------------------------------------------------
    //  테스트벤치가 따로 계산하는 모드와 게이팅
    //-----------------------------------------------------------------
    wire [1:0] exp_mode = sw_mode[1] ? 2'd1 :
                          sw_mode[2] ? 2'd2 :
                          sw_mode[3] ? 2'd3 : 2'd0;

    wire is_sw = (exp_mode == 2'd0);
    wire is_wt = (exp_mode == 2'd1);
    wire is_sr = (exp_mode == 2'd2);
    wire is_dh = (exp_mode == 2'd3);

    wire [1:0] ref_edit_sel;
    wire       ref_run_stop, ref_clear, ref_count_mode;
    wire       ref_wt_clear, ref_wt_up, ref_wt_down;

    control_unit_stopwatch REF_SW (
        .clk       (clk),
        .reset     (reset),
        .i_run_stop(is_sw & btn_l),
        .i_run     (is_sw & u_run),
        .i_stop    (is_sw & u_stop),
        .i_clear   (is_sw & (btn_r | u_clear)),
        .i_mode    (is_sw & (btn_u | u_mode)),
        .o_run_stop(ref_run_stop),
        .o_clear   (ref_clear),
        .o_mode    (ref_count_mode)
    );

    control_unit_watch REF_WT (
        .clk       (clk),
        .reset     (reset),
        .btn_L     (is_wt & (btn_l | u_left)),
        .btn_R     (is_wt & (btn_r | u_right)),
        .btn_U     (is_wt & (btn_u | u_up)),
        .btn_D     (is_wt & (btn_d | u_down)),
        .btn_C     (is_wt & u_clear),
        .i_sel_sec (is_wt & u_sel_s),
        .i_sel_min (is_wt & u_sel_m),
        .i_sel_hour(is_wt & u_sel_h),
        .edit_sel  (ref_edit_sel),
        .o_clear   (ref_wt_clear),
        .o_up      (ref_wt_up),
        .o_down    (ref_wt_down)
    );

    task chk(input cond, input [8*30:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  sw=%b mode=%0d/%0d",
                             $time, tag, sw_mode, mode_sel, exp_mode);
            end
        end
    endtask

    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            // 조합 출력
            chk(mode_sel   === exp_mode, "mode_sel priority wrong");
            chk(disp_mode  === sw_disp,  "disp_mode not sw[0]");
            chk(sr04_start === (is_sr & (btn_l | u_start)), "sr04_start gating");
            chk(dht_start  === (is_dh & (btn_l | u_start)), "dht_start gating");

            // 게이팅된 입력을 먹인 참조 FSM 과 비교
            chk(sw_run_stop   === ref_run_stop,   "sw_run_stop mismatch");
            chk(sw_clear      === ref_clear,      "sw_clear mismatch");
            chk(sw_count_mode === ref_count_mode, "sw_count_mode mismatch");
            chk(wt_edit_sel   === ref_edit_sel,   "wt_edit_sel mismatch");
            chk(wt_clear      === ref_wt_clear,   "wt_clear mismatch");
            chk(wt_up         === ref_wt_up,      "wt_up mismatch");
            chk(wt_down       === ref_wt_down,    "wt_down mismatch");
        end
    end

    task all_low;
        begin
            btn_l = 1'b0; btn_r = 1'b0; btn_u = 1'b0; btn_d = 1'b0;
            u_run = 1'b0; u_stop = 1'b0; u_clear = 1'b0; u_mode = 1'b0;
            u_up = 1'b0; u_down = 1'b0; u_left = 1'b0; u_right = 1'b0;
            u_sel_s = 1'b0; u_sel_m = 1'b0; u_sel_h = 1'b0; u_start = 1'b0;
        end
    endtask

    initial begin
        seed0  = 32'h6C0D_2001;
        seed   = seed0;
        errors = 0;
        checks = 0;

        monitor_on = 1'b0;
        reset      = 1'b1;
        sw_mode    = 3'b000;
        sw_disp    = 1'b0;
        all_low;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        //---------------- 모드 우선순위 전수 확인 ----------------
        for (i = 0; i < 8; i = i + 1) begin
            sw_mode = i[2:0];
            sw_disp = i[0];
            repeat (2) @(negedge clk);
        end

        //---------------- 무작위 ----------------
        //  입력은 전부 1클럭 폭 펄스이고 연달아 붙지 않는다
        //  (btn_debounce / ascii_decoder 가 그렇게 만든다)
        busy = 1'b0;
        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            if (({$random(seed)} % 40) == 0) sw_mode = {$random(seed)} % 8;
            if (({$random(seed)} % 60) == 0) sw_disp = {$random(seed)} % 2;

            if (busy) begin
                all_low;
                busy = 1'b0;
            end else begin
                btn_l   = (({$random(seed)} % 20) == 0);
                btn_r   = (({$random(seed)} % 20) == 0);
                btn_u   = (({$random(seed)} % 20) == 0);
                btn_d   = (({$random(seed)} % 20) == 0);
                u_run   = (({$random(seed)} % 40) == 0);
                u_stop  = (({$random(seed)} % 40) == 0);
                u_clear = (({$random(seed)} % 40) == 0);
                u_mode  = (({$random(seed)} % 40) == 0);
                u_up    = (({$random(seed)} % 40) == 0);
                u_down  = (({$random(seed)} % 40) == 0);
                u_left  = (({$random(seed)} % 40) == 0);
                u_right = (({$random(seed)} % 40) == 0);
                u_sel_s = (({$random(seed)} % 50) == 0);
                u_sel_m = (({$random(seed)} % 50) == 0);
                u_sel_h = (({$random(seed)} % 50) == 0);
                u_start = (({$random(seed)} % 30) == 0);
                busy    = btn_l | btn_r | btn_u | btn_d |
                          u_run | u_stop | u_clear | u_mode |
                          u_up | u_down | u_left | u_right |
                          u_sel_s | u_sel_m | u_sel_h | u_start;
            end
        end
        @(negedge clk);
        all_low;
        repeat (5) @(negedge clk);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_main_control_unit : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_main_control_unit : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_main_control_unit : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
