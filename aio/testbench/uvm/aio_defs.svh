// =============================================================================
// aio_defs.svh : 공용 상수 / 트랜잭션 / 설정 객체 / host memory 모델
// =============================================================================

// ---------------- 레지스터 오프셋 (docs/design_spec.md 와 같다) ----------------
localparam logic [11:0] REG_CONTROL      = 12'h000;
localparam logic [11:0] REG_STATUS       = 12'h004;
localparam logic [11:0] REG_NAND_ROW     = 12'h008;
localparam logic [11:0] REG_HOST_ADDR    = 12'h00c;
localparam logic [11:0] REG_PAGE_WORDS   = 12'h010;
localparam logic [11:0] REG_TIMEOUT      = 12'h014;
localparam logic [11:0] REG_CORR_COUNT   = 12'h018;
localparam logic [11:0] REG_UNCORR_COUNT = 12'h01c;
localparam logic [11:0] REG_ERROR_CODE   = 12'h020;
localparam logic [11:0] REG_IRQ_ENABLE   = 12'h024;
localparam logic [11:0] REG_ID           = 12'h0fc;

localparam logic [31:0] ID_VALUE = 32'h4149_4f31;   // "AIO1"

localparam int OP_PROGRAM = 0;
localparam int OP_READ    = 1;
localparam int OP_ERASE   = 2;
localparam int OP_RESET   = 3;

// ERROR_CODE 값
localparam int ERR_NONE       = 0;
localparam int ERR_BAD_LENGTH = 1;
localparam int ERR_NAND_FAIL  = 2;
localparam int ERR_TIMEOUT    = 3;
localparam int ERR_ECC        = 4;

// ECC 판정
localparam int ECC_CLEAN        = 0;
localparam int ECC_DATA_FIXED   = 1;
localparam int ECC_PARITY_FIXED = 2;
localparam int ECC_UNCORR       = 3;

localparam logic [6:0] ECC_ERASED_MASK = 7'h67;
localparam int         BYTES_PER_WORD  = 5;         // data 4 + ecc 1


// =============================================================================
// APB 트랜잭션
// =============================================================================
class apb_item extends uvm_sequence_item;
    rand logic [11:0] addr;
    rand logic [31:0] data;         // write : 쓸 값   /   read : 읽힌 값
    rand bit          write;
    bit               slverr;
    bit               irq;          // ACCESS 가 끝날 때의 irq 핀
    bit               is_reset;     // 1 이면 "리셋이 들어왔다" 는 알림 (버스 전송 아님)

    `uvm_object_utils(apb_item)

    function new(string name = "apb_item");
        super.new(name);
    endfunction

    function string convert2string();
        string s;
        if (is_reset)   s = "RESET";
        else if (write) s = $sformatf("WR addr=%03x data=%08x", addr, data);
        else            s = $sformatf("RD addr=%03x data=%08x", addr, data);
        return s;
    endfunction
endclass


// =============================================================================
// DMA 트랜잭션 (모니터가 handshake 하나마다 만든다)
// =============================================================================
class mem_item extends uvm_sequence_item;
    logic [31:0] addr;
    logic [31:0] data;
    bit          write;

    `uvm_object_utils(mem_item)

    function new(string name = "mem_item");
        super.new(name);
    endfunction
endclass


