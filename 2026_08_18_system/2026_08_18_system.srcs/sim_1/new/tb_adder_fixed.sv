`timescale 1ns / 1ps

interface adder_interface;
    logic [7:0] a;
    logic [7:0] b;
    logic mode;
    logic [7:0] s;
    logic c;
endinterface

class transaction;

    rand bit [7:0] a;
    rand bit [7:0] b;
    rand bit mode;
    logic [7:0] s;
    logic c;

endclass

class generator;
    transaction tr;
    virtual adder_interface adder_vif;

    function new(virtual adder_interface adder_aif);
        tr = new;
        adder_vif = adder_aif;
    endfunction

    task run();
        repeat (10) begin
            //randomize();
            tr.randomize();
            adder_vif.a = tr.a;
            adder_vif.b = tr.b;
            adder_vif.mode = tr.mode;
            #10;
        end
    endtask

endclass

class monitor;
    transaction tr;
    virtual adder_interface adder_mon_vif;

    int compare_s;
    bit compare_c;
    function new(virtual adder_interface adder_mon_aif);
        tr = new;
        adder_mon_vif = adder_mon_aif;
    endfunction
    //taskrun
    // FIX: 원본은 task run(arguments); — "arguments"가 타입 없는 매개변수로 선언되어
    //      run()이 인자 1개를 요구하게 됨. 호출부(mon.run())는 인자 없이 부르니 시그니처
    //      불일치로 에러. 그 인자는 어디서도 쓰이지 않아서 그냥 제거.
    task run();
    repeat(10)begin
        #1;
        tr.a   = adder_mon_vif.a;
        tr.b   = adder_mon_vif.b;
        // FIX: 원본의 tr.mon = adder_mon_vif.mon; 삭제 — transaction, adder_interface
        //      어디에도 "mon" 필드가 없어서 컴파일 에러였음 (둘 다 a,b,mode,s,c 뿐).
        tr.s   = adder_mon_vif.s;
        tr.c   = adder_mon_vif.c;

        {compare_c,compare_s}=tr.a+tr.b;
        if(compare_s==tr.s)$display("pass sum");    // FIX: $$display -> $display (존재하지 않는 system task)
        else $display("fail sum");
        if(compare_c==tr.c)$display("pass carry");  // FIX: $$display -> $display
        else $display("fail carry");
    end
    endtask


endclass

module tb_adder_fixed ();
    adder_interface adder_if ();
    generator gen;
    monitor mon;

    adder dut (
        .a(adder_if.a),
        .b(adder_if.b),
        .mode(adder_if.mode),
        .s(adder_if.s),
        .c(adder_if.c)
    );



    initial begin
        gen = new(adder_if);
        mon = new(adder_if);
        // FIX: 원본은 gen.run(); mon.run(); 순차 실행 — monitor가 시작할 때 generator는
        //      이미 10번 다 끝난 뒤라, adder_if.a/b는 마지막(10번째) 값에 멈춰 있고
        //      monitor는 그 값만 10번 반복해서 보게 됨 (10개 트랜잭션 중 사실상 1개만 검증).
        //      fork/join으로 동시에 돌려야 generator가 찌르는 매 트랜잭션을 monitor가 같이 봄.
        fork
            gen.run();
            mon.run();
        join
        // #10;
        $stop;
    end
endmodule
