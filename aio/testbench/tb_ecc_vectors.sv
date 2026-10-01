`timescale 1ns/1ps

// =============================================================================
// tb_ecc_vectors : Python 골든 모델이 만든 벡터로 ECC RTL 을 검사한다
//
//   tb_secded_ecc_32 는 RTL 이 "자기가 만든 ECC 로 자기가 복구하는지" 를 본다.
//   그것만으로는 encoder 와 decoder 가 같은 방식으로 틀린 경우를 못 잡는다.
//   여기서는 RTL 과 무관하게 짠 scripts/ecc_ref.py 의 답과 비교한다.
//
//   벡터 파일 (실행 디렉터리의 ecc_vectors.txt) 한 줄 :
//       data ecc corrupted_data corrupted_ecc status corrected_data
//   만드는 법 :
//       python scripts/ecc_ref.py gen ecc_vectors.txt 1000 2026
// =============================================================================
module tb_ecc_vectors;
    logic [31:0] data_i;
    logic [6:0]  ecc_o;
    logic [31:0] check_data_i;
    logic [6:0]  check_ecc_i;
    logic [31:0] corrected_data_o;
    logic [1:0]  status_o;
    logic [5:0]  syndrome_o;

    secded_ecc_32 dut (
        .data_i(data_i), .ecc_o(ecc_o),
        .check_data_i(check_data_i), .check_ecc_i(check_ecc_i),
        .corrected_data_o(corrected_data_o), .status_o(status_o),
        .syndrome_o(syndrome_o)
    );

    int          fd, got, n_vec;
    int          n_by_status [4];
    string       line;
    logic [31:0] data, bad_data, corrected;
    logic [6:0]  ecc, bad_ecc;
    int          exp_status;

    initial begin
        n_vec = 0;
        for (int i = 0; i < 4; i++) n_by_status[i] = 0;

        fd = $fopen("ecc_vectors.txt", "r");
        if (fd == 0) $fatal(1, "ecc_vectors.txt not found (run scripts/ecc_ref.py gen first)");

        while (!$feof(fd)) begin
            if ($fgets(line, fd) == 0) break;
            got = $sscanf(line, "%h %h %h %h %h %h",
                          data, ecc, bad_data, bad_ecc, exp_status, corrected);
            if (got != 6) continue;                 // 주석 / 빈 줄

            data_i       = data;
            check_data_i = bad_data;
            check_ecc_i  = bad_ecc;
            #1;

            assert (ecc_o === ecc)
                else $fatal(1, "encode mismatch: data=%08x rtl=%02x python=%02x", data, ecc_o, ecc);
            assert (status_o == exp_status)
                else $fatal(1, "status mismatch: data=%08x ecc=%02x rtl=%0d python=%0d",
                            bad_data, bad_ecc, status_o, exp_status);
            assert (corrected_data_o === corrected)
                else $fatal(1, "correction mismatch: data=%08x ecc=%02x rtl=%08x python=%08x",
                            bad_data, bad_ecc, corrected_data_o, corrected);

            n_vec++;
            n_by_status[exp_status]++;
        end
        $fclose(fd);

        if (n_vec == 0) $fatal(1, "no vectors were read");

        $display("PASS: ECC RTL matches %0d Python golden vectors (clean=%0d data_fixed=%0d parity_fixed=%0d uncorrectable=%0d)",
                 n_vec, n_by_status[0], n_by_status[1], n_by_status[2], n_by_status[3]);
        $finish;
    end
endmodule