// =============================================================================
// NAND 핀에서 다시 조립한 트랜잭션. CE# 가 내려가 있는 한 구간이 하나다.
// =============================================================================
class nand_txn extends uvm_sequence_item;
    logic [7:0] cmds  [$];      // CLE 사이클
    logic [7:0] addrs [$];      // ALE 사이클
    logic [7:0] wdata [$];      // WE# 데이터 사이클
    logic [7:0] rdata [$];      // RE# 사이클

    `uvm_object_utils(nand_txn)

    function new(string name = "nand_txn");
        super.new(name);
    endfunction

    function string convert2string();
        // xsim 2020.2 : 문자열 연결 안에 함수 호출을 바로 넣으면 커널이 죽는다.
        // 지역변수에 먼저 받는다.
        string s, t;
        s = "cmd";
        foreach (cmds[i]) begin
            t = $sformatf(" %02x", cmds[i]);
            s = {s, t};
        end
        t = $sformatf(" | addr x%0d | wr x%0d | rd x%0d", addrs.size(), wdata.size(), rdata.size());
        s = {s, t};
        return s;
    endfunction
endclass


// =============================================================================
// 스코어보드가 동작 하나를 다 판정한 뒤 커버리지로 넘기는 요약
// =============================================================================
class aio_op_result extends uvm_object;
    int op;
    int row;
    int words;
    int err_code;
    int corr;
    int uncorr;
    bit wp;
    int bp_level;           // DMA backpressure : 0 없음, 1 보통, 2 심함
    int ecc_status [$];     // READ 일 때 워드별 판정
    int ecc_bitpos [$];     // DATA_FIXED 일 때 고친 데이터 비트 (그 외 -1)

    `uvm_object_utils(aio_op_result)

    function new(string name = "aio_op_result");
        super.new(name);
    endfunction
endclass


// =============================================================================
// host memory : DMA 의 상대. 메모리 에이전트가 응답에 쓰고, 시퀀스가 미리 채운다.
// =============================================================================
class host_mem_model extends uvm_object;
    logic [31:0] mem [int unsigned];

    `uvm_object_utils(host_mem_model)

    function new(string name = "host_mem_model");
        super.new(name);
    endfunction

    function logic [31:0] read(logic [31:0] addr);
        int unsigned idx = addr[31:2];
        if (mem.exists(idx)) return mem[idx];
        return 32'h0;
    endfunction

    function void write(logic [31:0] addr, logic [31:0] data, logic [3:0] strb = 4'hf);
        int unsigned idx = addr[31:2];
        logic [31:0] cur;
        cur = mem.exists(idx) ? mem[idx] : 32'h0;
        for (int b = 0; b < 4; b++)
            if (strb[b]) cur[8*b +: 8] = data[8*b +: 8];
        mem[idx] = cur;
    endfunction
endclass


// =============================================================================
// 환경 설정. 테스트가 만들어 config_db 에 넣고, 모든 컴포넌트가 같은 객체를 본다.
// =============================================================================
class aio_env_cfg extends uvm_object;
    virtual apb_if      apb_vif;
    virtual mem_if      mem_vif;
    virtual nand_pin_if nand_vif;
    virtual aio_bd_if   bd_vif;

    host_mem_model host_mem;

    // DUT 파라미터 (tb 에서 채운다)
    int max_words       = 16;
    int pages_per_block = 64;
    int blocks          = 4;
    int stall_cycles    = 256;      // PHY 가 "코어가 떠났다" 고 판단하는 데 걸리는 클럭 수

    // ---- DMA backpressure 손잡이 (시퀀스가 돌리는 중에 바꾼다) ----
    int mem_ready_pct   = 75;       // 매 클럭 req_ready 가 1 일 확률 (%)
    int mem_rsp_pct     = 66;       // 읽기 응답이 이번 클럭에 나갈 확률 (%)
    int bp_level        = 1;

    // ---- 테스트가 스코어보드에 미리 알려 주는 것 ----
    bit expect_watchdog = 0;        // 다음 동작은 코어 watchdog 으로 끝난다

    `uvm_object_utils(aio_env_cfg)

    function new(string name = "aio_env_cfg");
        super.new(name);
        host_mem = host_mem_model::type_id::create("host_mem");
    endfunction

    function void set_backpressure(int level);
        bp_level = level;
        case (level)
            0:       begin mem_ready_pct = 100; mem_rsp_pct = 100; end
            1:       begin mem_ready_pct = 75;  mem_rsp_pct = 66;  end
            default: begin mem_ready_pct = 15;  mem_rsp_pct = 20;  end
        endcase
    endfunction
endclass
