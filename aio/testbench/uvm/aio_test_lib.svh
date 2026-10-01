// =============================================================================
// aio_test_lib.svh : 테스트
//
//   테스트는 "환경을 세우고 시퀀스 하나를 고르는 것" 이 전부다.
//
//     aio_smoke_test   aio_ecc_test   aio_err_test
//     aio_bp_test      aio_reset_test aio_rand_test
//
//   [테스트 고르는 법]
//     VCS  : +UVM_TESTNAME=aio_ecc_test
//     xsim : 윈도의 xsim.bat 이 '=' 가 든 인자를 잘라 먹는다. 그래서 실행
//            디렉터리의 uvm_test.txt 에 이름을 적어 두면 tb 가 읽어서 넘긴다.
//            (scripts/regress.py 가 알아서 한다)
// =============================================================================

class aio_base_test extends uvm_test;
    `uvm_component_utils(aio_base_test)

    aio_env     env;
    aio_env_cfg cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = aio_env_cfg::type_id::create("cfg");
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "apb_vif", cfg.apb_vif))
            `uvm_fatal("NOVIF", "apb_vif not set")
        if (!uvm_config_db #(virtual mem_if)::get(this, "", "mem_vif", cfg.mem_vif))
            `uvm_fatal("NOVIF", "mem_vif not set")
        if (!uvm_config_db #(virtual nand_pin_if)::get(this, "", "nand_vif", cfg.nand_vif))
            `uvm_fatal("NOVIF", "nand_vif not set")
        if (!uvm_config_db #(virtual aio_bd_if)::get(this, "", "bd_vif", cfg.bd_vif))
            `uvm_fatal("NOVIF", "bd_vif not set")
        void'(uvm_config_db #(int)::get(this, "", "max_words", cfg.max_words));
        void'(uvm_config_db #(int)::get(this, "", "pages_per_block", cfg.pages_per_block));
        void'(uvm_config_db #(int)::get(this, "", "blocks", cfg.blocks));
        void'(uvm_config_db #(int)::get(this, "", "stall_cycles", cfg.stall_cycles));

        uvm_config_db #(aio_env_cfg)::set(this, "*", "cfg", cfg);
        env = aio_env::type_id::create("env", this);
    endfunction

    // -------------------------------------------------------------------------
    // 기준 ECC 모델을 Python 골든 벡터로 검사한다.
    //   RTL <-> SV 기준 모델 <-> Python 모델 셋이 서로를 물고 있게 된다.
    //   벡터 : data ecc corrupted_data corrupted_ecc status corrected_data
    // -------------------------------------------------------------------------
    function void start_of_simulation_phase(uvm_phase phase);
        int          fd, n, st, bp, got;
        string       line, msg;
        logic [31:0] data, bad_data, corrected, fx;
        logic [6:0]  ecc, bad_ecc;
        int          exp_st;

        fd = $fopen("ecc_vectors.txt", "r");
        if (fd == 0) begin
            `uvm_warning("REF", "ecc_vectors.txt not found : reference model was NOT checked against the Python model")
            return;
        end
        n = 0;
        while (!$feof(fd)) begin
            if ($fgets(line, fd) == 0) break;
            got = $sscanf(line, "%h %h %h %h %h %h", data, ecc, bad_data, bad_ecc, exp_st, corrected);
            if (got != 6) continue;         // 주석 / 빈 줄
            n++;
            if (aio_ref_model::ecc32(data) !== ecc) begin
                msg = $sformatf("reference encode mismatch : data=%08x python=%02x sv=%02x",
                                data, ecc, aio_ref_model::ecc32(data));
                `uvm_error("REF", msg)
            end
            aio_ref_model::decode(bad_data, bad_ecc, st, fx, bp);
            if ((st != exp_st) || (fx !== corrected)) begin
                msg = $sformatf("reference decode mismatch : data=%08x ecc=%02x python=(%0d,%08x) sv=(%0d,%08x)",
                                bad_data, bad_ecc, exp_st, corrected, st, fx);
                `uvm_error("REF", msg)
            end
        end
        $fclose(fd);
        msg = $sformatf("reference ECC model matches %0d Python golden vectors", n);
        `uvm_info("REF", msg, UVM_NONE)
    endfunction

    task apply_reset();
        cfg.apb_vif.presetn       = 1'b0;
        cfg.bd_vif.write_protect  = 1'b0;
        repeat (5) @(posedge cfg.apb_vif.clk);
        cfg.apb_vif.presetn       = 1'b1;
        repeat (2) @(posedge cfg.apb_vif.clk);
    endtask

    // 파생 테스트가 시퀀스를 고른다
    virtual task run_seq();
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        apply_reset();
        run_seq();
        repeat (50) @(posedge cfg.apb_vif.clk);
        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int               n_err;
        svr   = uvm_report_server::get_server();
        n_err = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);
        if (n_err == 0) `uvm_info("TEST", "UVM TEST PASSED", UVM_NONE)
        else            `uvm_info("TEST", "UVM TEST FAILED", UVM_NONE)
    endfunction
endclass


class aio_smoke_test extends aio_base_test;
    `uvm_component_utils(aio_smoke_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_seq();
        aio_smoke_seq seq;
        seq = aio_smoke_seq::type_id::create("seq");
        seq.start(env.apb.sqr);
    endtask
endclass


class aio_ecc_test extends aio_base_test;
    `uvm_component_utils(aio_ecc_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_seq();
        aio_ecc_seq seq;
        seq = aio_ecc_seq::type_id::create("seq");
        seq.start(env.apb.sqr);
    endtask
endclass


class aio_err_test extends aio_base_test;
    `uvm_component_utils(aio_err_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_seq();
        aio_err_seq seq;
        seq = aio_err_seq::type_id::create("seq");
        seq.start(env.apb.sqr);
    endtask
endclass


class aio_bp_test extends aio_base_test;
    `uvm_component_utils(aio_bp_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_seq();
        aio_bp_seq seq;
        seq = aio_bp_seq::type_id::create("seq");
        seq.start(env.apb.sqr);
    endtask
endclass


class aio_reset_test extends aio_base_test;
    `uvm_component_utils(aio_reset_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_seq();
        aio_reset_seq seq;
        seq = aio_reset_seq::type_id::create("seq");
        seq.start(env.apb.sqr);
    endtask
endclass


class aio_rand_test extends aio_base_test;
    `uvm_component_utils(aio_rand_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_seq();
        aio_rand_seq seq;
        seq = aio_rand_seq::type_id::create("seq");
        seq.start(env.apb.sqr);
    endtask
endclass
