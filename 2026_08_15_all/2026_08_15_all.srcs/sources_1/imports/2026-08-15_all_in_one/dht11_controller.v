`timescale 1ns / 1ps

//=====================================================================
// DHT11 single-wire controller
//
// The DATA pin is open-drain: the FPGA drives only Low during START and
// releases the line in every other state.  A 4.7~5.1 kohm external pull-up
// to 3.3 V is required on the board; the XDC PULLUP is only a weak backup.
//=====================================================================
module dht11_controller #(
    parameter integer TICK_1US        = 100,
    // Datasheet requirements: no command for one second after power-up,
    // and at least one second between sampling requests.
    parameter integer SAMPLE_GUARD_US = 1_000_000
) (
    input             clk,
    input             reset,
    input             start,
    output     [15:0] humidity,     // {integral, decimal}
    output     [15:0] temperature,  // {integral, decimal}
    output            done,
    output            valid,
    // 진단용 진행도. 측정을 시작할 때 0 으로 지워지고, 프레임이 진행되면서
    // 도달한 단계까지 1 로 채워진다. 어디서 끊겼는지 그대로 보인다.
    //   [0] 측정 시작됨 (start 가 FSM 에 접수됨. 1초 가드 통과)
    //   [1] START 를 놓았을 때 라인이 High 로 복귀함  <- 풀업/배선 확인용
    //   [2] 센서가 응답 Low 를 냄 (센서가 살아있음)
    //   [3] 싱크 80us Low + 80us High 통과, 데이터 수신 시작
    //   [4] 40비트 전부 수신 완료
    //   [5] 체크섬 통과
    output      [5:0] dbg_step,
    inout             dht11_io
);
    localparam [2:0] IDLE  = 3'd0,
                     START = 3'd1,
                     WAIT  = 3'd2,
                     SYNC  = 3'd3,
                     DATA  = 3'd4,
                     STOP  = 3'd5;

    localparam integer BIT_THRESHOLD_US    = 40;
    localparam integer START_LOW_US         = 19_000;
    localparam integer START_LOW_LIMIT      = START_LOW_US - 1;
    localparam integer RESPONSE_TIMEOUT_US  = 200;
    localparam integer DATA_TIMEOUT_US      = 200;
    localparam integer END_TIMEOUT_US       = 200;
    localparam integer GUARD_WIDTH =
        (SAMPLE_GUARD_US < 2) ? 1 : $clog2(SAMPLE_GUARD_US + 1);
    localparam integer GUARD_LIMIT =
        (SAMPLE_GUARD_US < 1) ? 0 : SAMPLE_GUARD_US - 1;

    wire tick_us;

    reg [20:0] count_reg, count_next;
    reg [2:0] c_state, n_state;
    reg sync_phase_reg, sync_phase_next;  // 0=response Low, 1=response High
    reg data_phase_reg, data_phase_next;  // 0=bit Low, 1=measure bit High
    reg wait_high_seen_reg, wait_high_seen_next;
    reg request_pending_reg, request_pending_next;
    reg [39:0] data_reg, data_next;
    reg [5:0] bit_cnt_reg, bit_cnt_next;
    reg done_reg, done_next;
    reg valid_reg, valid_next;
    reg [5:0] dbg_reg, dbg_next;

    // The sensor output is asynchronous to clk.  Preserve the two flops and
    // place them together so Vivado treats this as a CDC synchronizer.
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] io_sync;
    wire io_in = io_sync[1];

    reg [GUARD_WIDTH-1:0] guard_count_reg;
    reg sample_ready_reg;
    wire start_requested = start | request_pending_reg;
    wire accept_start =
        (c_state == IDLE) && sample_ready_reg && start_requested;
    wire [7:0] checksum_calc = data_reg[39:32] + data_reg[31:24] +
                               data_reg[23:16] + data_reg[15:8];

    dht_tick_1us #(
        .F_COUNT(TICK_1US)
    ) U_TICK_GEN_1US (
        .clk   (clk),
        .reset (reset),
        .o_tick(tick_us)
    );

    // True open-drain behavior: never drive a logic High onto the DHT bus.
    assign dht11_io    = (c_state == START) ? 1'b0 : 1'bz;
    assign humidity    = {data_reg[39:32], data_reg[31:24]};
    assign temperature = {data_reg[23:16], data_reg[15:8]};
    assign done        = done_reg;
    assign valid       = valid_reg;
    assign dbg_step    = dbg_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state             <= IDLE;
            count_reg           <= 0;
            sync_phase_reg      <= 1'b0;
            data_phase_reg      <= 1'b0;
            wait_high_seen_reg  <= 1'b0;
            request_pending_reg <= 1'b0;
            data_reg            <= 40'b0;
            bit_cnt_reg         <= 0;
            done_reg            <= 1'b0;
            valid_reg           <= 1'b0;
            dbg_reg             <= 6'b0;
            io_sync             <= 2'b11;
        end else begin
            c_state             <= n_state;
            count_reg           <= count_next;
            sync_phase_reg      <= sync_phase_next;
            data_phase_reg      <= data_phase_next;
            wait_high_seen_reg  <= wait_high_seen_next;
            request_pending_reg <= request_pending_next;
            data_reg            <= data_next;
            bit_cnt_reg         <= bit_cnt_next;
            done_reg            <= done_next;
            valid_reg           <= valid_next;
            dbg_reg             <= dbg_next;
            io_sync             <= {io_sync[0], dht11_io};
        end
    end

    // One counter implements both the initial one-second stabilization time
    // and the minimum interval from one accepted start to the next.
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            guard_count_reg  <= 0;
            sample_ready_reg <= (SAMPLE_GUARD_US == 0);
        end else if (accept_start) begin
            guard_count_reg  <= 0;
            sample_ready_reg <= (SAMPLE_GUARD_US == 0);
        end else if (!sample_ready_reg && tick_us) begin
            if (guard_count_reg >= GUARD_LIMIT) begin
                sample_ready_reg <= 1'b1;
            end else begin
                guard_count_reg <= guard_count_reg + 1'b1;
            end
        end
    end

    always @(*) begin
        n_state             = c_state;
        count_next          = count_reg;
        sync_phase_next     = sync_phase_reg;
        data_phase_next     = data_phase_reg;
        wait_high_seen_next = wait_high_seen_reg;
        request_pending_next = request_pending_reg;
        data_next           = data_reg;
        bit_cnt_next        = bit_cnt_reg;
        done_next           = 1'b0;
        valid_next          = valid_reg;
        dbg_next            = dbg_reg;

        case (c_state)
            IDLE: begin
                count_next          = 0;
                sync_phase_next     = 1'b0;
                data_phase_next     = 1'b0;
                wait_high_seen_next = 1'b0;

                // If start arrives during the one-second guard, remember it
                // and begin automatically as soon as the guard expires.
                if (start) request_pending_next = 1'b1;
                if (accept_start) begin
                    request_pending_next = 1'b0;
                    valid_next = 1'b0;
                    dbg_next = 6'b000001;  // 새 측정 시작 : 진행도 초기화
                    n_state = START;
                end
            end

            START: begin
                if (tick_us) begin
                    if (count_reg >= START_LOW_LIMIT) begin
                        n_state = WAIT;
                        count_next = 0;
                        wait_high_seen_next = 1'b0;
                    end else begin
                        count_next = count_reg + 1'b1;
                    end
                end
            end

            WAIT: begin
                if (tick_us) count_next = count_reg + 1'b1;

                // First verify that releasing START really raised the bus.
                // Only a subsequent falling level is a valid DHT response.
                if (!wait_high_seen_reg && io_in == 1'b1) begin
                    wait_high_seen_next = 1'b1;
                    dbg_next[1] = 1'b1;  // 라인이 High 로 복귀함
                    count_next = 0;
                end else if (wait_high_seen_reg && io_in == 1'b0) begin
                    count_next = 0;
                    sync_phase_next = 1'b0;
                    dbg_next[2] = 1'b1;  // 센서가 응답 Low 를 냄
                    n_state = SYNC;
                end else if (count_reg >= RESPONSE_TIMEOUT_US) begin
                    done_next = 1'b1;
                    valid_next = 1'b0;
                    n_state = IDLE;
                end
            end

            SYNC: begin
                if (tick_us) count_next = count_reg + 1'b1;

                if (sync_phase_reg == 1'b0) begin
                    // Sensor response Low should end after about 80 us.
                    if (io_in == 1'b1) begin
                        count_next = 0;
                        sync_phase_next = 1'b1;
                    end else if (count_reg >= RESPONSE_TIMEOUT_US) begin
                        done_next = 1'b1;
                        valid_next = 1'b0;
                        n_state = IDLE;
                    end
                end else begin
                    // The falling edge after response High starts bit 39 Low.
                    if (io_in == 1'b0) begin
                        count_next = 0;
                        sync_phase_next = 1'b0;
                        data_phase_next = 1'b0;
                        data_next = 40'b0;
                        bit_cnt_next = 0;
                        dbg_next[3] = 1'b1;  // 싱크 통과, 데이터 수신 시작
                        n_state = DATA;
                    end else if (count_reg >= RESPONSE_TIMEOUT_US) begin
                        done_next = 1'b1;
                        valid_next = 1'b0;
                        n_state = IDLE;
                    end
                end
            end

            DATA: begin
                if (tick_us) count_next = count_reg + 1'b1;

                if (data_phase_reg == 1'b0) begin
                    // Every data bit starts with about 50 us Low.
                    if (io_in == 1'b1) begin
                        count_next = 0;
                        data_phase_next = 1'b1;
                    end else if (count_reg >= DATA_TIMEOUT_US) begin
                        done_next = 1'b1;
                        valid_next = 1'b0;
                        n_state = IDLE;
                    end
                end else begin
                    // 26~28 us High means 0; about 70 us High means 1.
                    if (io_in == 1'b0) begin
                        data_next = {
                            data_reg[38:0],
                            (count_reg > BIT_THRESHOLD_US) ? 1'b1 : 1'b0
                        };
                        bit_cnt_next = bit_cnt_reg + 1'b1;
                        count_next = 0;
                        data_phase_next = 1'b0;
                        if (bit_cnt_reg == 39) begin
                            dbg_next[4] = 1'b1;  // 40비트 전부 수신
                            n_state = STOP;
                        end
                    end else if (count_reg >= DATA_TIMEOUT_US) begin
                        done_next = 1'b1;
                        valid_next = 1'b0;
                        n_state = IDLE;
                    end
                end
            end

            STOP: begin
                if (tick_us) count_next = count_reg + 1'b1;

                // DHT11 keeps the line Low for about 50 us after bit 0.
                // Keep releasing the bus until the pull-up restores High.
                if (io_in == 1'b1) begin
                    done_next = 1'b1;
                    valid_next = (data_reg[7:0] == checksum_calc);
                    dbg_next[5] = (data_reg[7:0] == checksum_calc);
                    count_next = 0;
                    n_state = IDLE;
                end else if (count_reg >= END_TIMEOUT_US) begin
                    done_next = 1'b1;
                    valid_next = 1'b0;
                    n_state = IDLE;
                end
            end

            default: begin
                n_state = IDLE;
                count_next = 0;
                request_pending_next = 1'b0;
                done_next = 1'b1;
                valid_next = 1'b0;
            end
        endcase
    end

endmodule


//---------------------------------------------------------------------
// dht11_controller 전용 1us tick.
//   [기존] 공용 tick_gen_1us 를 run_stop=1, clear=0 으로 묶어서 썼다.
//   [변경] 여기서는 항상 자유 구동이라 그 두 포트를 아예 뺐다.
//          (sr04 쪽은 위상 리셋이 필요해서 run_stop/clear 를 유지한다)
//---------------------------------------------------------------------
module dht_tick_1us #(
    parameter F_COUNT = 100  // 100MHz -> 1us
) (
    input      clk,
    input      reset,
    output reg o_tick
);
    reg [$clog2(F_COUNT)-1:0] clk_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            clk_counter <= 0;
            o_tick      <= 1'b0;
        end else begin
            o_tick <= 1'b0;
            if (clk_counter == (F_COUNT - 1)) begin
                clk_counter <= 0;
                o_tick      <= 1'b1;
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
    end
endmodule
