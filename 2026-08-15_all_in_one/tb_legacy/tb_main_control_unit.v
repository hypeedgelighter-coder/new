`timescale 1ns / 1ps

//=====================================================================
// tb_main_control_unit  -  Control Unit 검증
//
//  검사 항목
//   1) sw[3:1] 우선순위 인코딩 (낮은 번호 우선, 전부 0 이면 스톱워치)
//   2) 스톱워치 : 버튼 토글 / UART r,s 는 무조건 RUN,STOP / clear / 업다운
//   3) 시계     : 편집 자리 이동(L,R) 과 직접 선택(S,M,H), up 펄스
//   4) 모드 게이팅 : 현재 모드가 아닌 블록으로는 신호가 안 나간다
//=====================================================================
module tb_main_control_unit ();

    reg clk, reset;
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

    integer err;
    integer n_sw_clear, n_wt_up, n_sr04, n_dht;

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

    always #5 clk = ~clk;

    // 펄스 출력 개수 세기
    always @(posedge clk) begin
        if (sw_clear)   n_sw_clear = n_sw_clear + 1;
        if (wt_up)      n_wt_up    = n_wt_up + 1;
        if (sr04_start) n_sr04     = n_sr04 + 1;
        if (dht_start)  n_dht      = n_dht + 1;
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

    // 0=stopwatch 1=watch 2=sr04 3=dht
    task set_mode(input integer m);
        begin
            sw_mode = 3'b000;
            case (m)
                1: sw_mode[1] = 1'b1;
                2: sw_mode[2] = 1'b1;
                3: sw_mode[3] = 1'b1;
            endcase
            repeat (3) @(posedge clk);
        end
    endtask

    // 0=L 1=R 2=U 3=D
    task pulse_btn(input integer which);
        begin
            @(posedge clk);
            #1;
            case (which)
                0: btn_l = 1'b1;
                1: btn_r = 1'b1;
                2: btn_u = 1'b1;
                3: btn_d = 1'b1;
            endcase
            @(posedge clk);
            #1;
            {btn_l, btn_r, btn_u, btn_d} = 4'b0000;
            repeat (5) @(posedge clk);
        end
    endtask

    // 0=run 1=stop 2=clear 3=mode 4=up 5=down 6=left 7=right
    // 8=sel_s 9=sel_m 10=sel_h 11=start
    task pulse_cmd(input integer which);
        begin
            @(posedge clk);
            #1;
            case (which)
                0:  u_run   = 1'b1;
                1:  u_stop  = 1'b1;
                2:  u_clear = 1'b1;
                3:  u_mode  = 1'b1;
                4:  u_up    = 1'b1;
                5:  u_down  = 1'b1;
                6:  u_left  = 1'b1;
                7:  u_right = 1'b1;
                8:  u_sel_s = 1'b1;
                9:  u_sel_m = 1'b1;
                10: u_sel_h = 1'b1;
                11: u_start = 1'b1;
            endcase
            @(posedge clk);
            #1;
            {u_run, u_stop, u_clear, u_mode}   = 4'b0000;
            {u_up, u_down, u_left, u_right}    = 4'b0000;
            {u_sel_s, u_sel_m, u_sel_h, u_start} = 4'b0000;
            repeat (5) @(posedge clk);
        end
    endtask

    initial begin
        clk     = 1'b0;
        reset   = 1'b1;
        sw_mode = 3'b000;
        sw_disp = 1'b0;
        {btn_l, btn_r, btn_u, btn_d} = 4'b0000;
        {u_run, u_stop, u_clear, u_mode} = 4'b0000;
        {u_up, u_down, u_left, u_right} = 4'b0000;
        {u_sel_s, u_sel_m, u_sel_h, u_start} = 4'b0000;
        err = 0;
        n_sw_clear = 0; n_wt_up = 0; n_sr04 = 0; n_dht = 0;

        repeat (10) @(posedge clk);
        reset = 1'b0;
        repeat (10) @(posedge clk);

        $display("\n===== tb_main_control_unit =====");

        //================= 1) 모드 선택 =================
        $display("\n[1] sw[3:1] 우선순위 인코딩");
        set_mode(0);
        ok(mode_sel === 2'd0); $display("sw 전부 내림 -> 스톱워치(0)");
        set_mode(1);
        ok(mode_sel === 2'd1); $display("sw[1] -> 시계(1)");
        set_mode(2);
        ok(mode_sel === 2'd2); $display("sw[2] -> SR04(2)");
        set_mode(3);
        ok(mode_sel === 2'd3); $display("sw[3] -> DHT11(3)");
        sw_mode = 3'b111;
        repeat (3) @(posedge clk);
        ok(mode_sel === 2'd1); $display("sw 여러 개 올리면 낮은 번호(시계) 우선");
        sw_disp = 1'b1;
        repeat (2) @(posedge clk);
        ok(disp_mode === 1'b1); $display("sw[0] 이 disp_mode 로 그대로 나감");
        sw_disp = 1'b0;

        //================= 2) 스톱워치 =================
        $display("\n[2] 스톱워치 모드");
        set_mode(0);
        ok(sw_run_stop === 1'b0); $display("리셋 직후 정지 상태");
        pulse_btn(0);
        ok(sw_run_stop === 1'b1); $display("btn_L -> RUN");
        pulse_btn(0);
        ok(sw_run_stop === 1'b0); $display("btn_L 다시 -> STOP (토글)");
        pulse_cmd(0);
        ok(sw_run_stop === 1'b1); $display("UART 'r' -> RUN");
        pulse_cmd(0);
        ok(sw_run_stop === 1'b1); $display("'r' 한 번 더 -> 여전히 RUN (토글 아님)");
        pulse_cmd(1);
        ok(sw_run_stop === 1'b0); $display("UART 's' -> STOP");
        pulse_cmd(1);
        ok(sw_run_stop === 1'b0); $display("'s' 한 번 더 -> 여전히 STOP");

        n_sw_clear = 0;
        pulse_btn(1);
        ok(n_sw_clear === 1); $display("btn_R -> clear 펄스 1회");
        n_sw_clear = 0;
        pulse_cmd(2);
        ok(n_sw_clear === 1); $display("UART 'c' -> clear 펄스 1회");

        ok(sw_count_mode === 1'b0); $display("업카운트로 시작");
        pulse_btn(2);
        ok(sw_count_mode === 1'b1); $display("btn_U -> 다운카운트로 토글");
        pulse_cmd(3);
        ok(sw_count_mode === 1'b0); $display("UART 'm' -> 다시 업카운트");

        //================= 3) 시계 =================
        $display("\n[3] 시계 모드");
        set_mode(1);
        pulse_cmd(9);  // 'M' : 분 선택
        ok(wt_edit_sel === 2'd1); $display("UART 'M' -> 편집자리 min(1)");
        pulse_btn(0);  // LEFT
        ok(wt_edit_sel === 2'd0); $display("btn_L -> min(1) 에서 sec(0) 으로");
        pulse_btn(1);  // RIGHT
        ok(wt_edit_sel === 2'd1); $display("btn_R -> sec(0) 에서 min(1) 로");
        pulse_cmd(10); // 'H'
        ok(wt_edit_sel === 2'd2); $display("UART 'H' -> hour(2)");
        pulse_btn(1);  // RIGHT (2 -> 0 되감김)
        ok(wt_edit_sel === 2'd0); $display("hour 에서 오른쪽 -> sec 으로 되감김");

        n_wt_up = 0;
        pulse_btn(2);
        ok(n_wt_up === 1); $display("btn_U -> wt_up 펄스 1회");
        n_wt_up = 0;
        pulse_cmd(4);
        ok(n_wt_up === 1); $display("UART 'U' -> wt_up 펄스 1회");

        //================= 4) 모드 게이팅 =================
        $display("\n[4] 모드 게이팅 (다른 모드로는 안 나간다)");
        set_mode(2);  // SR04
        n_sr04 = 0; n_dht = 0;
        pulse_btn(0);
        ok(n_sr04 === 1); $display("SR04 모드에서 btn_L -> sr04_start 1회");
        ok(n_dht === 0); $display("같은 버튼이 DHT11 로는 안 나감");
        ok(sw_run_stop === 1'b0); $display("SR04 모드 버튼이 스톱워치를 건드리지 않음");

        n_sr04 = 0; n_dht = 0;
        pulse_cmd(11);  // 't'
        ok(n_sr04 === 1); $display("SR04 모드에서 UART 't' -> sr04_start 1회");

        set_mode(3);  // DHT11
        n_sr04 = 0; n_dht = 0;
        pulse_btn(0);
        ok(n_dht === 1 && n_sr04 === 0); $display("DHT11 모드에서 btn_L -> dht_start 만");
        n_dht = 0;
        pulse_cmd(11);
        ok(n_dht === 1); $display("DHT11 모드에서 UART 't' -> dht_start 1회");

        set_mode(0);  // 스톱워치
        n_sr04 = 0; n_dht = 0;
        pulse_btn(0);
        ok(n_sr04 === 0 && n_dht === 0); $display("스톱워치 모드 버튼은 센서로 안 나감");
        ok(sw_run_stop === 1'b1); $display("대신 스톱워치가 RUN 으로");

        if (err == 0) $display("\n===== tb_main_control_unit : ALL PASS =====\n");
        else $display("\n===== tb_main_control_unit : %0d FAIL =====\n", err);
        $finish;
    end

endmodule
