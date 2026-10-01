`timescale 1ns/1ps

// =============================================================================
// UVM 환경이 DUT 를 만지는 통로 (interface) 네 개
//
//   apb_if       : APB3 + irq + 리셋. 드라이버가 몰고 모니터가 본다.
//   mem_if       : DMA 포트. 메모리 에이전트가 host memory 역할로 응답한다.
//   nand_pin_if  : NAND 핀. 보기만 한다 (passive).
//   aio_bd_if    : backdoor. NAND 모델 내용을 시간 소모 없이 보고 / 고치고 /
//                  고장을 심는다. 실제 칩에는 없는, 시뮬레이션만의 뒷문이다.
// =============================================================================

interface apb_if (input logic clk);
    logic        presetn;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [11:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;
    logic        irq;

`ifndef SYNTHESIS
    // ---------------- APB 프로토콜 assertion ----------------
    // 드라이버가 틀리든 DUT 가 틀리든 버스 규칙이 깨지면 여기서 먼저 걸린다.
    property p_setup_then_access;
        @(posedge clk) disable iff (!presetn)
        (psel && !penable) |=> (psel && penable);
    endproperty

    property p_stable_during_transfer;
        @(posedge clk) disable iff (!presetn)
        (psel && !penable) |=> ($stable(paddr) && $stable(pwrite) && $stable(pwdata));
    endproperty

    property p_penable_needs_psel;
        @(posedge clk) disable iff (!presetn)
        penable |-> psel;
    endproperty

    a_setup_then_access      : assert property (p_setup_then_access)
        else $error("APB: SETUP was not followed by ACCESS");
    a_stable_during_transfer : assert property (p_stable_during_transfer)
        else $error("APB: address/control/data changed between SETUP and ACCESS");
    a_penable_needs_psel     : assert property (p_penable_needs_psel)
        else $error("APB: PENABLE without PSEL");
`endif
endinterface


interface mem_if (input logic clk, input logic presetn);
    logic        req_valid;
    logic        req_ready;
    logic        req_write;
    logic [31:0] req_addr;
    logic [31:0] req_wdata;
    logic [3:0]  req_wstrb;
    logic        rsp_valid;
    logic [31:0] rsp_rdata;
    logic        rsp_ready;

`ifndef SYNTHESIS
    // valid 를 올렸으면 ready 가 올 때까지 내용이 바뀌면 안 된다 (backpressure 의 기본 규칙)
    property p_req_stable;
        @(posedge clk) disable iff (!presetn)
        (req_valid && !req_ready) |=> (req_valid && $stable(req_addr) &&
                                       $stable(req_write) && $stable(req_wdata));
    endproperty

    a_req_stable : assert property (p_req_stable)
        else $error("DMA: request changed or dropped while waiting for ready");
`endif
endinterface


interface nand_pin_if (input logic clk);
    logic       ce_n;
    logic       cle;
    logic       ale;
    logic       we_n;
    logic       re_n;
    logic       wp_n;
    logic       rb_n;
    logic [7:0] dq;
endinterface


// -----------------------------------------------------------------------------
// backdoor : 클래스는 모듈 계층을 직접 가리킬 수 없다. 그래서 계층 경로를 아는
//            함수를 interface 에 넣어 두고, 클래스는 virtual interface 로 부른다.
//            (경로 tb_aio_uvm.u_nand 는 elaboration 때 풀린다)
// -----------------------------------------------------------------------------
interface aio_bd_if;
    logic write_protect;        // DUT 의 write_protect 입력. 테스트가 직접 몬다.

    function automatic logic [7:0] peek(input int row, input int idx);
        return tb_aio_uvm.u_nand.peek(row, idx);
    endfunction

    function automatic void flip_bit(input int row, input int idx, input int b);
        tb_aio_uvm.u_nand.flip_bit(row, idx, b);
    endfunction

    function automatic void set_fail_next_prog();
        tb_aio_uvm.u_nand.fail_next_prog = 1'b1;
    endfunction

    function automatic void set_fail_next_erase();
        tb_aio_uvm.u_nand.fail_next_erase = 1'b1;
    endfunction

    function automatic void set_stuck_busy(input bit on);
        tb_aio_uvm.u_nand.stuck_busy = on;
    endfunction

    function automatic bit fail_prog_armed();
        return tb_aio_uvm.u_nand.fail_next_prog;
    endfunction

    function automatic bit fail_erase_armed();
        return tb_aio_uvm.u_nand.fail_next_erase;
    endfunction

    function automatic bit stuck_busy();
        return tb_aio_uvm.u_nand.stuck_busy;
    endfunction

    function automatic int viol_cnt();
        return tb_aio_uvm.u_nand.viol_cnt;
    endfunction
endinterface
