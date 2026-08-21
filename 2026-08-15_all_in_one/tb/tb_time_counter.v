`timescale 1ns / 1ps

//=====================================================================
// tb_time_counter  -  time_counter 단독 무작위 테스트벤치
//
//  대상 : tick_gen.v 의 time_counter
//         (스톱워치/시계의 msec, sec, min, hour 를 전부 이 모듈 하나로 쓴다)
//
//  [무작위로 만드는 것]
//    매 클럭 i_tick / mode / clear / run_stop / up / down 을 전부 무작위로.
//    동시에 들어오는 조합(up 과 i_tick 이 같은 클럭 등)도 그냥 나온다.
//
//  [검사 방법]  참조 모델(golden model)과 매 클럭 비교
//    RTL 은 $clog2(TIMES) 폭 레지스터로 세지만, 참조 모델은 integer 로
//    센다. 폭이 모자라서 넘치거나 래핑 조건이 어긋나면 바로 갈린다.
//
//    참조 모델이 보는 우선순위 (RTL 과 같아야 하는 규칙)
//      reset  >  clear  >  up|down  >  run_stop&i_tick
//      up   : TIMES-1 에서 0 으로 랩          (o_tick 안 나감)
//      down : 0 에서 TIMES-1 로 랩            (o_tick 안 나감)
//      tick : 랩이 일어나는 그 클럭에만 o_tick=1
//
//  [인스턴스 2개]
//    A : TIMES=10, INIT_VAL=0   (msec/sec 처럼 0 에서 시작)
//    B : TIMES=24, INIT_VAL=12  (시계 hour. clear 하면 12 로 돌아가야 한다)
//=====================================================================
module tb_time_counter ();

    localparam integer N_CYCLE = 8000;

    localparam integer TIMES_A = 10, INIT_A = 0;
    localparam integer TIMES_B = 24, INIT_B = 12;

    reg clk = 1'b0;
    reg reset;
    reg i_tick, mode, clear, run_stop, up, down;

    wire [6:0] cnt_a;
    wire [4:0] cnt_b;
    wire       tick_a, tick_b;

    // 참조 모델
    integer m_a, m_b;
    reg     mt_a, mt_b;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on;

    always #5 clk = ~clk;

    time_counter #(
        .BIT_WIDTH(7),
        .TIMES    (TIMES_A),
        .INIT_VAL (INIT_A)
    ) DUT_A (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (i_tick),
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
        .up        (up),
        .down      (down),
        .time_count(cnt_a),
        .o_tick    (tick_a)
    );

    time_counter #(
        .BIT_WIDTH(5),
        .TIMES    (TIMES_B),
        .INIT_VAL (INIT_B)
    ) DUT_B (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (i_tick),
        .mode      (mode),
        .clear     (clear),
        .run_stop  (run_stop),
        .up        (up),
        .down      (down),
        .time_count(cnt_b),
        .o_tick    (tick_b)
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

    //---------------- 참조 모델 A ----------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            m_a  <= INIT_A;
            mt_a <= 1'b0;
        end else if (clear) begin
            m_a  <= INIT_A;
            mt_a <= 1'b0;
        end else if (up || down) begin
            if (up) m_a <= (m_a == TIMES_A - 1) ? 0 : m_a + 1;
            else    m_a <= (m_a == 0) ? TIMES_A - 1 : m_a - 1;
            mt_a <= 1'b0;
        end else if (run_stop && i_tick) begin
            if (!mode) begin
                m_a  <= (m_a == TIMES_A - 1) ? 0 : m_a + 1;
                mt_a <= (m_a == TIMES_A - 1);
            end else begin
                m_a  <= (m_a == 0) ? TIMES_A - 1 : m_a - 1;
                mt_a <= (m_a == 0);
            end
        end else begin
            mt_a <= 1'b0;
        end
    end

    //---------------- 참조 모델 B ----------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            m_b  <= INIT_B;
            mt_b <= 1'b0;
        end else if (clear) begin
            m_b  <= INIT_B;
            mt_b <= 1'b0;
        end else if (up || down) begin
            if (up) m_b <= (m_b == TIMES_B - 1) ? 0 : m_b + 1;
            else    m_b <= (m_b == 0) ? TIMES_B - 1 : m_b - 1;
            mt_b <= 1'b0;
        end else if (run_stop && i_tick) begin
            if (!mode) begin
                m_b  <= (m_b == TIMES_B - 1) ? 0 : m_b + 1;
                mt_b <= (m_b == TIMES_B - 1);
            end else begin
                m_b  <= (m_b == 0) ? TIMES_B - 1 : m_b - 1;
                mt_b <= (m_b == 0);
            end
        end else begin
            mt_b <= 1'b0;
        end
    end

    //---------------- 매 클럭 비교 (엣지 직전값끼리) ----------------
    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            chk(cnt_a === m_a[6:0], "A count mismatch");
            chk(tick_a === mt_a,    "A o_tick mismatch");
            chk(cnt_b === m_b[4:0], "B count mismatch");
            chk(tick_b === mt_b,    "B o_tick mismatch");
        end
    end

    initial begin
        seed0  = 32'h7C0F_FEE1;
        seed   = seed0;
        errors = 0;
        checks = 0;

        monitor_on = 1'b0;
        reset      = 1'b1;
        i_tick     = 1'b0;
        mode       = 1'b0;
        clear      = 1'b0;
        run_stop   = 1'b0;
        up         = 1'b0;
        down       = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        // 리셋 직후 초기값 확인 (hour 가 12 에서 시작하는지)
        chk(cnt_a === INIT_A[6:0], "A init value");
        chk(cnt_b === INIT_B[4:0], "B init value");

        for (i = 0; i < N_CYCLE; i = i + 1) begin
            @(negedge clk);
            i_tick   = (({$random(seed)} % 3) == 0);    // 1/3
            run_stop = (({$random(seed)} % 8) != 0);    // 7/8
            up       = (({$random(seed)} % 25) == 0);   // 1/25
            down     = (({$random(seed)} % 25) == 0);   // 1/25
            clear    = (({$random(seed)} % 60) == 0);   // 1/60
            if (({$random(seed)} % 100) == 0) mode = ~mode;
        end

        @(negedge clk);
        i_tick = 1'b0; up = 1'b0; down = 1'b0; clear = 1'b0;
        repeat (3) @(negedge clk);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_time_counter : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_time_counter : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_time_counter : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
