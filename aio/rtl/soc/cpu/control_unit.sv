module control_unit
    import rv32_pkg::*;
    (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] instr_code,
    output logic        pc_enable,  // 멀티사이클 : 명령의 "마지막" 단계에서만 1
    output logic [3:0]  alu_control,
    output logic        rf_we,
    output logic        alusrc_sel,
    output logic        bus_we,     // 1 = write. S-type 의 mem 단계 내내 유지된다
    output logic        transfer,   // 1 = APB 전송 요청 (그림의 transfer)
    input  logic        bus_ready,  // APB 마스터가 전송을 끝냈다 (PREADY 를 받았다)
    output logic [2:0]  itype,      // Load / Store 접근 크기 (funct3)
    output logic [2:0]  rf_srcsel,  // RFWdSrcSel : 레지스터에 써 넣을 값 선택
    output logic        branch,     // B-type  : b_taken 과 AND 되어 PC 를 바꾼다
    output logic        jal,        // J-type  : 조건 없이 PC + imm
    output logic        jalr        // JL-type : 조건 없이 PC = rs1 + imm
    );

    // -------------------------------------------------------------------------
    // 상태. enum 으로 두면 파형에 fetch / decode / ... 이름이 그대로 뜬다.
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        fetch   = 3'b000,
        decode  = 3'b001,
        execute = 3'b010,
        mem     = 3'b011,
        wb      = 3'b100
    } state_e;

    state_e c_state, n_state;

    logic [2:0] funct3;

    opcode_e opcode;
    assign opcode = opcode_e'(instr_code[6:0]);

    assign funct3 = instr_code[14:12];


    // =========================================================================
    // 1) 상태 레지스터
    // =========================================================================
    // program_counter / reg_file / data_memory 가 모두 동기 리셋이라 맞춘다.
    // (Xilinx 7-series 는 동기 리셋이 권장 스타일이기도 하다)
    always_ff @(posedge clk)
    begin
        if(!rst_n) c_state <= fetch;
        else       c_state <= n_state;
    end


    // =========================================================================
    // 2) 시퀀싱 : "언제" 쓰느냐
    //
    //    상태에 의존하는 신호만 여기서 만든다. 이 셋은 한 명령이 지나가는 동안
    //    정확히 한 번씩만 떠야 한다. 여러 상태에 걸쳐 1 이면 그 사이클 수만큼
    //    중복으로 써버린다.
    //        pc_enable : PC 를 다음 명령으로 넘긴다   -> 마지막 단계
    //        rf_we     : 레지스터 파일에 쓴다         -> wb 단계
    //        transfer  : APB 전송을 요청한다          -> mem 단계 (Load/Store)
    //        bus_we    : 그 전송이 쓰기다             -> mem 단계 (Store 만)
    //
    //    [APB 가 붙으면서 달라진 점]
    //    메모리가 버스 반대편으로 갔다. 한 사이클에 끝나지 않는다.
    //    그래서 mem 단계는 bus_ready 가 올 때까지 제자리에 머문다.
    //    transfer / bus_we 는 그동안 계속 걸려 있어야 한다 (펄스가 아니다).
    //
    //    [핵심] instruction_rom 이 데이터 메모리와 분리된 "조합 읽기" 라서
    //    PC 만 멈춰 있으면 instr_code / rf_rd1 / rf_rd2 / alu_result / drdata
    //    가 명령 내내 그대로 유지된다. 그래서 IR 도, A/B/ALUOut/MDR 래치도
    //    필요 없다. 멈춰 세울 것은 PC 하나뿐이다.
    // =========================================================================
    always_comb
    begin
        n_state   = fetch;
        pc_enable = 1'b0;
        rf_we     = 1'b0;
        transfer  = 1'b0;
        bus_we    = 1'b0;

        case(c_state)

            // 명령어 인출. 위 [핵심] 때문에 이 단계에서 붙잡아 둘 것이 없다.
            fetch : n_state = decode;

            // opcode 해석 + 레지스터 읽기. 역시 조합이라 기다리기만 한다.
            decode : n_state = execute;

            // 연산 / 주소 계산. 여기서 타입별로 갈래가 나뉜다.
            execute :
            begin
                case(opcode)

                    // 메모리 주소를 계산해야 하는 둘만 mem 으로 간다
                    OP_ILTYPE, OP_STYPE : n_state = mem;

                    // B-type 은 여기서 끝. mem 도 wb 도 없다 (rd 에 안 쓴다).
                    // branch 는 3) 에서 이미 1 이라 pc_sel 이 b_taken 을 반영한다.
                    OP_BTYPE :
                    begin
                        pc_enable = 1'b1;
                        n_state   = fetch;
                    end

                    // 나머지는 전부 rd 에 써야 하므로 wb 로 간다
                    OP_RTYPE, OP_ITYPE, OP_LUI,
                    OP_AUIPC, OP_JAL,   OP_JALR : n_state = wb;

                    // 정의되지 않은 opcode. 여기서 멈추면 영원히 못 빠져나오니
                    // NOP 처럼 PC 만 넘기고 다음 명령으로 간다.
                    default :
                    begin
                        pc_enable = 1'b1;
                        n_state   = fetch;
                    end
                endcase
            end

            // 데이터 메모리 / 주변장치 접근. Load / Store 만 들어온다.
            //
            // APB 마스터에게 전송을 걸어 놓고 bus_ready 를 기다린다.
            // ready 가 안 오면 n_state = mem 이라 제자리에 머문다. PC 도
            // 멈춰 있으므로 주소(daddr)와 쓰기 데이터(rs2)가 그대로 유지된다.
            // 느린 슬레이브(wait state)를 붙여도 CPU 는 그냥 더 기다릴 뿐이다.
            mem :
            begin
                transfer = 1'b1;
                bus_we   = (opcode == OP_STYPE);

                if(!bus_ready)
                begin
                    n_state = mem;      // PREADY 대기
                end
                else
                begin
                    case(opcode)

                        // Store 는 쓰기가 끝났으니 여기서 명령이 끝난다. wb 가 없다.
                        OP_STYPE :
                        begin
                            pc_enable = 1'b1;
                            n_state   = fetch;
                        end

                        // Load 는 읽어온 값을 rd 에 넣어야 하므로 wb 로 간다.
                        // 읽기 데이터는 마스터가 레지스터에 잡아 두고 있다.
                        OP_ILTYPE : n_state = wb;

                        default : n_state = fetch;
                    endcase
                end
            end

            // 레지스터 쓰기. Store / B-type 은 애초에 여기로 오지 않으므로
            // wb 에 도달했다는 것 자체가 "rd 에 쓴다" 는 뜻이다. opcode 를
            // 다시 볼 필요가 없다. 무엇을 쓸지(rf_srcsel)는 3) 이 정해준다.
            wb :
            begin
                rf_we     = 1'b1;
                pc_enable = 1'b1;
                n_state   = fetch;
            end

            default : n_state = fetch;
        endcase
    end


    // =========================================================================
    // 3) 명령 디코드 : "무엇을" 쓰느냐
    //
    //    전부 opcode / funct 만의 함수라 상태와 무관하다. 그래서 단계마다
    //    반복해서 쓸 필요가 없고, 명령이 끝날 때까지 계속 걸어두면 된다.
    //    2) 와 대입하는 신호가 겹치지 않으므로 always 블록을 나눠도 안전하다.
    //
    //    branch / jal / jalr 도 여기 둔다. 이 셋은 pc_next 를 "고르기만" 하고
    //    실제로 PC 가 움직이는 것은 pc_enable 이 뜨는 순간뿐이라서, 명령 내내
    //    걸려 있어도 무해하다.
    // =========================================================================
    always_comb
    begin
        alu_control = ALU_ADD;
        alusrc_sel  = 1'b0;
        itype       = SW;       // SW / LW 와 같은 3'b010
        rf_srcsel   = WB_ALU;
        branch      = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;

        case(opcode)

            OP_RTYPE : // R-type : rd = rs1 op rs2
            begin
                alusrc_sel  = 1'b0;
                alu_control = alu_ctrl_r(instr_code);   // {funct7[5], funct3}
                rf_srcsel   = WB_ALU;
            end

            OP_ITYPE : // I-type : rd = rs1 op imm
            begin
                alusrc_sel  = 1'b1;
                alu_control = alu_ctrl_i(instr_code);   // SRLI/SRAI 만 instr[30] 사용
                rf_srcsel   = WB_ALU;
            end

            OP_STYPE : // S-type : M[rs1 + imm] = rs2
            begin
                alusrc_sel  = 1'b1;
                alu_control = ALU_ADD;  // 주소 계산 : rs1 + imm
                itype       = funct3;   // SB / SH / SW
            end

            OP_ILTYPE : // IL-type : rd = M[rs1 + imm]
            begin
                alusrc_sel  = 1'b1;
                alu_control = ALU_ADD;  // 주소 계산 : rs1 + imm
                itype       = funct3;   // LB / LH / LW / LBU / LHU
                rf_srcsel   = WB_MEM;
            end

            OP_BTYPE : // B-type : if(rs1 cmp rs2) PC += imm
            begin
                alusrc_sel  = 1'b0;             // rs1 과 rs2 를 그대로 비교
                alu_control = {1'b0, funct3};   // [2:0] = funct3 -> Comparator
                branch      = 1'b1;
            end

            OP_LUI : // U-type : rd = imm
            begin
                alusrc_sel  = 1'b1;
                alu_control = ALU_ADD;  // ALU 결과는 쓰지 않는다
                rf_srcsel   = WB_IMM;   // ALU 를 우회해서 imm 을 그대로 쓴다
            end

            OP_AUIPC : // U-type : rd = PC + imm
            begin
                alusrc_sel  = 1'b1;
                alu_control = ALU_ADD;
                rf_srcsel   = WB_PCIMM; // PC + imm 가산기 결과를 그대로 쓴다
            end

            OP_JAL : // J-type : rd = PC + 4;  PC += imm
            begin
                alusrc_sel  = 1'b1;
                alu_control = ALU_ADD;
                rf_srcsel   = WB_PC4;   // 복귀 주소
                jal         = 1'b1;     // 조건 없이 PC + imm
            end

            OP_JALR : // JL-type : rd = PC + 4;  PC = rs1 + imm
            begin
                alusrc_sel  = 1'b1;     // rs1 + imm 은 ALU 가 만든다
                alu_control = ALU_ADD;
                rf_srcsel   = WB_PC4;   // 복귀 주소
                jalr        = 1'b1;     // 조건 없이 PC = (rs1 + imm) & ~1
            end

            default : ; // NOP : 위의 기본값 그대로 (아무것도 바꾸지 않는다)
        endcase
    end

endmodule
