`timescale 1ns / 1ps
interface reg_interface;
    logic        clk;
    logic        rst;
    logic        enable;
    logic [31:0] d;
    logic [31:0] q;

endinterface




// ********************************* Transaction ***********************************
// transaction은 테스트에서 주고받을 데이터 묶음
class transaction;
    bit                           rst;
    rand bit                      enable;
    rand bit               [31:0] d;  // x값 안 만들 거니 bit로
    logic                  [31:0] q;

    
    function void debug_print(string name);
        $display("%t : [%s] enable = %d, d = %d, q = %d", $time, name, enable,
                 d, q);
    endfunction

endclass


// ********************************* Generator ***********************************
class generator;
    transaction tr;                          // Handler 생성
    transaction tr2sb;                       // Handler 생성
    mailbox #(transaction) gen2drv_mbox;     // 메일박스라는 클래스에서 transaction데이터타입으로 된 변수
    mailbox #(transaction) gen2sb_mbox;
    event event2_gen;


    function new(mailbox#(transaction) gen2drv_mbox, mailbox #(transaction) gen2sb_mbox,
                    event event2_gen);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen2sb_mbox = gen2sb_mbox;
        this.event2_gen   = event2_gen;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr = new();
            tr.randomize();

            tr2sb = new();
            tr2sb.enable = tr.enable;
            tr2sb.d      = tr.d;
            tr2sb.q      = tr.q;


            gen2drv_mbox.put(tr);
            gen2sb_mbox.put(tr2sb);

            tr2sb.debug_print("GEN_TR2_SB");
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

            @(posedge reg_vif.clk);
            #1;

            reg_vif.enable = tr.enable;
            reg_vif.d = tr.d;
            tr.debug_print("DRV");
        end
    endtask

endclass


class monitor;
    transaction            tr;
    virtual reg_interface  reg_vif;
    mailbox #(transaction) mon2sb_mbox;

    function new(mailbox#(transaction) mon2sb_mbox,
                 virtual reg_interface reg_vif);
        this.mon2sb_mbox = mon2sb_mbox;
        this.reg_vif     = reg_vif;
    endfunction

    task run();
        forever begin
            @(negedge reg_vif.clk);
            tr        = new();

            tr.enable = reg_vif.enable;
            tr.d      = reg_vif.d;
            tr.q      = reg_vif.q;
            
            mon2sb_mbox.put(tr);  // tr을 메일 박스에 보내기
            tr.debug_print("MON");
        end
    endtask
endclass


class scoreboard;
    transaction            tr;
    transaction            tr2sb;
    
    mailbox #(transaction) mon2sb_mbox;
    mailbox #(transaction) gen2sb_mbox;
    
    event                  event2_gen;
    
    // bit   [31:0]           previous_d = 0;

    function new(mailbox#(transaction) mon2sb_mbox, mailbox #(transaction) gen2sb_mbox, 
                event event2_gen);
        this.mon2sb_mbox = mon2sb_mbox;
        this.gen2sb_mbox = gen2sb_mbox;
        this.event2_gen  = event2_gen;
    endfunction

    bit first_flag = 0;             // 처음에는 건너 뛰게 하기 위함 (1cycle 건너 뛰어야 하니)
    // bit [31:0]      expected_q = 0;

    task run();
        forever begin
            mon2sb_mbox.get(tr);
            // gen2sb_mbox.get(tr2sb);
            if (first_flag) begin
                tr.debug_print("SCB");

                // pass / fail 판단
                if (tr2sb.enable) begin
                    if (tr2sb.d == tr.q) $display("PASS");
                    else $display("FAIL : gen.d = %d, tr.q = %d", tr2sb.d, tr.q);
                end
            end
            else first_flag = 1;    // 1번 건너 뛴다음부터 

            gen2sb_mbox.get(tr2sb);
            ->event2_gen;  // gen에게 event 발생시킨다

            // mon2sb_mbox.get(tr);
            // tr.debug_print("SCB");
            // // pass / fail 판단
            // // write your code
            //     if(tr.enable) begin
            //         if(previous_d ==tr.q) $display("PASS");
            //         else $display("FAIL : pre_d = %d, tr.q = %d", previous_d, tr.q);
            //         
            //         previous_d = tr.d;
            //     end
            // ->event2_gen;  // gen에게 event 발생시킨다
        end
    endtask

endclass


class environment;
    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2sb_mbox;

    event                  event2_gen;

    function new(virtual reg_interface reg_vif);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen2sb_mbox = new();

        gen = new(gen2drv_mbox, gen2sb_mbox, event2_gen);
        drv = new(gen2drv_mbox, reg_vif);
        mon = new(mon2scb_mbox, reg_vif);
        scb = new(mon2scb_mbox, gen2sb_mbox, event2_gen);

    endfunction

    task run();
        drv.preset();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        $display("end process env");
        $finish;
    endtask

endclass



// ********************************* TB ***********************************
module tb_register_sv ();
    reg_interface reg_if ();  // <--------------------------------- 괄호 꼭
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
        env.run();
    end
endmodule
