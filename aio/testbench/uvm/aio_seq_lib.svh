// =============================================================================
// aio_seq_lib.svh : 시퀀스 (자극)
//
//   시퀀스는 "무엇을 시킬지" 만 안다. 결과가 맞는지는 스코어보드가 본다.
//   그래서 여기에는 기대값 비교가 하나도 없다.
//
//   aio_base_seq    레지스터 읽기/쓰기, 동작 하나 돌리기 같은 공용 도구
//   aio_smoke_seq   ERASE -> PROGRAM -> READ 한 바퀴
//   aio_ecc_seq     코드워드 40 비트를 하나씩 다 깨 본다 + 2/3 bit + 여러 워드
//   aio_err_seq     잘못된 길이, NAND FAIL, WP#, R/B# 고착, watchdog, 버스 에러
//   aio_bp_seq      DMA backpressure 를 세게 걸고 돌린다
//   aio_reset_seq   동작 도중에 리셋을 건다
//   aio_rand_seq    전부 무작위
// =============================================================================

class aio_base_seq extends uvm_sequence #(apb_item);
    `uvm_object_utils(aio_base_seq)

    aio_env_cfg  cfg;
    logic [31:0] status, corr, uncorr, code;

    localparam logic [31:0] HOST_BASE   = 32'h1000_0000;
    localparam int          BIG_TIMEOUT = 200000;

    function new(string name = "aio_base_seq");
        super.new(name);
    endfunction

    task pre_start();
        if (!uvm_config_db #(aio_env_cfg)::get(m_sequencer, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "aio_env_cfg not found")
    endtask

    // ---------------- 레지스터 ----------------
    task reg_write(logic [11:0] addr, logic [31:0] data);
        apb_item it;
        it = apb_item::type_id::create("it");
        start_item(it);
        it.addr  = addr;
        it.data  = data;
        it.write = 1'b1;
        finish_item(it);
    endtask

    task reg_read(logic [11:0] addr, output logic [31:0] data);
        apb_item it;
        it = apb_item::type_id::create("it");
        start_item(it);
        it.addr  = addr;
        it.data  = '0;
        it.write = 1'b0;
        finish_item(it);
        data = it.data;
    endtask

    // ---------------- 동작 하나 ----------------
    task launch(int op, int row, logic [31:0] host, int words, int timeout = BIG_TIMEOUT);
        reg_write(REG_NAND_ROW, row);
        reg_write(REG_HOST_ADDR, host);
        reg_write(REG_PAGE_WORDS, words);
        reg_write(REG_TIMEOUT, timeout);
        reg_write(REG_CONTROL, (32'h1 << 8) | (op << 1) | 32'h1);   // CLEAR_STATUS + OP + START
    endtask

    task wait_done();
        int polls;
        polls  = 0;
        status = '0;
        while (!status[1]) begin
            reg_read(REG_STATUS, status);
            polls++;
            if (polls > 20000) `uvm_fatal("SEQ", "operation never reached DONE")
        end
    endtask

    // 결과 레지스터를 읽어 둔다 (스코어보드가 이 읽기를 보고 비교한다)
    task collect();
        reg_read(REG_CORR_COUNT, corr);
        reg_read(REG_UNCORR_COUNT, uncorr);
        reg_read(REG_ERROR_CODE, code);
    endtask

    task run_op(int op, int row, logic [31:0] host, int words, int timeout = BIG_TIMEOUT);
        launch(op, row, host, words, timeout);
        wait_done();
        collect();
    endtask

    task do_erase(int row);
        run_op(OP_ERASE, row, HOST_BASE, cfg.max_words);
    endtask

    task do_program(int row, logic [31:0] host, int words);
        fill_host(host, words);
        run_op(OP_PROGRAM, row, host, words);
    endtask

    task do_read(int row, logic [31:0] host, int words);
        run_op(OP_READ, row, host, words);
    endtask

    task do_nand_reset();
        run_op(OP_RESET, 0, HOST_BASE, cfg.max_words);
    endtask

    // ---------------- 도구 ----------------
    task wait_clk(int n);
        repeat (n) @(posedge cfg.apb_vif.clk);
    endtask

    function int row_of(int blk, int page);
        return blk * cfg.pages_per_block + page;
    endfunction

    function logic [31:0] host_slot(int n);
        return HOST_BASE + n * 32'h100;
    endfunction

    function void fill_host(logic [31:0] host, int words);
        for (int i = 0; i < words; i++)
            cfg.host_mem.write(host + 4*i, $urandom());
    endfunction

    // 코드워드 비트 cw_bit (0..39) 를 뒤집는다.  0..31 데이터, 32..38 ECC, 39 는 안 쓰는 비트
    function void flip(int row, int word, int cw_bit);
        cfg.bd_vif.flip_bit(row, BYTES_PER_WORD*word + cw_bit/8, cw_bit % 8);
    endfunction

    task set_wp(bit on);
        cfg.bd_vif.write_protect = on;
        wait_clk(4);                // PHY 가 플롭을 거쳐 WP# 핀에 내보낸다
    endtask
