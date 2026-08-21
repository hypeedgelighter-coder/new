`timescale 1ns / 1ps


module dht (
    input clk,
    input reset,
    input start,
    output [15:0] humidity,
    output [15:0] temperature,
    output done,
    output valid,
    inout dht11_io
);

    tick_gen U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .o_tick(tick_us)
    );

    localparam BIT_THRESHOLD = 35;  // High 폭 0/1 판정 임계값(us): 26~28us=0, 약70us=1

    reg [$clog2(18000)-1:0] count_next, count_reg;
    reg [2:0] n_state, c_state;
    parameter [2:0] IDLE = 0, START = 1, WAIT = 2, SYNC = 3, DATA = 4, STOP = 5;
    reg io_control, dht11_io_reg, dht11_io_next;
    reg
        sync_phase_reg,
        sync_phase_next;  // SYNC: 0 = 80us Low(싱크1), 1 = 80us High(싱크2)
    reg
        data_phase_reg,
        data_phase_next;  // DATA: 0 = 50us Low 대기, 1 = High 폭 측정
    reg [39:0] data_reg, data_next;
    reg [5:0] bit_cnt_reg, bit_cnt_next;
    reg done_reg, done_next;
    reg valid_reg, valid_next;

    // dht11_io는 센서가 비동기로 흔드는 입력이라 메타스테이블 방지를 위해 2단 동기화 후 사용
    reg [1:0] io_sync;
    wire io_in = io_sync[1];

    assign dht11_io = (io_control) ? (dht11_io_reg) : 1'bz;
    assign humidity = {
        data_reg[39:32], data_reg[31:24]
    };  // {정수부, 소수부}
    assign temperature = {data_reg[23:16], data_reg[15:8]};
    assign done = done_reg;
    assign valid = valid_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            count_reg <= 0;
            dht11_io_reg <= 1;
            sync_phase_reg <= 0;
            data_phase_reg <= 0;
            data_reg <= 0;
            bit_cnt_reg <= 0;
            done_reg <= 0;
            valid_reg <= 0;
            io_sync <= 2'b11;
        end else begin
            c_state <= n_state;
            count_reg <= count_next;
            dht11_io_reg <= dht11_io_next;
            sync_phase_reg <= sync_phase_next;
            data_phase_reg <= data_phase_next;
            data_reg <= data_next;
            bit_cnt_reg <= bit_cnt_next;
            done_reg <= done_next;
            valid_reg <= valid_next;
            io_sync <= {io_sync[0], dht11_io};
        end
    end

    always @(*) begin
        n_state = c_state;
        count_next = count_reg;
        sync_phase_next = sync_phase_reg;
        data_phase_next = data_phase_reg;
        data_next = data_reg;
        bit_cnt_next = bit_cnt_reg;
        dht11_io_next = dht11_io_reg;
        done_next = 0;  // done은 1클럭짜리 펄스
        valid_next = valid_reg;  // 다음 측정 끝날 때까지 유지
        io_control = 1;
        case (c_state)
            IDLE: begin
                io_control = 1;
                dht11_io_next = 1;
                count_next = 0;
                sync_phase_next = 0;
                if (start) begin
                    n_state = START;
                end else n_state = c_state;
            end

            START: begin
                io_control = 1;
                dht11_io_next = 0;
                if (count_reg == 19_000) begin
                    n_state = WAIT;
                    count_next = 0;
                end else if (tick_us) begin
                    count_next = count_reg + 1;
                end
            end
            WAIT: begin
                io_control = 0;
                if (tick_us) count_next = count_reg + 1;
                if (count_reg > 20) begin
                    if (io_in == 0) begin
                        // 센서가 라인을 Low로 당김 = 80us 응답(싱크1) 시작
                        count_next = 0;
                        sync_phase_next = 0;
                        n_state = SYNC;
                    end
                end
            end
            SYNC: begin
                io_control = 0;
                if (tick_us) begin
                    count_next = count_reg + 1;
                    if (sync_phase_reg == 0) begin
                        // 싱크1: 80us Low 구간
                        if (count_reg == 80) begin
                            count_next = 0;
                            sync_phase_next = 1;
                        end
                    end else begin
                        // 싱크2: 80us High 구간, 끝나면 DATA로 진입
                        if (count_reg == 80) begin
                            count_next = 0;
                            sync_phase_next = 0;
                            data_phase_next = 0;
                            data_next = 0;
                            bit_cnt_next = 0;
                            n_state = DATA;
                        end
                    end
                end
            end

            DATA: begin
                io_control = 0;
                if (tick_us) count_next = count_reg + 1;
                if (data_phase_reg == 0) begin
                    // 비트 시작 50us Low 구간, 라인이 다시 High로 올라오길 대기
                    if (io_in == 1) begin
                        count_next = 0;
                        data_phase_next = 1;
                    end
                end else begin
                    // High 폭 측정 구간, 라인이 다시 Low로 떨어지면 그 폭으로 0/1 판정
                    if (io_in == 0) begin
                        data_next = {
                            data_reg[38:0],
                            (count_reg > BIT_THRESHOLD) ? 1'b1 : 1'b0
                        };
                        bit_cnt_next = bit_cnt_reg + 1;
                        count_next = 0;
                        data_phase_next = 0;
                        if (bit_cnt_reg == 39) begin
                            n_state = STOP;
                        end
                    end
                end
            end

            STOP: begin
                io_control = 1;
                dht11_io_next = 1;
                done_next = 1;
                // 체크섬: data_reg[7:0]이 앞 4바이트 합과 같은지 검증
                valid_next = (data_reg[7:0] == (data_reg[39:32] + data_reg[31:24] +
                                                 data_reg[23:16] + data_reg[15:8]));
                n_state = IDLE;
            end

        endcase

    end



endmodule

module tick_gen (
    input clk,
    input reset,
    output reg o_tick
);


    reg [$clog2(100)-1:0] clk_counter;

    always @(posedge clk, posedge reset)
        if (reset) begin
            clk_counter <= 0;
            o_tick <= 0;
        end else begin
            clk_counter <= clk_counter + 1;
            if (clk_counter == (100 - 1)) begin
                clk_counter <= 0;
                o_tick <= 1;
            end else begin
                o_tick <= 0;
            end
        end


endmodule
