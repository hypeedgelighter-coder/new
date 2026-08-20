`timescale 1ns / 1ps
//=============================================================================
// tb_fixed.sv  -  tb.sv 수정본 (GEN -> SCB 메일박스 구조)
//   [원본] / [수정] 주석으로 tb.sv 와의 차이를 표시했습니다.
//   ※ tb.sv 와 module/interface/class 이름이 같으므로 두 파일을 동시에
//     시뮬레이션 fileset 에 넣으면 중복 선언 에러가 납니다.
//     Vivado 에서 한쪽을 우클릭 -> Disable File 하고 돌리세요.
//=============================================================================
interface reg_interface;
    logic        clk;
    logic        rst;
    logic        enable;
    logic [31:0] d;
    logic [31:0] q;
endinterface


// ********************************* Transaction ***********************************
class transaction;
    bit             rst;
    rand bit        enable;
    rand bit [31:0] d;
    logic    [31:0] q;

    function void debug_print(string name);
        $display("%t : [%s] enable = %d, d = %d, q = %d", $time, name, enable,
                 d, q);
    endfunction
endclass


// ********************************* Generator ***********************************
class generator;
    transaction tr;
    transaction tr_scb;                       // [수정] SCB 전용 사본 핸들 추가

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;      // [수정] SCB 로 가는 자극 경로 추가
    event                  event2_gen;

    // [수정] 생성자에 gen2scb_mbox 인자 추가
    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event event2_gen);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen2scb_mbox = gen2scb_mbox;
        this.event2_gen   = event2_gen;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr     = new();
            tr_scb = new();                   // [수정] 같은 핸들을 두 메일박스에
            tr.randomize();                   //        넣으면 DRV/SCB 가 같은 객체를
                                              //        공유해 서로 간섭할 수 있음.
            tr_scb.enable = tr.enable;        //        필드를 복사한 별개 객체로 보냄.
            tr_scb.d      = tr.d;
            tr_scb.q      = tr.q;             //        (q 는 생성 시점엔 의미 없음)

            gen2drv_mbox.put(tr);
            gen2scb_mbox.put(tr_scb);         // [수정]

            tr.debug_print("GEN");
            @(event2_gen);
        end
    endtask
endclass


// ********************************* Driver *************************************
class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual reg_interface reg_vif;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual reg_interface reg_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.reg_vif      = reg_vif;
    endfunction

    task preset();
        reg_vif.rst    = 1;
        reg_vif.enable = 0;
        reg_vif.d      = 0;
        @(negedge reg_vif.clk);
        @(negedge reg_vif.clk);
        reg_vif.rst = 0;
        @(negedge reg_vif.clk);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            // posedge 에서 DUT 가 캡처를 끝낸 뒤(#1) 다음 값을 실어서
            // always_ff 샘플링과 레이스가 나지 않게 함.
            @(posedge reg_vif.clk);
            #1;
            reg_vif.enable = tr.enable;
            reg_vif.d      = tr.d;
            tr.debug_print("DRV");
        end
    endtask
endclass


// ********************************* Monitor ************************************
class monitor;
    transaction            tr;
    virtual reg_interface  reg_vif;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual reg_interface reg_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.reg_vif      = reg_vif;
    endfunction

    task run();
        forever begin
            @(negedge reg_vif.clk);
            tr        = new();
            tr.enable = reg_vif.enable;
            tr.d      = reg_vif.d;
            tr.q      = reg_vif.q;   // 직전 posedge 결과 = "지난 자극"의 출력
            mon2scb_mbox.put(tr);
            tr.debug_print("MON");
        end
    endtask
endclass


// ********************************* Scoreboard *********************************
class scoreboard;
    transaction            gen_tr;            // [수정] GEN 에서 온 이번 자극
    transaction            mon_tr;            // [수정] MON 에서 온 이번 관측
                                              //        (tr 하나로 돌려쓰지 않고 분리)

    mailbox #(transaction) gen2scb_mbox;      // [수정]
    mailbox #(transaction) mon2scb_mbox;
    event                  event2_gen;

    // 참조 모델(= SCB 안의 가짜 레지스터)이 들고 있는 상태.
    // "이번에 q 로 나와야 할 기대값". reset 직후 q 가 0 이므로 0 에서 시작.
    logic [31:0] expected_q = 32'd0;          // [수정] 저장소 추가

    int pass_cnt = 0;                         // [수정] 판정 카운터
    int fail_cnt = 0;

    function new(mailbox#(transaction) gen2scb_mbox,
                 mailbox#(transaction) mon2scb_mbox, event event2_gen);
        // [원본] this.mon2sb_mbox = ... : 선언명(mon2scb_mbox)과 달라 컴파일 에러
        this.gen2scb_mbox = gen2scb_mbox;
        this.mon2scb_mbox = mon2scb_mbox;
        this.event2_gen   = event2_gen;
    endfunction

    task run();
        forever begin
            // ---- 한 루프 = 한 transaction. 각 메일박스에서 get 1번씩 ----
            // [원본] mon2scb_mbox.get() 을 루프 안에서 2번 호출 + @(negedge) 로
            //        직접 한 클럭 미룸 -> MON 출력 절반이 검사 없이 버려지고
            //        GEN 과 박자가 어긋남. SCB 는 클럭을 만지면 안 됨
            //        (타이밍 맞추는 건 MON 담당).
            gen2scb_mbox.get(gen_tr);         // 이번 자극 (아직 DUT 에 안 들어감)
            mon2scb_mbox.get(mon_tr);         // 이번 관측 (q 는 지난 자극의 결과)
            mon_tr.debug_print("SCB");        // [원본] tr.debug_print -> 선언 없는 핸들

            // ---- (1) 비교 : enable 과 무관하게 매 사이클 무조건 ----
            // [원본] if (exp_tr.enable) 로 비교 자체를 막아, hold 동작
            //        (enable=0 일 때 q 가 유지되는가)이 통째로 검증 사각지대였음.
            // [원본] exp_tr.q == mon_tr.d : 과거의 출력 vs 미래의 입력 (양쪽 다 반대)
            //        q 는 항상 "지금 온 mon_tr" 쪽, 기대값은 항상 "저장해 둔" 쪽.
            if (mon_tr.q === expected_q) begin
                pass_cnt++;
                $display("%t : [SCB] PASS  q = %0d (expected %0d)", $time,
                         mon_tr.q, expected_q);
            end else begin
                fail_cnt++;
                $display("%t : [SCB] FAIL  q = %0d (expected %0d)", $time,
                         mon_tr.q, expected_q);
            end

            // ---- (2) 갱신 : 여기서만 enable 로 분기 ----
            // enable=1 이면 이번 d 가 다음 기대값, enable=0 이면 그대로 유지(hold).
            // 참조 모델이 DUT 의 always_ff 를 그대로 흉내내는 부분.
            // [원본] 갱신이 비교 if 안에 중첩돼 있어서, 한 번 mismatch 나면
            //        기대값이 영영 안 굴러가 그 뒤 전부 FAIL 도미노가 됐음.
            if (gen_tr.enable) begin
                expected_q = gen_tr.d;
            end

            ->event2_gen;
        end
    endtask

    function void report();
        $display("=================================================");
        $display("  TOTAL : %0d    PASS : %0d    FAIL : %0d",
                 pass_cnt + fail_cnt, pass_cnt, fail_cnt);
        $display("=================================================");
    endfunction
endclass


// ********************************* Environment ********************************
class environment;
    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;      // [수정]
    mailbox #(transaction) mon2scb_mbox;

    event                  event2_gen;

    function new(virtual reg_interface reg_vif);
        gen2drv_mbox = new();
        gen2scb_mbox = new();                 // [수정] new() 안 하면 null 핸들에
        mon2scb_mbox = new();                 //        put/get 해서 런타임 fatal

        gen = new(gen2drv_mbox, gen2scb_mbox, event2_gen);
        drv = new(gen2drv_mbox, reg_vif);
        mon = new(mon2scb_mbox, reg_vif);
        scb = new(gen2scb_mbox, mon2scb_mbox, event2_gen);
    endfunction

    task run(int run_count = 10);
        drv.preset();
        fork
            gen.run(run_count);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        scb.report();                         // [수정] 최종 집계 출력
        $display("end process env");
        $finish;
    endtask
endclass


// ********************************* TB ***********************************
module tb_register_sv ();
    reg_interface reg_if ();
    environment env;

    register_sv dut (
        .clk   (reg_if.clk),
        .rst   (reg_if.rst),
        .enable(reg_if.enable),
        .d     (reg_if.d),
        .q     (reg_if.q)
    );

    always #5 reg_if.clk = ~reg_if.clk;

    initial begin
        reg_if.clk = 0;
        $display("===== SIMULATION START =====");
        env = new(reg_if);
        env.run(10);
    end
endmodule
