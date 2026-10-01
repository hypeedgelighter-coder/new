`timescale 1ns/1ps

// 32-bit SEC-DED encoder/decoder.
// Code layout uses Hamming parity positions 1,2,4,8,16,32 and one
// additional overall parity bit.  The stored ECC is therefore 7 bits/word.
module secded_ecc_32 (
    input  logic [31:0] data_i,
    output logic [6:0]  ecc_o,

    input  logic [31:0] check_data_i,
    input  logic [6:0]  check_ecc_i,
    output logic [31:0] corrected_data_o,
    output logic [1:0]  status_o,
    output logic [5:0]  syndrome_o
);
    localparam logic [1:0] ECC_CLEAN       = 2'd0;
    localparam logic [1:0] ECC_DATA_FIXED  = 2'd1;
    localparam logic [1:0] ECC_PARITY_FIXED= 2'd2;
    localparam logic [1:0] ECC_UNCORRECTABLE = 2'd3;

    logic [37:0] enc_code;
    logic [37:0] chk_code;
    logic [5:0]  syndrome;
    logic        overall_mismatch;
    integer enc_pos;
    integer enc_bit_idx;
    integer enc_parity_idx;
    integer dec_pos;
    integer dec_bit_idx;
    integer dec_parity_idx;

    always_comb begin
        enc_code = '0;
        enc_bit_idx = 0;
        for (enc_pos = 1; enc_pos <= 38; enc_pos = enc_pos + 1) begin
            if ((enc_pos != 1) && (enc_pos != 2) && (enc_pos != 4) &&
                (enc_pos != 8) && (enc_pos != 16) && (enc_pos != 32)) begin
                enc_code[enc_pos-1] = data_i[enc_bit_idx];
                enc_bit_idx = enc_bit_idx + 1;
            end
        end

        for (enc_parity_idx = 0; enc_parity_idx < 6; enc_parity_idx = enc_parity_idx + 1) begin
            enc_code[(1 << enc_parity_idx)-1] = 1'b0;
            for (enc_pos = 1; enc_pos <= 38; enc_pos = enc_pos + 1)
                if ((enc_pos & (1 << enc_parity_idx)) != 0)
                    enc_code[(1 << enc_parity_idx)-1] =
                        enc_code[(1 << enc_parity_idx)-1] ^ enc_code[enc_pos-1];
            ecc_o[enc_parity_idx] = enc_code[(1 << enc_parity_idx)-1];
        end
        ecc_o[6] = ^enc_code;
    end

    always_comb begin
        chk_code = '0;
        dec_bit_idx = 0;
        for (dec_pos = 1; dec_pos <= 38; dec_pos = dec_pos + 1) begin
            if ((dec_pos == 1) || (dec_pos == 2) || (dec_pos == 4) ||
                (dec_pos == 8) || (dec_pos == 16) || (dec_pos == 32)) begin
                if (dec_pos == 1)       chk_code[dec_pos-1] = check_ecc_i[0];
                else if (dec_pos == 2)  chk_code[dec_pos-1] = check_ecc_i[1];
                else if (dec_pos == 4)  chk_code[dec_pos-1] = check_ecc_i[2];
                else if (dec_pos == 8)  chk_code[dec_pos-1] = check_ecc_i[3];
                else if (dec_pos == 16) chk_code[dec_pos-1] = check_ecc_i[4];
                else                    chk_code[dec_pos-1] = check_ecc_i[5];
            end else begin
                chk_code[dec_pos-1] = check_data_i[dec_bit_idx];
                dec_bit_idx = dec_bit_idx + 1;
            end
        end

        syndrome = '0;
        for (dec_parity_idx = 0; dec_parity_idx < 6; dec_parity_idx = dec_parity_idx + 1)
            for (dec_pos = 1; dec_pos <= 38; dec_pos = dec_pos + 1)
                if ((dec_pos & (1 << dec_parity_idx)) != 0)
                    syndrome[dec_parity_idx] = syndrome[dec_parity_idx] ^ chk_code[dec_pos-1];

        overall_mismatch = (^chk_code) ^ check_ecc_i[6];
        corrected_data_o = check_data_i;
        status_o = ECC_CLEAN;
        syndrome_o = syndrome;

        if ((syndrome == 0) && !overall_mismatch) begin
            status_o = ECC_CLEAN;
        end else if ((syndrome == 0) && overall_mismatch) begin
            // Error in the extra overall parity bit only.
            status_o = ECC_PARITY_FIXED;
        end else if ((syndrome != 0) && overall_mismatch && (syndrome <= 38)) begin
            // A single-bit error is correctable.  Translate the Hamming code
            // position back to a data bit index when it is not a parity bit.
            if ((syndrome == 1) || (syndrome == 2) || (syndrome == 4) ||
                (syndrome == 8) || (syndrome == 16) || (syndrome == 32)) begin
                status_o = ECC_PARITY_FIXED;
            end else begin
                dec_bit_idx = 0;
                for (dec_pos = 1; dec_pos <= 38; dec_pos = dec_pos + 1) begin
                    if ((dec_pos != 1) && (dec_pos != 2) && (dec_pos != 4) &&
                        (dec_pos != 8) && (dec_pos != 16) && (dec_pos != 32)) begin
                        if (dec_pos == syndrome)
                            corrected_data_o[dec_bit_idx] = ~check_data_i[dec_bit_idx];
                        dec_bit_idx = dec_bit_idx + 1;
                    end
                end
                status_o = ECC_DATA_FIXED;
            end
        end else begin
            status_o = ECC_UNCORRECTABLE;
        end
    end
endmodule
