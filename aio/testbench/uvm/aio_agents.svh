// =============================================================================
// aio_agents.svh : 에이전트 셋
//
//   apb_agent   (active)   : 시퀀스가 준 apb_item 을 버스에 실어 보낸다 + 본다
//   mem_agent   (reactive) : DUT 가 DMA 로 물어 오면 host memory 로서 답한다 + 본다
//   nand_monitor (passive) : NAND 핀을 보고 커맨드 시퀀스를 다시 조립한다
//
//   모니터는 드라이버가 뭘 보냈는지 모른다. 오직 핀만 본다. 그래야 드라이버가
//   틀렸을 때도, DUT 가 틀렸을 때도 스코어보드가 같은 눈으로 잡아낸다.
// =============================================================================

// -----------------------------------------------------------------------------
// APB
// -----------------------------------------------------------------------------
typedef uvm_sequencer #(apb_item) apb_sequencer;

class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)

    aio_env_cfg    cfg;
    virtual apb_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aio_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "aio_env_cfg not found")
        vif = cfg.apb_vif;
    endfunction

    task run_phase(uvm_phase phase);
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite  <= 1'b0;
        vif.paddr   <= '0;
        vif.pwdata  <= '0;
        forever begin
            seq_item_port.get_next_item(req);
            drive(req);
            seq_item_port.item_done();
        end
    endtask

    // APB 한 번 : SETUP (psel=1, penable=0) -> ACCESS (penable=1, pready 까지)
    task drive(apb_item it);
        @(posedge vif.clk);
        vif.psel    <= 1'b1;
        vif.penable <= 1'b0;
        vif.pwrite  <= it.write;
        vif.paddr   <= it.addr;
        vif.pwdata  <= it.data;
        @(posedge vif.clk);
        vif.penable <= 1'b1;
        do @(posedge vif.clk); while (!vif.pready);
        if (!it.write) it.data = vif.prdata;
        it.slverr = vif.pslverr;
        it.irq    = vif.irq;
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
    endtask
endclass


class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    aio_env_cfg    cfg;
    virtual apb_if vif;
    uvm_analysis_port #(apb_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aio_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "aio_env_cfg not found")
        vif = cfg.apb_vif;
    endfunction

    task run_phase(uvm_phase phase);
        fork
            watch_bus();
            watch_reset();
        join
    endtask

    task watch_bus();
        apb_item it;
        forever begin
            @(posedge vif.clk);
            if (vif.presetn && vif.psel && vif.penable && vif.pready) begin
                it = apb_item::type_id::create("it");
                it.addr   = vif.paddr;
                it.write  = vif.pwrite;
                it.data   = vif.pwrite ? vif.pwdata : vif.prdata;
                it.slverr = vif.pslverr;
                it.irq    = vif.irq;
                ap.write(it);
            end
        end
    endtask

    task watch_reset();
        apb_item it;
        forever begin
            @(negedge vif.presetn);
            it = apb_item::type_id::create("it");
            it.is_reset = 1'b1;
            ap.write(it);
        end
    endtask
endclass


