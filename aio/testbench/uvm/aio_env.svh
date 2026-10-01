// =============================================================================
// aio_env.svh : 기능 커버리지 + 환경 조립
// =============================================================================

// -----------------------------------------------------------------------------
// 기능 커버리지 : "무엇을 시험해 봤는가" 를 숫자로 남긴다.
//
//   코드 커버리지는 "이 줄이 실행됐나" 를 세고, 기능 커버리지는 "이 상황을
//   만들어 봤나" 를 센다. 아래 bin 이 곧 검증 계획서의 체크 목록이다.
//
//   스코어보드가 동작 하나를 판정할 때마다 aio_op_result 가 온다.
//   bin 경계에 파라미터(max_words 등)가 들어가면 시뮬레이터마다 지원이
//   갈려서, 먼저 "분류 번호" 로 바꾼 다음 그 번호를 센다.
// -----------------------------------------------------------------------------
class aio_coverage extends uvm_subscriber #(aio_op_result);
    `uvm_component_utils(aio_coverage)

    aio_env_cfg cfg;

    // sample 직전에 채우는 값
    int c_op, c_err, c_words, c_blk, c_page, c_corr, c_uncorr, c_wp, c_bp, c_prev;
    int c_ecc_st, c_ecc_bit;

    covergroup cg_op;
        option.per_instance = 1;

        cp_op : coverpoint c_op {
            bins prog    = {0};
            bins read    = {1};
            bins erase   = {2};
            bins reset   = {3};
        }
        cp_err : coverpoint c_err {
            bins ok        = {0};
            bins bad_len   = {1};
            bins nand_fail = {2};
            bins timeout   = {3};
            bins ecc       = {4};
        }
        // 어떤 동작이 어떤 결과로 끝났나
        x_op_err : cross cp_op, cp_err {
            ignore_bins ecc_needs_read  = binsof(cp_err.ecc) && !binsof(cp_op.read);
            ignore_bins timeout_on_fast = binsof(cp_err.timeout) && (binsof(cp_op.erase) || binsof(cp_op.reset));
            ignore_bins reset_bad_len   = binsof(cp_err.bad_len) && binsof(cp_op.reset);
        }
        cp_words : coverpoint c_words {
            bins zero = {0};        // 거부돼야 한다
            bins one  = {1};
            bins mid  = {2};
            bins max  = {3};
            bins over = {4};        // 거부돼야 한다
        }
        cp_blk : coverpoint c_blk {
            bins first = {0};
            bins mid   = {1};
            bins last  = {2};
        }
        cp_page : coverpoint c_page {
            bins first = {0};
            bins mid   = {1};
            bins last  = {2};
        }
        x_addr : cross cp_blk, cp_page;
        cp_corr : coverpoint c_corr iff (c_op == 1) {
            bins none = {0};
            bins one  = {1};
            bins many = {[2:$]};
        }
        cp_uncorr : coverpoint c_uncorr iff (c_op == 1) {
            bins none = {0};
            bins one  = {1};
            bins many = {[2:$]};
        }
        // 한 페이지 안에 고칠 수 있는 에러와 못 고치는 에러가 섞인 경우
        x_corr_uncorr : cross cp_corr, cp_uncorr;
        cp_wp : coverpoint c_wp {
            bins off = {0};
            bins on  = {1};
        }
        x_op_wp : cross cp_op, cp_wp;
        cp_bp : coverpoint c_bp {
            bins none  = {0};
            bins light = {1};
            bins heavy = {2};
        }
        x_op_bp : cross cp_op, cp_bp {
            ignore_bins no_dma = binsof(cp_op.erase) || binsof(cp_op.reset);
        }
        // 앞 동작 -> 이번 동작 (연달아 돌 때 상태가 새는지)
        cp_prev : coverpoint c_prev {
            bins prog    = {0};
            bins read    = {1};
            bins erase   = {2};
            bins reset   = {3};
        }
        x_seq : cross cp_prev, cp_op;
    endgroup

    // READ 에서 워드마다 한 번씩
    covergroup cg_ecc;
        option.per_instance = 1;

        cp_status : coverpoint c_ecc_st {
            bins clean        = {0};
            bins data_fixed   = {1};
            bins parity_fixed = {2};
            bins uncorr       = {3};
        }
        // 데이터 32 비트 자리를 하나씩 다 고쳐 봤는가
        cp_bit : coverpoint c_ecc_bit iff (c_ecc_st == 1) {
            bins b[32] = {[0:31]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_op  = new();
        cg_ecc = new();
        c_prev = -1;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aio_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "aio_env_cfg not found")
    endfunction

    function int classify3(int v, int last);
        if (v == 0)    return 0;
        if (v >= last) return 2;
        return 1;
    endfunction

    function void write(aio_op_result t);
        c_op     = t.op;
        c_err    = t.err_code;
        c_corr   = t.corr;
        c_uncorr = t.uncorr;
        c_wp     = t.wp;
        c_bp     = t.bp_level;

        if (t.words == 0)                  c_words = 0;
        else if (t.words == 1)             c_words = 1;
        else if (t.words < cfg.max_words)  c_words = 2;
        else if (t.words == cfg.max_words) c_words = 3;
        else                               c_words = 4;

        c_blk  = classify3(t.row / cfg.pages_per_block, cfg.blocks - 1);
        c_page = classify3(t.row % cfg.pages_per_block, cfg.pages_per_block - 1);

        cg_op.sample();
        c_prev = t.op;

        foreach (t.ecc_status[i]) begin
            c_ecc_st  = t.ecc_status[i];
            c_ecc_bit = t.ecc_bitpos[i];
            cg_ecc.sample();
        end
    endfunction

    function void report_phase(uvm_phase phase);
        string msg;
        msg = $sformatf("functional coverage : operations %0.1f%%  ecc %0.1f%%",
                        cg_op.get_inst_coverage(), cg_ecc.get_inst_coverage());
        `uvm_info("COV", msg, UVM_NONE)
    endfunction
endclass


// -----------------------------------------------------------------------------
// 환경
//
//        시퀀스 --> [apb_agent] ---APB---> +-----+ ---핀---> NAND 모델
//                   [mem_agent] <--DMA---> | DUT |             ^
//                                          +-----+             | backdoor
//                   [nand_monitor] <-------- 핀 --------+      |
//                        |                                     |
//        apb.mon / mem.mon / nand_mon ---> [scoreboard] -------+
//                                               |
//                                          [coverage]
// -----------------------------------------------------------------------------
class aio_env extends uvm_env;
    `uvm_component_utils(aio_env)

    apb_agent      apb;
    mem_agent      mem;
    nand_monitor   nand_mon;
    aio_scoreboard sb;
    aio_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        apb      = apb_agent::type_id::create("apb", this);
        mem      = mem_agent::type_id::create("mem", this);
        nand_mon = nand_monitor::type_id::create("nand_mon", this);
        sb       = aio_scoreboard::type_id::create("sb", this);
        cov      = aio_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        apb.mon.ap.connect(sb.apb_imp);
        mem.mon.ap.connect(sb.mem_imp);
        nand_mon.ap.connect(sb.nand_imp);
        sb.result_ap.connect(cov.analysis_export);
    endfunction
endclass
