`timescale 1ns / 1ps


// ************************* Interface ********************************************
// interface : to connect of object with module, moudle
interface adder_interface;
    logic [7:0] a;
    logic [7:0] b;
    logic       mode;
    logic [7:0] s;
    logic       c;

endinterface





// ************************* Transaction ********************************************
// Stimulus for generate variable object
// Data를 '운반'하는 용도로만!! (일종의 서류)
class transaction;
    // 2 state로만 선언
    rand bit [7:0] a;  // rand :  random하게 생성해내겠다.
    rand bit [7:0] b;  // randc:  random하게 + Cycle돌리겠다
    rand bit       mode;  // rand -> 자동으로 랜덤한 값을 넣어줌

    // 출력은 rand하게 생성할 필요가 없는 "결과"이니 Logic으로만 선언
    logic    [7:0] s;
    logic          c;


    constraint mode_dist2 {
        mode dist {  // dist라는 키워드
            0 :/ 90,  // 90/100 확률
            1 :/ 10  // 10/100 확률
        };
    }

    function void debug_print(string name);
        $display("%t : [%s] a = %d, b = %d, mode = %d, s = %d, c = %d", $time,
                 name, a, b, mode, s, c);
    endfunction

endclass




// *********************************** Generator ********************************************
// Sequencer 혹은 Generator 이름으로 작성함.
class generator;  // 객체 이름을 generator로 만든 것

    // Handler는 항상 정적할당(Static allocation)
    // class 객체를 가리키는 handle 선언 (정적 할당 객체)
    transaction tr; // transaction 객체를 가리킬 핸들만 선언 // 아직까진 객체의 위치만 가리킴
    mailbox #(transaction) gen2drv_mbox;
    event event2gen;

    function new(mailbox#(transaction) gen2drv_mbox,
                 event event2gen);  // generator의 생성자
        this.gen2drv_mbox = gen2drv_mbox;
        this.event2gen    = event2gen;
    endfunction


    task run(int run_count);
        // forever begin
        repeat (run_count) begin
            tr = new();  // transaction 객체 생성

            // randomize for tr
            tr.randomize();         // tr -> rand Keyword 대상을 모두 random 값을 생성해라.
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            // wait event2gen;
            @(event2gen);
        end
        $display("end gen");
    endtask

endclass
// 정적 할당 (Static allocation ) : Initializtion 때 할당되는 것
// 동적 할당 (Dynamic allocation) : Running 중에 메모리가 할당되고, release되는 것



// ************************* Driver *****************************
class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual adder_interface adder_vif;
    event event2gen;

    function new(mailbox#(transaction) gen2drv_mbox, event event2gen,
                 virtual adder_interface adder_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.event2gen    = event2gen;
        this.adder_vif    = adder_vif;
    endfunction

    task run();
        forever begin
            gen2drv_mbox.get(tr);

            adder_vif.a    = tr.a;
            adder_vif.b    = tr.b;
            adder_vif.mode = tr.mode;
            #10;
            ->event2gen;  // 이벤트를 발생시키다. // @는 이벤트를 기다리다.
            tr.debug_print("DRV");
        end
        $display("end drv");
    endtask

endclass



// ***************************************** Monitor *********************************
class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual adder_interface adder_mon_vif;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual adder_interface adder_mon_aif);  // 소켓 역활임 
        this.mon2scb_mbox  = mon2scb_mbox;
        this.adder_mon_vif = adder_mon_aif;

    endfunction

    // task run
    task run();
        forever begin
            #1;
            tr = new();     // 객체 생성

            tr.a    = adder_mon_vif.a;
            tr.b    = adder_mon_vif.b;
            tr.mode = adder_mon_vif.mode;
            tr.s    = adder_mon_vif.s;
            tr.c    = adder_mon_vif.c;

            tr.debug_print("MON");
            mon2scb_mbox.put(tr);
            #9;
        end
    endtask

endclass


// ***************************************** Scoreboard *****************************
class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;

    bit [7:0] compare_sum;
    bit compare_carry;
    int pass_cnt = 0, fail_cnt = 0, total_cnt = 0;

    function new(mailbox#(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
        pass_cnt = 0;
        fail_cnt = 0;
    endfunction


    task run();
        forever begin
            // tr이라는 handller를 통해 가져오는 것
            mon2scb_mbox.get(tr);
            tr.debug_print("SCB");
            total_cnt++;
            // scoring
            if (!tr.mode) {compare_carry, compare_sum} = tr.a + tr.b;
            else {compare_carry, compare_sum} = tr.a - tr.b;

            if (compare_sum == tr.s && compare_carry == tr.c) begin
                pass_cnt = pass_cnt + 1;
                $display("%t : scb pass", $time);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("%t : scb fail ", $time);
            end
        end
    endtask

    task done();

        $display("%t : PASS = %d, FAIL = %d", $time, pass_cnt, fail_cnt);

    endtask
endclass



// ***************************************** Environment *****************************
// TOP management gen and mon task
class environment;
    // transaction             tr;
    // virtual adder_interface adder_env_vif;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event event2gen;  // 양쪽 통로를 연결해주는 역할

    function new(virtual adder_interface adder_vif);
        gen2drv_mbox = new;
        gen = new(gen2drv_mbox, event2gen);
        drv = new(gen2drv_mbox, event2gen, adder_vif);

        mon2scb_mbox = new;
        mon = new(mon2scb_mbox, adder_vif);
        scb = new(mon2scb_mbox);
    endfunction

    task run();
        fork
            gen.run(20);
            drv.run();
            mon.run();
            scb.run();
        join_any

        #10;
        $display("_____________________");
        $display("** Total test = %d **", scb.total_cnt);
        $display("** PASS test  = %d **", scb.pass_cnt);
        $display("** FAIL test  = %d **", scb.fail_cnt);
        $display("_____________________");
        $finish;

    endtask

endclass





// **************************************** TB *******************************************
module tb_adder ();
    // adder_interface insatnace (HW 실체화되어 있는 것)
    adder_interface adder_if ();
    // handler for generator class
    environment env;

    adder dut (
        .a   (adder_if.a),
        .b   (adder_if.b),
        .mode(adder_if.mode),
        .s   (adder_if.s),
        .c   (adder_if.c)
    );

    // Stimulus(Vector)을 넣어서 검사 = Verification

    initial begin
        env = new(adder_if);
        env.run();
        // #10;

        $stop;
    end
endmodule



// **********************************************************************
// 08.18(화) SV 1일차
// **********************************************************************
// `timescale 1ns / 1ps


