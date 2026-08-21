`timescale 1ns / 1ps

//=====================================================================
// tb_control_unit_stopwatch  -  control_unit_stopwatch 단독 무작위 TB
//
//  대상 : main_control_unit.v 안의 control_unit_stopwatch
//
//  버튼/UART 펄스를 스톱워치 데이터패스가 쓰는 신호로 바꾼다.
//    i_run_stop : 토글 (버튼 L)
//    i_run      : 무조건 RUN  (UART 'r')
//    i_stop     : 무조건 STOP (UART 's')
//    i_clear    : 1클럭 clear 펄스를 만든다
//    i_mode     : 업/다운 카운트 방향 토글
//
//  [무작위로 만드는 것]
//    5개 입력을 매 클럭 무작위 1클럭 펄스로. 두 개가 같은 클럭에 겹치는
//    경우도 그냥 나온다 (그래서 우선순위가 흔들리면 잡힌다).
//
//  [검사]
//    1) 참조 모델과 o_run_stop / o_clear / o_mode 를 매 클럭 비교
//    2) o_clear 는 항상 1클럭 폭 (2클럭 이상 붙으면 카운터가 두 번 지워진다)
//    3) 딱 집어서 보는 것
//       - RUN 중에 'r' 을 또 눌러도 계속 RUN (토글이 아님)
//       - STOP 중에 's' 를 또 눌러도 계속 STOP
//       - 버튼(i_run_stop)은 누를 때마다 토글
//=====================================================================
module tb_control_unit_stopwatch ();

    localparam integer N_CYCLE = 8000;

    reg  clk = 1'b0;
    reg  reset;
    reg  i_run_stop, i_run, i_stop, i_clear, i_mode;
    wire o_run_stop, o_clear, o_mode;

    // 참조 모델
    localparam [1:0] R_STOP = 2'd0, R_RUN = 2'd1, R_CLEAR = 2'd2, R_MODE = 2'd3;
    reg [1:0] r_state, r_nstate;
    reg r_rs, r_rs_n, r_cl, r_cl_n, r_md, r_md_n;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on, prev_clear;

    always #5 clk = ~clk;

    control_unit_stopwatch DUT (
        .clk       (clk),
        .reset     (reset),
        .i_run_stop(i_run_stop),
        .i_run     (i_run),
        .i_stop    (i_stop),
        .i_clear   (i_clear),
        .i_mode    (i_mode),
        .o_run_stop(o_run_stop),
        .o_clear   (o_clear),
        .o_mode    (o_mode)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  dut(rs=%b cl=%b md=%b) ref(rs=%b cl=%b md=%b)",
                             $time, tag, o_run_stop, o_clear, o_mode, r_rs, r_cl, r_md);
            end
        end
    endtask

    //---------------- 참조 모델 ----------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_state <= R_STOP;
            r_rs <= 1'b0; r_cl <= 1'b0; r_md <= 1'b0;
        end else begin
            r_state <= r_nstate;
            r_rs <= r_rs_n; r_cl <= r_cl_n; r_md <= r_md_n;
        end
    end

    always @(*) begin
        r_nstate = r_state;
        r_rs_n = r_rs; r_cl_n = r_cl; r_md_n = r_md;
        case (r_state)
            R_STOP: begin
                r_rs_n = 1'b0;
                r_cl_n = 1'b0;
                if (i_run_stop | i_run) r_nstate = R_RUN;
                else if (i_clear)       r_nstate = R_CLEAR;
                else if (i_mode)        r_nstate = R_MODE;
            end
            R_RUN: begin
                r_rs_n = 1'b1;
                if (i_run_stop | i_stop) r_nstate = R_STOP;
            end
            R_CLEAR: begin
                r_cl_n   = 1'b1;
                r_nstate = R_STOP;
            end
            R_MODE: begin
                r_md_n   = ~r_md;
                r_nstate = R_STOP;
            end
        endcase
    end

    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            chk(o_run_stop === r_rs, "o_run_stop mismatch");
            chk(o_clear    === r_cl, "o_clear mismatch");
            chk(o_mode     === r_md, "o_mode mismatch");
            chk(!(o_clear === 1'b1 && prev_clear === 1'b1), "o_clear wider than 1 clk");
            prev_clear = o_clear;
        end
    end

    task idle_clk(input integer n);
        begin
            repeat (n) begin
                @(negedge clk);
                i_run_stop = 1'b0; i_run = 1'b0; i_stop = 1'b0;
                i_clear = 1'b0; i_mode = 1'b0;
            end
        end
    endtask

    task pulse_run_stop; begin @(negedge clk); i_run_stop = 1'b1;
                               @(negedge clk); i_run_stop = 1'b0; idle_clk(4); end endtask
    task pulse_run;      begin @(negedge clk); i_run = 1'b1;
                               @(negedge clk); i_run = 1'b0; idle_clk(4); end endtask
    task pulse_stop;     begin @(negedge clk); i_stop = 1'b1;
                               @(negedge clk); i_stop = 1'b0; idle_clk(4); end endtask

    initial begin
        seed0  = 32'h5704_2A17;
        seed   = seed0;
        errors = 0;
        checks = 0;
        prev_clear = 1'b0;

        monitor_on = 1'b0;
        reset      = 1'b1;
        i_run_stop = 1'b0; i_run = 1'b0; i_stop = 1'b0;
        i_clear = 1'b0; i_mode = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        chk(o_run_stop === 1'b0, "run_stop is not 0 after reset");
        chk(o_mode     === 1'b0, "mode is not 0 after reset");

        //---------------- 1) 매 클럭 무작위 펄스 ----------------
        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            i_run_stop = (({$random(seed)} % 15) == 0);
            i_run      = (({$random(seed)} % 25) == 0);
            i_stop     = (({$random(seed)} % 25) == 0);
            i_clear    = (({$random(seed)} % 20) == 0);
            i_mode     = (({$random(seed)} % 20) == 0);
        end
        idle_clk(5);

        //---------------- 2) 'r' 은 토글이 아니라 무조건 RUN ----------------
        pulse_stop;                                   // 확실히 STOP 으로
        chk(o_run_stop === 1'b0, "not stopped");
        pulse_run;
        chk(o_run_stop === 1'b1, "'r' did not start");
        pulse_run;                                    // RUN 중에 또 'r'
        chk(o_run_stop === 1'b1, "'r' toggled instead of RUN");
        pulse_run;
        chk(o_run_stop === 1'b1, "'r' toggled instead of RUN");

        //---------------- 3) 's' 는 무조건 STOP ----------------
        pulse_stop;
        chk(o_run_stop === 1'b0, "'s' did not stop");
        pulse_stop;                                   // STOP 중에 또 's'
        chk(o_run_stop === 1'b0, "'s' toggled instead of STOP");

        //---------------- 4) 버튼은 토글 ----------------
        pulse_run_stop;
        chk(o_run_stop === 1'b1, "button did not toggle to RUN");
        pulse_run_stop;
        chk(o_run_stop === 1'b0, "button did not toggle to STOP");
        pulse_run_stop;
        chk(o_run_stop === 1'b1, "button did not toggle to RUN");
        pulse_stop;

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_control_unit_stopwatch : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_control_unit_stopwatch : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_control_unit_stopwatch : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