endclass


// -----------------------------------------------------------------------------
class aio_smoke_seq extends aio_base_seq;
    `uvm_object_utils(aio_smoke_seq)

    function new(string name = "aio_smoke_seq");
        super.new(name);
    endfunction

    task body();
        int          row;
        logic [31:0] id;

        row = row_of(1, 3);
        reg_read(REG_ID, id);
        reg_write(REG_IRQ_ENABLE, 1);

        do_erase(row);
        do_read(row, host_slot(8), cfg.max_words);          // 지운 페이지
        do_program(row, host_slot(0), cfg.max_words);
        do_read(row, host_slot(8), cfg.max_words);
    endtask
endclass


// -----------------------------------------------------------------------------
// ECC : 에러를 넣는 위치와 개수를 체계적으로 훑는다
// -----------------------------------------------------------------------------
class aio_ecc_seq extends aio_base_seq;
    `uvm_object_utils(aio_ecc_seq)

    function new(string name = "aio_ecc_seq");
        super.new(name);
    endfunction

    task body();
        int row, w, b1, b2, b3;

        row = row_of(2, 10);
        do_erase(row);
        do_program(row, host_slot(0), cfg.max_words);
        do_read(row, host_slot(8), cfg.max_words);

        // 1) 코드워드 40 비트를 하나씩 : 데이터 32 + ECC 7 + 안 쓰는 비트 1
        for (int b = 0; b < 40; b++) begin
            w = b % cfg.max_words;
            flip(row, w, b);
            do_read(row, host_slot(8), cfg.max_words);
            flip(row, w, b);                                // 되돌린다
        end

        // 2) 같은 워드에 2 bit : 절대 "고쳤다" 고 하면 안 된다
        repeat (24) begin
            w  = $urandom_range(0, cfg.max_words - 1);
            b1 = $urandom_range(0, 38);
            do b2 = $urandom_range(0, 38); while (b2 == b1);
            flip(row, w, b1);
            flip(row, w, b2);
            do_read(row, host_slot(8), cfg.max_words);
            flip(row, w, b1);
            flip(row, w, b2);
        end

        // 3) 같은 워드에 3 bit : SEC-DED 의 한계 밖이다. 1 bit 에러로 오인해서
        //    엉뚱한 비트를 "고칠" 수 있다 (오정정). 기준 모델도 같은 한계를 가지므로
        //    RTL 이 기준 모델과 똑같이 행동하는지를 본다.
        repeat (8) begin
            w  = $urandom_range(0, cfg.max_words - 1);
            b1 = $urandom_range(0, 12);
            b2 = $urandom_range(13, 25);
            b3 = $urandom_range(26, 38);
            flip(row, w, b1); flip(row, w, b2); flip(row, w, b3);
            do_read(row, host_slot(8), cfg.max_words);
            flip(row, w, b1); flip(row, w, b2); flip(row, w, b3);
        end

        // 4) 모든 워드에 1 bit 씩 : 한 페이지에서 max_words 번 정정
        for (int i = 0; i < cfg.max_words; i++) flip(row, i, (i * 7) % 39);
        do_read(row, host_slot(8), cfg.max_words);
        for (int i = 0; i < cfg.max_words; i++) flip(row, i, (i * 7) % 39);

        // 5) 고칠 수 있는 워드와 못 고치는 워드가 한 페이지에 섞인 경우
        flip(row, 1, 3);
        flip(row, 4, 35);                                   // ECC 비트
        flip(row, 7, 0);  flip(row, 7, 31);                 // 2 bit
        flip(row, 9, 10); flip(row, 9, 33);                 // 데이터 1 + ECC 1
        do_read(row, host_slot(8), cfg.max_words);
        flip(row, 1, 3);
        flip(row, 4, 35);
        flip(row, 7, 0);  flip(row, 7, 31);
        flip(row, 9, 10); flip(row, 9, 33);

        // 5b) 한 페이지 안의 (고친 워드 수) x (못 고친 워드 수) 조합 9 가지를 전부 만든다.
        //     커버리지의 x_corr_uncorr 교차가 이 조합을 센다. 무작위로는 잘 안 나오는
        //     조합(정정 0 + 정정 불가 여러 개 등)이 있어서 직접 만든다.
        for (int nc = 0; nc <= 2; nc++) begin
            for (int nu = 0; nu <= 2; nu++) begin
                for (int i = 0; i < nc; i++) flip(row, i, 4 + i);
                for (int i = 0; i < nu; i++) begin
                    flip(row, 8 + i, 1);
                    flip(row, 8 + i, 20);
                end
                do_read(row, host_slot(8), cfg.max_words);
                for (int i = 0; i < nc; i++) flip(row, i, 4 + i);
                for (int i = 0; i < nu; i++) begin
                    flip(row, 8 + i, 1);
                    flip(row, 8 + i, 20);
                end
            end
        end

        // 6) 짧은 읽기 : 앞쪽 워드만 읽으면 뒤쪽 에러는 보이지 않아야 한다
        flip(row, cfg.max_words - 1, 5);
        do_read(row, host_slot(8), 1);
        do_read(row, host_slot(8), cfg.max_words);
        flip(row, cfg.max_words - 1, 5);
    endtask