// // ************************* Interface ********************************************
// // interface : to connect of object with module, moudle
// interface adder_interface;
//     logic [7:0] a;
//     logic [7:0] b;
//     logic       mode;
//     logic [7:0] s;
//     logic       c;

// endinterface





// // ************************* Transaction ********************************************
// // Stimulus for generate variable object
// // Data를 '운반'하는 용도로만!! (일종의 서류)
// class transaction;
//     // new 생략 가능하다. 왜냐 = transaction에선 필요 없으니

//     // 4 상태로 선언할 때
//     // logic [7:0] a;
//     // logic [7:0] b;
//     // logic       mode;

//     // 2 state로만 선언
//     rand bit [7:0] a;  // rand :  random하게 생성해내겠다.
//     rand bit [7:0] b;  // randc:  random하게 + Cycle돌리겠다
//     rand bit       mode;  // rand -> 자동으로 랜덤한 값을 넣어줌

//     // 출력은 rand하게 생성할 필요가 없는 "결과"이니 Logic으로만 선언
//     logic    [7:0] s;
//     logic          c;

//     // constraint in_range {
//     //     a > 128;
//     //     b > 250;
//     // }

//     //     constraint in_range {
//     //         a inside {[1:127]};

//     // }

//     // constraint mode_distribute {
//     //     if (mode == 0)
//     //     b inside {0, 1, 2, 3, 15, 20, 127};
//     //     else
//     //     b > 128;
//     // }

//     constraint mode_dist2 {
//         mode dist {  // dist라는 키워드
//             0 :/ 90,  // 90/100 확률
//             1 :/ 10  // 10/100 확률
//         };
//     }

//     function void debug_print(string name);
//         $display("%t : [%s] a = %d, b = %d, mode = %d, s = %d, c = %d", $time,
//                  name, a, b, mode, s, c);
//     endfunction

// endclass




// // *********************************** Generator ********************************************
// // Sequencer 혹은 Generator 이름으로 작성함.
// class generator;  // 객체 이름을 generator로 만든 것

//     // Handler는 항상 정적할당(Static allocation)
//     // class 객체를 가리키는 handle 선언 (정적 할당 객체)
//     transaction tr; // transaction 객체를 가리킬 핸들만 선언 // 아직까진 객체의 위치만 가리킴
//     mailbox #(transaction) gen2drv_mbox;

//     function new(mailbox#(transaction) gen2drv_mbox);  // generator의 생성자
//         this.gen2drv_mbox = gen2drv_mbox;
//     endfunction


//     task run();
//         tr = new();  // transaction 객체 생성

//         // randomize for tr
//         tr.randomize();     // tr -> rand Keyword 대상을 모두 random 값을 생성해라.
//         gen2drv_mbox.put(tr);
//         // $display("%t : gen tr.a = %d, tr.b = %d, tr.mode = %d", $time,
//         //          tr.a, tr.b, tr.mode);

//         tr.debug_print("GEN");
//     endtask

