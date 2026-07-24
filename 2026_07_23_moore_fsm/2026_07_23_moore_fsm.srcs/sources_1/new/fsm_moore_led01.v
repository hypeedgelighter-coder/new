
`timescale 1ns / 1ps

module fsm_moore_led01 (
    input clk,
    input reset,
    input [2:0] sw,
    output reg [2:0] led

);

    parameter s0 = 3'b000, s1 = 3'b001, s2 = 3'b010, s3 = 3'b011, s4 = 3'b100;
    //state register
    reg [2:0] current_state, next_state;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state <= s0;
        end else begin
            current_state <= next_state;
        end
    end
    // next state combinatainal logic
    always @(*) begin
        case (current_state)
            s0:
            if (sw == s1) begin
                next_state = s1;
            end else if (sw == s4) begin
                next_state = s4;
            end else begin
                next_state = s0;
            end

            s1:
            if (sw == s2) begin
                next_state = s2;
            end else begin
                next_state = s1;
            end

            s2:
            if (sw == s3) begin
                next_state = s3;
            end else begin
                next_state = s2;
            end

            s3:
            if (sw == s4) begin
                next_state = s4;
            end else begin
                next_state = s3;
            end

            s4:
            if (sw == 3'b000) begin
                next_state = s0;
            end else if (sw == s1) begin
                next_state = s1;
            end else begin
                next_state = s4;
            end

            default: next_state = current_state;
        endcase
    end

    //output cobinatinoal logic
    always @(*) begin
        if (current_state == s0) begin
            led = s0;
        end else if (current_state == s1) begin
            led = s1;
        end else if (current_state == s2) begin
            led = s2;
        end else if (current_state == s3) begin
            led = s3;
        end else begin
            led = s4;
        end


    end




endmodule



