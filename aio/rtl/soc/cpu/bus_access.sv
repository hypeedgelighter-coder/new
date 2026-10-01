// =============================================================================
// bus_access : CPU 와 APB 사이의 바이트 레인 정렬기
//
//   [왜 이 모듈이 생겼나]
//   원래 data_memory.sv 는 두 가지 일을 한 덩어리로 하고 있었다.
//       (1) 저장   : 워드 배열 dmem[]
//       (2) 레인   : SB/SH 를 어느 바이트에 넣을지, LB/LH 를 어떻게 부호확장할지
//   APB 를 끼우면 (1) 은 버스 반대편(apb_ram) 으로 넘어간다. 하지만 (2) 는
//   funct3(itype) 를 알아야 하는데, itype 은 APB 에 실려 가지 않는다.
//   그래서 (2) 를 CPU 쪽으로 떼어 온 것이 이 모듈이다.
//   data_memory.sv 의 레인 로직을 그대로 옮겨 왔고, 버린 것은 dmem[] 뿐이다.
//
//   [쓰기] 바이트를 레인에 맞게 복제해서 보내고, pstrb 로 어느 바이트를
//          쓸지 알려 준다. (APB4 의 PSTRB. 슬레이브가 byte enable 로 쓴다)
//   [읽기] 슬레이브는 언제나 워드를 통째로 준다. 거기서 필요한 바이트/하프를
//          꺼내 부호확장 또는 zero 확장한다.
//
//   SB/SH/SW 와 LB/LH/LW 의 funct3 가 000/001/010 으로 같아서 case 하나로
//   양쪽을 다 본다. LBU=100, LHU=101 은 읽기에만 나온다.
// =============================================================================
module bus_access
    import rv32_pkg::*;
    (
    input  logic [1:0]  addr_lsb,    // daddr[1:0] : 워드 안에서의 위치
    input  logic [2:0]  itype,       // funct3
    input  logic [31:0] rs2,         // Store 데이터 (정렬 전)
    input  logic [31:0] rdata_bus,   // 슬레이브가 준 워드

    output logic [31:0] wdata_bus,   // 레인에 맞춰 복제한 Store 데이터
    output logic [3:0]  wstrb,       // byte enable
    output logic [31:0] rdata_cpu    // 레인 추출 + 부호/zero 확장
);

    logic [7:0]  rdata_byte;
    logic [15:0] rdata_half;

    // ---------------- Store : 레인 복제 + byte enable ----------------
    // 바이트를 4벌 복제해 두면 어느 레인이 선택되든 값이 맞는다.
    // 실제로 어디에 쓰이는지는 wstrb 가 정한다.
    always_comb
    begin
        case(itype)
            SB :
            begin
                wdata_bus = {4{rs2[7:0]}};
                wstrb     = 4'b0001 << addr_lsb;
            end
            SH :
            begin
                wdata_bus = {2{rs2[15:0]}};
                wstrb     = addr_lsb[1] ? 4'b1100 : 4'b0011;
            end
            SW :
            begin
                wdata_bus = rs2;
                wstrb     = 4'b1111;
            end
            default :
            begin
                wdata_bus = rs2;
                wstrb     = 4'b1111;
            end
        endcase
    end

    // ---------------- Load : 레인 추출 ----------------
    always_comb
    begin
        case(addr_lsb)
            2'b00   : rdata_byte = rdata_bus[ 7: 0];
            2'b01   : rdata_byte = rdata_bus[15: 8];
            2'b10   : rdata_byte = rdata_bus[23:16];
            2'b11   : rdata_byte = rdata_bus[31:24];
            default : rdata_byte = rdata_bus[ 7: 0];
        endcase
    end

    assign rdata_half = (addr_lsb[1]) ? rdata_bus[31:16] : rdata_bus[15:0];

    always_comb
    begin
        case(itype)
            LB      : rdata_cpu = {{24{rdata_byte[7]}},  rdata_byte};  // 부호확장
            LH      : rdata_cpu = {{16{rdata_half[15]}}, rdata_half};  // 부호확장
            LW      : rdata_cpu = rdata_bus;
            LBU     : rdata_cpu = {24'b0, rdata_byte};                 // zero 확장
            LHU     : rdata_cpu = {16'b0, rdata_half};                 // zero 확장
            default : rdata_cpu = rdata_bus;
        endcase
    end

endmodule