// endclass
// // 정적 할당 (Static allocation ) : Initializtion 때 할당되는 것
// // 동적 할당 (Dynamic allocation) : Running 중에 메모리가 할당되고, release되는 것



// // ************************* Driver *****************************
// class driver;
//     transaction tr;
//     mailbox #(transaction) gen2drv_mbox;
//     virtual adder_interface adder_vif;

//     function new(mailbox#(transaction) gen2drv_mbox,
//                  virtual adder_interface adder_vif);
//         this.gen2drv_mbox = gen2drv_mbox;
//         this.adder_vif    = adder_vif;
//     endfunction

//     task run();
//         gen2drv_mbox.get(tr);

//         adder_vif.a    = tr.a;
//         adder_vif.b    = tr.b;
//         adder_vif.mode = tr.mode;

//         tr.debug_print("DRV");
//     endtask

// endclass



// // ***************************************** Monitor *********************************
// class monitor;
//     transaction tr;
//     mailbox #(transaction) mon2scb_mbox;
//     virtual adder_interface adder_mon_vif;

//     function new(mailbox#(transaction) mon2scb_mbox,
//                  virtual adder_interface adder_mon_aif);  // 소켓 역활임 
//         this.mon2scb_mbox  = mon2scb_mbox;
//         this.adder_mon_vif = adder_mon_aif;

//     endfunction

//     // task run
//     task run();
//         tr = new();     // 객체 생성

//         tr.a    = adder_mon_vif.a;
//         tr.b    = adder_mon_vif.b;
//         tr.mode = adder_mon_vif.mode;
//         tr.s    = adder_mon_vif.s;
//         tr.c    = adder_mon_vif.c;

//         tr.debug_print("MON");
//         mon2scb_mbox.put(tr);
//     endtask

// endclass


// // ***************************************** Scoreboard *****************************
// class scoreboard;
//     transaction tr;
//     mailbox #(transaction) mon2scb_mbox;

//     bit [7:0] compare_sum;
//     bit compare_carry;
//     int pass_cnt = 0, fail_cnt = 0, total_cnt = 0;

//     function new(mailbox#(transaction) mon2scb_mbox);
//         this.mon2scb_mbox = mon2scb_mbox;
//         pass_cnt = 0;
//         fail_cnt = 0;
//     endfunction


//     task run();
//         mon2scb_mbox.get(
//             tr);  // tr이라는 handller를 통해 가져오는 것
//         tr.debug_print("SCB");
//         total_cnt++;
//         // scoring
//         if (!tr.mode) {compare_carry, compare_sum} = tr.a + tr.b;
//         else {compare_carry, compare_sum} = tr.a - tr.b;

//         if (compare_sum == tr.s && compare_carry == tr.c) begin
//             pass_cnt = pass_cnt + 1;
//             $display("%t : scb pass", $time);
//         end
//         else begin
//             fail_cnt = fail_cnt + 1;
//             $display("%t : scb fail ", $time);
//         end

//     endtask

//     task done();

//         $display("%t : PASS = %d, FAIL = %d", $time, pass_cnt, fail_cnt);

//     endtask
// endclass



// // ***************************************** Environment *****************************
// // TOP management gen and mon task
// class environment;
//     // transaction             tr;
//     // virtual adder_interface adder_env_vif;
//     generator              gen;
//     driver                 drv;
//     monitor                mon;
//     scoreboard             scb;

//     mailbox #(transaction) gen2drv_mbox;
//     mailbox #(transaction) mon2scb_mbox;

//     function new(virtual adder_interface adder_vif);
//         gen2drv_mbox = new;
//         gen = new(gen2drv_mbox);
//         drv = new(gen2drv_mbox, adder_vif);

//         mon2scb_mbox = new;
//         mon = new(mon2scb_mbox, adder_vif);
//         scb = new(mon2scb_mbox);
//     endfunction

//     task run();
//         repeat (10) begin
//             gen.run();
//             drv.run();
//             #5;
//             mon.run();
//             scb.run();
//             #5;
//         end

//         #10;
//         $display("_____________________");
//         $display("** Total test = %d **", scb.total_cnt);
//         $display("** PASS test = %d **", scb.pass_cnt);
//         $display("** FAIL test = %d **", scb.fail_cnt);
//         $display("_____________________");
//         $finish;

//     endtask

// endclass


// module tb_adder ();
//     // adder_interface insatnace (HW 실체화되어 있는 것)
//     adder_interface adder_if ();
//     // handler for generator class
//     environment env;

//     adder dut (
//         .a   (adder_if.a),
//         .b   (adder_if.b),
//         .mode(adder_if.mode),
//         .s   (adder_if.s),
//         .c   (adder_if.c)
//     );

//     // Stimulus(Vector)을 넣어서 검사 = Verification

//     initial begin
//         env = new(adder_if);
//         env.run();
//         // #10;

//         $stop;
//     end
// endmodule