endclass


// -----------------------------------------------------------------------------
// 예외 경로
// -----------------------------------------------------------------------------
class aio_err_seq extends aio_base_seq;
    `uvm_object_utils(aio_err_seq)

    function new(string name = "aio_err_seq");
        super.new(name);
    endfunction

    task body();
        int          row_a, row_b, row_c, row_d;
        logic [31:0] rd;

        cfg.set_backpressure(0);        // watchdog 시험이 클럭 수에 기대므로 DMA 를 흔들지 않는다
        row_a = row_of(1, 0);
        row_b = row_of(1, 63);
        row_c = row_of(3, 63);          // 마지막 블록의 마지막 페이지
        row_d = row_of(0, 0);
        reg_write(REG_IRQ_ENABLE, 1);

        // ---- 버스 : 없는 주소는 PSLVERR, RO 레지스터에 써도 값이 안 변한다 ----
        reg_read(12'h030, rd);
        reg_write(12'h100, 32'hdead_beef);
        reg_write(REG_ID, 32'h0);
        reg_read(REG_ID, rd);
        reg_write(REG_CORR_COUNT, 32'hffff_ffff);
        reg_read(REG_CORR_COUNT, rd);

        // ---- 잘못된 길이 : NAND 도 DMA 도 움직이면 안 된다 ----
        run_op(OP_PROGRAM, row_a, host_slot(0), 0);
        run_op(OP_READ,    row_a, host_slot(0), cfg.max_words + 1);
        run_op(OP_ERASE,   row_a, host_slot(0), 0);

        // ---- 준비 ----
        do_erase(row_a);
        do_erase(row_c);
        do_erase(row_d);
        do_program(row_a, host_slot(0), cfg.max_words);

        // ---- NAND 가 status 로 FAIL 을 보고 ----
        cfg.bd_vif.set_fail_next_prog();
        do_program(row_b, host_slot(1), cfg.max_words);     // 실패해야 한다
        do_program(row_b, host_slot(1), cfg.max_words);     // 다시 하면 된다
        cfg.bd_vif.set_fail_next_erase();
        do_erase(row_c);                                    // 실패해야 한다
        do_erase(row_c);

        // ---- WP# : 쓰기와 지우기만 막히고 읽기는 된다 ----
        set_wp(1);
        do_program(row_c, host_slot(2), cfg.max_words);
        do_erase(row_a);
        do_read(row_a, host_slot(8), cfg.max_words);
        do_nand_reset();
        set_wp(0);
        do_program(row_c, host_slot(2), cfg.max_words);
        do_read(row_c, host_slot(8), cfg.max_words);

        // ---- R/B# 가 안 돌아온다 : PHY 가 포기하고 fail. RESET(FFh) 으로 되살린다 ----
        cfg.bd_vif.set_stuck_busy(1);
        do_read(row_a, host_slot(8), cfg.max_words);
        cfg.bd_vif.set_stuck_busy(0);
        do_nand_reset();
        do_read(row_a, host_slot(8), cfg.max_words);

        cfg.bd_vif.set_stuck_busy(1);
        do_program(row_d, host_slot(3), cfg.max_words);     // 셀은 그대로여야 한다
        cfg.bd_vif.set_stuck_busy(0);
        do_nand_reset();

        cfg.bd_vif.set_stuck_busy(1);
        do_erase(row_a);
        cfg.bd_vif.set_stuck_busy(0);
        do_nand_reset();

        cfg.bd_vif.set_stuck_busy(1);
        do_nand_reset();                                    // RESET 자체가 안 끝나는 경우
        cfg.bd_vif.set_stuck_busy(0);
        do_nand_reset();
        do_read(row_a, host_slot(8), cfg.max_words);        // 데이터는 살아 있다

        // ---- watchdog 이 데이터 스트림 한가운데서 터진다 ----
        //   READ    : host memory 를 건드리지 않고 끝나야 한다
        //   PROGRAM : 10h 가 나가기 전이므로 셀이 하나도 바뀌면 안 된다 (원자성)
        //   둘 다 PHY 가 스스로 FFh 로 NAND 를 정리해야 한다
        cfg.expect_watchdog = 1;
        run_op(OP_READ, row_a, host_slot(8), cfg.max_words, 500);
        wait_clk(cfg.stall_cycles + 400);
        do_read(row_a, host_slot(8), cfg.max_words);

        cfg.expect_watchdog = 1;
        fill_host(host_slot(3), cfg.max_words);
        run_op(OP_PROGRAM, row_d, host_slot(3), cfg.max_words, 400);
        wait_clk(cfg.stall_cycles + 400);
        do_read(row_d, host_slot(8), cfg.max_words);        // 여전히 지운 상태

        // ---- 동작 중에 START 를 또 쓴다 : 무시돼야 한다 ----
        launch(OP_READ, row_a, host_slot(8), cfg.max_words);
        reg_write(REG_CONTROL, (OP_ERASE << 1) | 32'h1);
        wait_done();
        collect();
        reg_read(REG_CONTROL, rd);

        // ---- CLEAR_STATUS 만 쓰기, irq enable 껐다 켜기 ----
        reg_write(REG_CONTROL, 32'h1 << 8);
        reg_read(REG_STATUS, rd);
        do_read(row_a, host_slot(8), cfg.max_words);
        reg_write(REG_IRQ_ENABLE, 0);
        reg_read(REG_STATUS, rd);
        reg_write(REG_IRQ_ENABLE, 1);
        reg_read(REG_STATUS, rd);
    endtask
endclass


// -----------------------------------------------------------------------------
// backpressure : DMA 가 거의 안 받아 주는 상황
// -----------------------------------------------------------------------------
class aio_bp_seq extends aio_base_seq;
    `uvm_object_utils(aio_bp_seq)

    function new(string name = "aio_bp_seq");
        super.new(name);
    endfunction

    task body();
        int row;
        int level [4] = '{2, 0, 1, 2};

        do_erase(row_of(0, 0));
        foreach (level[i]) begin
            row = row_of(0, i);
            cfg.set_backpressure(level[i]);
            do_program(row, host_slot(i), cfg.max_words);
            do_read(row, host_slot(8 + i), cfg.max_words);
            do_read(row, host_slot(8 + i), 1);
        end
        cfg.set_backpressure(2);
        do_erase(row_of(0, 0));
        do_nand_reset();
    endtask
