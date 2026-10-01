`timescale 1ns/1ps

module tb_secded_ecc_32;
    logic [31:0] data_i;
    logic [6:0] ecc_o;
    logic [31:0] check_data_i;
    logic [6:0] check_ecc_i;
    logic [31:0] corrected_data_o;
    logic [1:0] status_o;
    logic [5:0] syndrome_o;
    integer word_index;
    integer bit_index;
    integer bit_a;
    integer bit_b;
    integer checks;
    logic [31:0] original;
    logic [6:0] original_ecc;

    secded_ecc_32 dut (
        .data_i(data_i), .ecc_o(ecc_o),
        .check_data_i(check_data_i), .check_ecc_i(check_ecc_i),
        .corrected_data_o(corrected_data_o), .status_o(status_o),
        .syndrome_o(syndrome_o)
    );

    task automatic test_word(input logic [31:0] value);
        begin
            data_i = value;
            check_data_i = value;
            #1 original_ecc = ecc_o;
            check_ecc_i = original_ecc;
            #1;
            assert ((status_o == 0) && (corrected_data_o == value))
                else $fatal(1, "clean decode failed for %08x", value);
            checks = checks + 1;

            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin
                check_data_i = value ^ (32'b1 << bit_index);
                check_ecc_i = original_ecc;
                #1;
                assert ((status_o == 1) && (corrected_data_o == value))
                    else $fatal(1, "data correction failed value=%08x bit=%0d", value, bit_index);
                checks = checks + 1;
            end

            check_data_i = value;
            for (bit_index = 0; bit_index < 7; bit_index = bit_index + 1) begin
                check_ecc_i = original_ecc ^ (7'b1 << bit_index);
                #1;
                assert ((status_o == 2) && (corrected_data_o == value))
                    else $fatal(1, "ECC correction failed value=%08x bit=%0d", value, bit_index);
                checks = checks + 1;
            end

            check_ecc_i = original_ecc;
            for (bit_index = 0; bit_index < 10; bit_index = bit_index + 1) begin
                bit_a = (bit_index * 7 + word_index) % 32;
                bit_b = (bit_a + bit_index + 1) % 32;
                check_data_i = value ^ (32'b1 << bit_a) ^ (32'b1 << bit_b);
                #1;
                assert (status_o == 3)
                    else $fatal(1, "double-bit detection failed bits=%0d,%0d", bit_a, bit_b);
                checks = checks + 1;
            end
        end
    endtask

    initial begin
        data_i = 0;
        check_data_i = 0;
        check_ecc_i = 0;
        checks = 0;
        original = 32'h1a2b_3c4d;

        for (word_index = 0; word_index < 105; word_index = word_index + 1) begin
            if (word_index == 0) original = 32'h0000_0000;
            else if (word_index == 1) original = 32'hffff_ffff;
            else if (word_index == 2) original = 32'h8000_0000;
            else original = $urandom;
            test_word(original);
        end

        $display("PASS: ECC RTL exhaustive single-bit regression (%0d checks)", checks);
        $finish;
    end
endmodule
