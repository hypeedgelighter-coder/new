`timescale 1ns / 1ps
class transaction;

    bit clk;
    bit rst;
    rand bit enable;
    rand bit [7:0] d;
    logic [7:0] q;

endclass

interface reg_interface;
    logic clk;
    logic rst;
    logic enable;
    logic [7:0] d;
    logic [7:0] q;
endinterface 

class generator;//tr 우리가 지금 하고 있는게 tr 랜덤 생성해서 드라이브 해주고 어디에 ? dut에 뭐로 ? 가상케이블로 왜 ? 실제 하드웨어 아님 다시 가상케이블로 받아와서 모니터,스코어 보드 근데 왜 이거 두개 나눠준거지 ?일단 
    
    transaction tr;//tr 핸들명 설명 이타입의 포맷을 쓰겠다 옷걸이 만들어줌
    mailbox#(transaction) gen2drv_mbox;//메일박스 클래스를 쓰겠습다(포인터 역할)메일박스 객체아님

    function new(mailbox#(transaction)gen2drv_mobx);
    this.gen2drv_mbox=gen2drv_mbox;//들어오는 변수 메일박스의 포인터가 가르키는 곳은 여기의 핸들이 가르키는 곳과 같습니다  
    endfunction
     
    task run();
    tr=new();//tr 객체 생성 이제 기본바구니
    tr.randomize();//랜던 tr 객체 생성
    gen2drv_mbox.put(tr);//만들어준 tr의 주소를 포인터에 put 이제 변수객체 메일박스 들어오면 거기에 가르키는곳도 똑 ?.    
    endtask //automatic
endclass //className

class drive;
transaction tr;
mailbox#(transaction) gen2drv_mbox;
virtual reg_interface reg_vif;

function new(mailbox#(transaction) gen2drv_mbox,virtual reg_interface reg_vif);
this.gen2drv_mbox=gen2drv_mbox;
this.reg_vif=reg_vif;
endfunction

task run();
tr=new();//tr 객체 생성
gen2drv_mbox.get(tr);//tr 데이터값 받아옴
reg_vif.enable=tr.enable;//가상 케이블이랑 반아온 거랑 연결 해줌 
reg_vif.d=tr.d;//가상케이블이랑 받아온거랑 연결해줌
endtask //automatic


endclass


module tb ();



    register dut (
        .clk(clk),
        .rst(rst),
        .d  (d),
        .q  (q)
    );


endmodule