endclass


// -----------------------------------------------------------------------------
// 동작 도중 리셋
// -----------------------------------------------------------------------------
class aio_reset_seq extends aio_base_seq;
    `uvm_object_utils(aio_reset_seq)

    function new(string name = "aio_reset_seq");
        super.new(name);
    endfunction

    task pulse_reset();
        cfg.apb_vif.presetn = 1'b0;
        wait_clk(3);
        cfg.apb_vif.presetn = 1'b1;
        wait_clk(3);
    endtask

    task body();
        int          row, row2;
        logic [31:0] rd;

        cfg.set_backpressure(0);
        row  = row_of(1, 5);
        row2 = row_of(1, 6);
        do_erase(row);
        do_program(row, host_slot(0), cfg.max_words);

        // 1) READ 의 데이터 구간 한가운데
        launch(OP_READ, row, host_slot(8), cfg.max_words);
        wait_clk(420);
        pulse_reset();
        reg_read(REG_STATUS, rd);                           // 리셋 값이어야 한다
        reg_read(REG_TIMEOUT, rd);
        do_read(row, host_slot(8), cfg.max_words);          // PHY 가 FFh 부터 다시 하고, 데이터는 멀쩡하다

        // 2) PROGRAM 의 DMA 구간 (NAND 에는 아직 아무것도 안 나갔다)
        fill_host(host_slot(1), cfg.max_words);
        launch(OP_PROGRAM, row2, host_slot(1), cfg.max_words);
        wait_clk(20);
        pulse_reset();
        do_read(row2, host_slot(8), cfg.max_words);         // 지운 상태 그대로

        // 3) 쉬는 중에 리셋
        pulse_reset();
        do_program(row2, host_slot(1), cfg.max_words);
        do_read(row2, host_slot(8), cfg.max_words);
    endtask
endclass


// -----------------------------------------------------------------------------
// 무작위 : 동작 / 주소 / 길이 / backpressure / 에러 주입을 전부 섞는다
// -----------------------------------------------------------------------------
class aio_rand_seq extends aio_base_seq;
    `uvm_object_utils(aio_rand_seq)

    int n_ops = 80;
    bit used [int];             // 이 시퀀스가 PROGRAM 한 적이 있는 row (자극을 고르는 데만 쓴다)

    function new(string name = "aio_rand_seq");
        super.new(name);
    endfunction

    function int pick_page();
        case ($urandom_range(0, 3))
            0:       return 0;
            1:       return cfg.pages_per_block - 1;
            default: return $urandom_range(0, cfg.pages_per_block - 1);
        endcase
    endfunction

    function int pick_words();
        case ($urandom_range(0, 3))
            0:       return 1;
            1:       return cfg.max_words;
            default: return $urandom_range(1, cfg.max_words);
        endcase
    endfunction

    function void forget_block(int row);
        int r0;
        r0 = (row / cfg.pages_per_block) * cfg.pages_per_block;
        for (int i = 0; i < cfg.pages_per_block; i++)
            if (used.exists(r0 + i)) used.delete(r0 + i);
    endfunction

    task body();
        int          pick, row, words, w, b1, b2;
        logic [31:0] host;

        reg_write(REG_IRQ_ENABLE, $urandom_range(0, 1));

        repeat (n_ops) begin
            cfg.set_backpressure($urandom_range(0, 2));
            row   = row_of($urandom_range(0, cfg.blocks - 1), pick_page());
            words = pick_words();
            host  = HOST_BASE + $urandom_range(0, 63) * 32'h40;
            pick  = $urandom_range(0, 99);

            if (pick < 40) begin
                // PROGRAM : 대개는 지운 페이지에, 열 번에 한 번은 일부러 덮어쓴다
                if (used.exists(row) && ($urandom_range(0, 9) != 0)) begin
                    do_erase(row);
                    forget_block(row);
                end
                do_program(row, host, words);
                used[row] = 1;
            end else if (pick < 85) begin
                // READ : 절반은 그대로, 나머지는 셀을 깨고 읽는다 (깬 셀은 ERASE 때까지 남는다)
                case ($urandom_range(0, 9))
                    5, 6, 7: flip(row, $urandom_range(0, words - 1), $urandom_range(0, 39));
                    8: begin
                        w  = $urandom_range(0, words - 1);
                        b1 = $urandom_range(0, 38);
                        do b2 = $urandom_range(0, 38); while (b2 == b1);
                        flip(row, w, b1);
                        flip(row, w, b2);
                    end
                    9: repeat ($urandom_range(2, 6))
                           flip(row, $urandom_range(0, words - 1), $urandom_range(0, 39));
                    default: ;
                endcase
                do_read(row, host, words);
            end else if (pick < 95) begin
                do_erase(row);
                forget_block(row);
            end else begin
                do_nand_reset();
            end
        end
    endtask
endclass
