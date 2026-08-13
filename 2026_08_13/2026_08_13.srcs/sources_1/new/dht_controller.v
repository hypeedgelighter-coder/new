`timescale 1ns / 1ps



module dht_controller (
    input clk,
    input reset,
    input start,
    output [15:0] humidity,
    output [15:0] temperature,
    output done,
    output valid,
    inout dht11_io

);


    localparam [2:0] IDLE = 0, START = 1, WAIT = 2, SYNC = 3, DATA = 4, STOP = 5;

    // WAIT: 규격은 20~40us지만 여유를 두고 100us 안에 응답 없으면 IDLE로 복귀(센서 미응답 대비)
    localparam WAIT_TIMEOUT = 100;
    // bit 판정 임계값(us): High가 26~28us=0, ~70us=1 이므로 그 사이 아무 값이나 안전
    localparam BIT_THRESHOLD = 35;

    reg io_control;
    reg dht11_io_reg, dht11_io_next;
    reg [2:0] c_state, n_state;
    reg [$clog2(19_000)-1:0] count_next, count_reg;

    reg [5:0] bit_cnt_reg, bit_cnt_next;
    reg [39:0] data_reg, data_next;
    reg done_reg, done_next;
    reg valid_reg, valid_next;
    reg sync_phase_reg, sync_phase_next;  // SYNC: 0=Low구간 대기, 1=High구간 대기
    reg bit_phase_reg, bit_phase_next;  // DATA: 1=50us Low 대기, 0=High 폭 측정중

    // dht11_io는 비동기 입력이므로 2단 동기화 후 edge 검출
    reg  [1:0] in_sync;
    reg        in_prev;

    wire       in_now = in_sync[1];
    wire       fall_edge = in_prev & ~in_now;
    wire       rise_edge = ~in_prev & in_now;

    assign dht11_io = (io_control) ? (dht11_io_reg) : 1'bz;

    assign humidity = {data_reg[39:32], data_reg[31:24]};  // {정수부, 소수부}
    assign temperature = {data_reg[23:16], data_reg[15:8]};
    assign done = done_reg;
    assign valid = valid_reg;

    wire w_tick;

    tick_gen U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .o_tick(w_tick)
    );

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            dht11_io_reg <= 1;
            count_reg <= 0;
            bit_cnt_reg <= 0;
            data_reg <= 0;
            done_reg <= 0;
            valid_reg <= 0;
            sync_phase_reg <= 0;
            bit_phase_reg <= 0;
            in_sync <= 2'b11;
            in_prev <= 1'b1;
        end else begin
            c_state <= n_state;
            dht11_io_reg <= dht11_io_next;
            count_reg <= count_next;
            bit_cnt_reg <= bit_cnt_next;
            data_reg <= data_next;
            done_reg <= done_next;
            valid_reg <= valid_next;
            sync_phase_reg <= sync_phase_next;
            bit_phase_reg <= bit_phase_next;
            in_sync <= {in_sync[0], dht11_io};
            in_prev <= in_sync[1];
        end
    end

    always @(*) begin
        n_state = c_state;
        dht11_io_next = dht11_io_reg;
        io_control = 1;
        count_next = count_reg;
        bit_cnt_next = bit_cnt_reg;
        data_next = data_reg;
        done_next = 1'b0;  // done은 1클럭짜리 펄스
        valid_next = valid_reg;  // 다음 측정 끝날 때까지 유지
        sync_phase_next = sync_phase_reg;
        bit_phase_next = bit_phase_reg;

        case (c_state)
            IDLE: begin
                dht11_io_next = 1;
                io_control = 1;
                count_next = 0;
                bit_cnt_next = 0;
                sync_phase_next = 0;
                bit_phase_next = 0;
                if (start) begin
                    n_state = START;
                end
            end

            START: begin
                dht11_io_next = 0;
                io_control = 1;
                //18ms
                if (w_tick) begin
                    count_next = count_reg + 1;
                    if (count_reg == 18_000) begin
                        count_next = 0;
                        n_state = WAIT;
                    end
                end
            end

            WAIT: begin
                io_control = 0;
                if (w_tick) begin
                    count_next = count_reg + 1;
                end
                if (fall_edge) begin
                    // 센서가 선을 Low로 당김 = 80us 응답 시작
                    count_next = 0;
                    sync_phase_next = 0;
                    n_state = SYNC;
                end else if (count_reg >= WAIT_TIMEOUT) begin
                    n_state = IDLE;
                end
            end

            SYNC: begin
                io_control = 0;
                if (sync_phase_reg == 0) begin
                    // 80us Low 구간: rising edge 오면 High 구간 시작
                    if (rise_edge) sync_phase_next = 1;
                end else begin
                    // 80us High 구간: falling edge = 첫 비트의 50us Low 시작
                    if (fall_edge) begin
                        bit_cnt_next   = 0;
                        data_next      = 0;
                        bit_phase_next = 1;
                        n_state        = DATA;
                    end
                end
            end

            DATA: begin
                io_control = 0;
                if (bit_phase_reg == 1) begin
                    // 비트 시작 50us Low 구간, High 시작(rising edge) 대기
                    if (rise_edge) begin
                        count_next     = 0;
                        bit_phase_next = 0;
                    end
                end else begin
                    // High 구간 폭 측정
                    if (w_tick) count_next = count_reg + 1;
                    if (fall_edge) begin
                        data_next = {data_reg[38:0], (count_reg > BIT_THRESHOLD) ? 1'b1 : 1'b0};
                        bit_cnt_next   = bit_cnt_reg + 1;
                        bit_phase_next = 1;
                        if (bit_cnt_reg == 39) begin
                            n_state = STOP;
                        end
                    end
                end
            end

            STOP: begin
                io_control = 0;
                done_next  = 1'b1;
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
