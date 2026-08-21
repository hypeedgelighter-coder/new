`timescale 1ns / 1ps

//=====================================================================
// HC-SR04 controller
//
// - Generates an 11 us trigger pulse (10 us minimum plus timing margin).
// - Measures only a synchronized echo rising-to-falling pulse.
// - A missing/stuck echo is reported as valid=0 and distance=0; it is not
//   clamped to 400 cm.
//=====================================================================
module sr04_controller #(
    parameter integer TICK_1US = 100
) (
    input            clk,
    input            reset,
    input            start,
    input            echo,
    output           done,
    output           valid,
    output           trigger,
    output     [8:0] distance
);
    localparam [2:0] IDLE      = 3'd0,
                     TRIGGER   = 3'd1,
                     WAIT_RISE = 3'd2,
                     MEASURE   = 3'd3,
                     FINISH    = 3'd4;

    localparam integer TRIGGER_US      = 11;
    localparam integer WAIT_TIMEOUT_US = 30_000;
    localparam integer MIN_ECHO_US     = 100;
    localparam integer MAX_ECHO_US     = 23_200;

    wire tick_us;
    reg [2:0] state_reg, state_next;
    reg [15:0] us_count_reg, us_count_next;
    reg [8:0] distance_reg;
    reg valid_reg;

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] echo_sync;
    reg echo_prev;
    wire echo_in   = echo_sync[1];
    wire echo_rise = echo_in & ~echo_prev;
    wire echo_fall = ~echo_in & echo_prev;

    // count / 58, implemented as count * 1130 / 65536 with rounding.
    // This avoids a long combinational divider at 100 MHz.
    wire [31:0] distance_scaled =
        (us_count_reg * 16'd1130) + 32'd32768;
    wire [8:0] distance_calc = distance_scaled[24:16];

    tick_gen_1us #(
        .F_COUNT(TICK_1US)
    ) U_TICK_GEN_1US (
        .clk     (clk),
        .reset   (reset),
        // Reset the divider phase in IDLE.  Otherwise a free-running tick
        // could make the trigger pulse slightly shorter than the minimum.
        .run_stop(state_reg != IDLE),
        .clear   (state_reg == IDLE),
        .o_tick  (tick_us)
    );

    assign trigger  = (state_reg == TRIGGER);
    assign done     = (state_reg == FINISH);
    assign valid    = valid_reg;
    assign distance = distance_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state_reg     <= IDLE;
            us_count_reg  <= 0;
            distance_reg  <= 0;
            valid_reg     <= 1'b0;
            echo_sync     <= 2'b00;
            echo_prev     <= 1'b0;
        end else begin
            state_reg    <= state_next;
            us_count_reg <= us_count_next;
            echo_sync    <= {echo_sync[0], echo};
            echo_prev    <= echo_in;

            // A new request clears the previous result immediately.
            if (state_reg == IDLE && start) begin
                distance_reg <= 0;
                valid_reg    <= 1'b0;
            end

            if (state_reg == WAIT_RISE &&
                us_count_reg >= WAIT_TIMEOUT_US && !echo_rise) begin
                distance_reg <= 0;
                valid_reg    <= 1'b0;
            end

            if (state_reg == MEASURE) begin
                if (echo_fall) begin
                    if (us_count_reg >= MIN_ECHO_US &&
                        us_count_reg <= MAX_ECHO_US) begin
                        distance_reg <= distance_calc;
                        valid_reg    <= 1'b1;
                    end else begin
                        distance_reg <= 0;
                        valid_reg    <= 1'b0;
                    end
                end else if (us_count_reg >= MAX_ECHO_US) begin
                    distance_reg <= 0;
                    valid_reg    <= 1'b0;
                end
            end
        end
    end

    always @(*) begin
        state_next    = state_reg;
        us_count_next = us_count_reg;

        case (state_reg)
            IDLE: begin
                us_count_next = 0;
                if (start) state_next = TRIGGER;
            end

            TRIGGER: begin
                if (tick_us) begin
                    if (us_count_reg >= (TRIGGER_US - 1)) begin
                        us_count_next = 0;
                        state_next = WAIT_RISE;
                    end else begin
                        us_count_next = us_count_reg + 1'b1;
                    end
                end
            end

            WAIT_RISE: begin
                if (echo_rise) begin
                    us_count_next = 0;
                    state_next = MEASURE;
                end else if (us_count_reg >= WAIT_TIMEOUT_US) begin
                    us_count_next = 0;
                    state_next = FINISH;
                end else if (tick_us) begin
                    us_count_next = us_count_reg + 1'b1;
                end
            end

            MEASURE: begin
                if (echo_fall) begin
                    state_next = FINISH;
                end else if (us_count_reg >= MAX_ECHO_US) begin
                    state_next = FINISH;
                end else if (tick_us) begin
                    us_count_next = us_count_reg + 1'b1;
                end
            end

            FINISH: begin
                us_count_next = 0;
                state_next = IDLE;
            end

            default: begin
                us_count_next = 0;
                state_next = IDLE;
            end
        endcase
    end

endmodule
