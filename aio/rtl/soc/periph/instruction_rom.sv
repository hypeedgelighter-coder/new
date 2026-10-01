// =============================================================================
// instruction_rom : 명령어 ROM (조합 읽기)
//
//   cpu/rtl/instruction_rom.sv 에서 출발했다. 달라진 점은 둘이다.
//     - 크기가 파라미터다 (펌웨어가 1KB 를 넘는다)
//     - 내장 테스트 프로그램을 없애고 항상 파일(sw/fw.hex)을 읽는다
//
//   버스를 타지 않고 CPU 에 직결이다 (하버드 구조). 그래서 PC 만 멈춰 두면
//   instr_code 가 명령이 끝날 때까지 그대로 유지된다.
//
//   INIT_FILE 은 타입 없는 파라미터다. "parameter string" 은 Vivado 합성이
//   받지 않는다 ([Synth 8-27]). 타입을 안 쓰면 알아서 문자열로 묶인다.
// =============================================================================
module instruction_rom #(
    parameter int WORDS     = 1024,         // 4KB. sw/link.ld 의 ROM 크기와 같아야 한다
    parameter     INIT_FILE = "fw.hex"
)(
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_code
);

    localparam int AW = $clog2(WORDS);

    logic [31:0] instr_rom [0:WORDS-1];

    initial
    begin
        // 안 쓰는 자리는 NOP (addi x0, x0, 0) 으로 채워서 X 가 안 흘러다니게 한다
        for(int i = 0; i < WORDS; i++) instr_rom[i] = 32'h0000_0013;
        $readmemh(INIT_FILE, instr_rom);
    end

    // 워드 인덱스. instr_addr[31:2] 를 그대로 쓰면 배열 범위를 벗어난다.
    assign instr_code = instr_rom[instr_addr[AW+1:2]];

endmodule