class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_driver    drv;
    apb_monitor   mon;
    apb_sequencer sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = apb_driver::type_id::create("drv", this);
        mon = apb_monitor::type_id::create("mon", this);
        sqr = apb_sequencer::type_id::create("sqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass


// -----------------------------------------------------------------------------
// DMA memory : 시퀀스가 없다. DUT 가 요청하면 그때 답하는 slave 다.
//
//   req_ready 와 응답 지연을 무작위로 흔든다 (cfg.mem_ready_pct / mem_rsp_pct).
//   backpressure 아래에서 DUT 의 index 와 상태가 "handshake 가 성립한 클럭에만"
//   전진하는지를 보려는 것이다.
// -----------------------------------------------------------------------------
class mem_responder extends uvm_component;
    `uvm_component_utils(mem_responder)

    aio_env_cfg    cfg;
    virtual mem_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aio_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "aio_env_cfg not found")
        vif = cfg.mem_vif;
    endfunction

    task run_phase(uvm_phase phase);
        bit          pending;
        logic [31:0] pending_data;

        vif.req_ready <= 1'b0;
        vif.rsp_valid <= 1'b0;
        vif.rsp_rdata <= '0;
        pending = 1'b0;

        forever begin
            @(posedge vif.clk);
            if (!vif.presetn) begin
                vif.req_ready <= 1'b0;
                vif.rsp_valid <= 1'b0;
                pending = 1'b0;
            end else begin
                // 이번 클럭에 성립한 handshake 부터 처리한다 (아래 값들은 엣지 직전 값이다)
                if (vif.rsp_valid && vif.rsp_ready) vif.rsp_valid <= 1'b0;

                if (vif.req_valid && vif.req_ready) begin
                    if (vif.req_write) begin
                        cfg.host_mem.write(vif.req_addr, vif.req_wdata, vif.req_wstrb);
                    end else begin
                        if (pending)
                            `uvm_error("MEM", "DUT issued a second read before the first response")
                        pending      = 1'b1;
                        pending_data = cfg.host_mem.read(vif.req_addr);
                    end
                end else if (pending && !vif.rsp_valid &&
                             ($urandom_range(0, 99) < cfg.mem_rsp_pct)) begin
                    vif.rsp_valid <= 1'b1;
                    vif.rsp_rdata <= pending_data;
                    pending = 1'b0;
                end

                vif.req_ready <= ($urandom_range(0, 99) < cfg.mem_ready_pct);
            end
        end
    endtask
endclass


class mem_monitor extends uvm_monitor;
    `uvm_component_utils(mem_monitor)

    aio_env_cfg    cfg;
    virtual mem_if vif;
    uvm_analysis_port #(mem_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aio_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "aio_env_cfg not found")
        vif = cfg.mem_vif;
    endfunction

    // 쓰기는 요청 handshake 에서, 읽기는 응답 handshake 에서 하나씩 내보낸다.
    task run_phase(uvm_phase phase);
        mem_item     it;
        logic [31:0] rd_addr;
        forever begin
            @(posedge vif.clk);
            if (vif.presetn) begin
                if (vif.req_valid && vif.req_ready) begin
                    if (vif.req_write) begin
                        it = mem_item::type_id::create("it");
                        it.addr  = vif.req_addr;
                        it.data  = vif.req_wdata;
                        it.write = 1'b1;
                        ap.write(it);
                    end else rd_addr = vif.req_addr;
                end
                if (vif.rsp_valid && vif.rsp_ready) begin
                    it = mem_item::type_id::create("it");
                    it.addr  = rd_addr;
                    it.data  = vif.rsp_rdata;
                    it.write = 1'b0;
                    ap.write(it);
                end
            end
        end
    endtask
endclass


class mem_agent extends uvm_agent;
    `uvm_component_utils(mem_agent)

    mem_responder rsp;
    mem_monitor   mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        rsp = mem_responder::type_id::create("rsp", this);
        mon = mem_monitor::type_id::create("mon", this);
    endfunction
endclass


// -----------------------------------------------------------------------------
// NAND 핀 모니터
//
//   WE# 상승 엣지 : CLE 면 커맨드, ALE 면 주소, 둘 다 아니면 쓰기 데이터
//   RE# 상승 엣지 : 읽기 데이터 (컨트롤러가 잡는 순간과 같다)
//   CE# 상승 엣지 : 트랜잭션 하나가 끝났다 -> 스코어보드로 보낸다
//
//   NAND 모델(nand_model.sv)과는 따로 핀을 해석한다. 모델이 "받아들인 것" 과
//   모니터가 "본 것" 이 둘 다 예측과 맞아야 통과다.
// -----------------------------------------------------------------------------
class nand_monitor extends uvm_monitor;
    `uvm_component_utils(nand_monitor)

    aio_env_cfg         cfg;
    virtual nand_pin_if vif;
    uvm_analysis_port #(nand_txn) ap;

    nand_txn cur;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aio_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "aio_env_cfg not found")
        vif = cfg.nand_vif;
    endfunction

    task run_phase(uvm_phase phase);
        cur = nand_txn::type_id::create("cur");
        fork
            forever begin
                @(posedge vif.we_n);
                if (vif.ce_n === 1'b0) begin
                    if (vif.cle)      cur.cmds.push_back(vif.dq);
                    else if (vif.ale) cur.addrs.push_back(vif.dq);
                    else              cur.wdata.push_back(vif.dq);
                end
            end
            forever begin
                @(posedge vif.re_n);
                if (vif.ce_n === 1'b0) cur.rdata.push_back(vif.dq);
            end
            forever begin
                @(posedge vif.ce_n);
                if (cur.cmds.size() != 0) begin
                    ap.write(cur);
                    cur = nand_txn::type_id::create("cur");
                end
            end
        join
    endtask
endclass
