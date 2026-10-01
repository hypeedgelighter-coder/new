// =============================================================================
// apb_master : APB Requester (Master)
//
//   CPU 쪽은 "주소 + 데이터 + transfer/ready" 만 있는 단순 버스다.
//   그걸 APB 의 2 단계 프로토콜(SETUP -> ACCESS)로 바꿔 준다.
//
//   [APB 한 번의 전송]
//       IDLE   : transfer 를 기다린다. psel = 0
//       SETUP  : psel = 1, penable = 0   (주소/데이터/방향을 세워 두는 한 사이클)
//       ACCESS : psel = 1, penable = 1   (pready = 1 이 될 때까지 여기 머문다)
//
//   pready 가 늦게 오면 ACCESS 에 계속 머물고, ready 를 CPU 에 주지 않는다.
//   그동안 control_unit 은 mem 상태에서 대기한다. 이게 그림의
//   "S-type / IL-type -> PREADY -> wait" 다.
//
//   [디코드 에러]
//   어느 슬레이브에도 안 걸리는 주소는 dec_err 로 표시하고, 슬레이브 없이
//   그 자리에서 ready 를 만들어 준다. 안 그러면 CPU 가 영원히 mem 에 갇힌다.
// =============================================================================
module apb_master
    import apb_pkg::*;
    (
    input  logic                     clk,
    input  logic                     rst_n,

    // ---------------- CPU 쪽 (단순 버스) ----------------
    input  logic [31:0]              bus_addr,
    input  logic [31:0]              bus_wdata,
    input  logic [3:0]               bus_wstrb,   // byte enable (SB/SH 용)
    input  logic                     bus_we,      // 1 = write
    input  logic                     transfer,    // 1 = 전송 요청
    output logic [31:0]              bus_rdata,
    output logic                     ready,       // 1 사이클 : 전송 완료

    // ---------------- APB 쪽 ----------------
    output logic [31:0]              paddr,
    output logic [31:0]              pwdata,
    output logic [3:0]               pstrb,
    output logic                     pwrite,
    output logic                     penable,
    output logic [N_SLAVE-1:0]       psel,
    input  logic [N_SLAVE-1:0]       pready,
    input  logic [N_SLAVE-1:0][31:0] prdata
);

    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        ACCESS = 2'b10
    } apb_state_e;

    apb_state_e c_state, n_state;

    logic [N_SLAVE-1:0] psel_dec;   // 디코더가 고른 슬레이브 (아직 안 걸린 것)
    logic               err_dec;
    logic               dec_err;    // 전송 시작할 때 같이 걸어 둔 값
    logic               slave_ready;
    logic [31:0]        prdata_mux;

    // ---------------- Address Decoder ----------------
    apb_decoder U0_APB_DECODER(
        .paddr  (bus_addr),
        .psel   (psel_dec),
        .dec_err(err_dec)
    );

    // ---------------- PREADY MUX ----------------
    // 고른 슬레이브의 pready 만 본다. 없는 주소면 즉시 끝낸다.
    assign slave_ready = |(psel & pready) | dec_err;

    // ---------------- PRDATA MUX ----------------
    // 슬레이브 수만큼의 MUX. 선택 신호는 psel 이다.
    always_comb
    begin
        prdata_mux = 32'h0000_0000;
        for(int i = 0; i < N_SLAVE; i++)
        begin
            if(psel[i]) prdata_mux = prdata[i];
        end
    end

    // ---------------- 상태 레지스터 ----------------
    always_ff @(posedge clk)
    begin
        if(!rst_n) c_state <= IDLE;
        else       c_state <= n_state;
    end

    always_comb
    begin
        n_state = c_state;
        case(c_state)
            IDLE    : if(transfer)    n_state = SETUP;
            SETUP   :                 n_state = ACCESS;
            ACCESS  : if(slave_ready) n_state = IDLE;
            default :                 n_state = IDLE;
        endcase
    end

    // ---------------- 주소 / 데이터 / psel 래치 ----------------
    // APB 는 SETUP 과 ACCESS 두 사이클 내내 주소와 데이터가 그대로여야 한다.
    // CPU 쪽 신호를 그대로 흘려보내지 않고 전송 시작 시점에 한 번 잡아 둔다.
    always_ff @(posedge clk)
    begin
        if(!rst_n)
        begin
            paddr   <= 32'h0;
            pwdata  <= 32'h0;
            pstrb   <= 4'h0;
            pwrite  <= 1'b0;
            psel    <= '0;
            dec_err <= 1'b0;
        end
        else if((c_state == IDLE) && transfer)
        begin
            paddr   <= bus_addr;
            pwdata  <= bus_wdata;
            pstrb   <= bus_wstrb;
            pwrite  <= bus_we;
            psel    <= psel_dec;
            dec_err <= err_dec;
        end
        else if((c_state == ACCESS) && slave_ready)
        begin
            // 전송이 끝났으니 슬레이브 선택을 푼다
            psel    <= '0;
            dec_err <= 1'b0;
        end
    end

    // penable 은 ACCESS 상태 그 자체다 (레지스터 출력이라 글리치가 없다)
    assign penable = (c_state == ACCESS);

    // ---------------- CPU 쪽 응답 ----------------
    // ready 는 ACCESS 에서 pready 를 받은 그 사이클에 1 이 된다.
    // control_unit 이 같은 엣지에서 mem 을 빠져나가므로 다음 사이클에는
    // transfer 가 내려가 있다. (중복 전송이 생기지 않는다)
    assign ready = (c_state == ACCESS) && slave_ready;

    // 읽기 데이터는 반드시 레지스터에 받아 둬야 한다.
    // PRDATA 는 pready 가 뜬 그 사이클에만 유효한데, CPU 는 그 다음 사이클인
    // wb 에서 레지스터 파일에 써 넣기 때문이다.
    always_ff @(posedge clk)
    begin
        if(!rst_n)                              bus_rdata <= 32'h0;
        else if(ready && !pwrite && !dec_err)   bus_rdata <= prdata_mux;
        else if(ready && dec_err)               bus_rdata <= 32'h0;
    end

endmodule


// =============================================================================
// apb_decoder : 주소 -> PSel
//
//   그림의 Address Decoder 상자. 조합 논리뿐이고, 주소 맵은 apb_pkg 가 쥐고 있다.
// =============================================================================
module apb_decoder
    import apb_pkg::*;
    (
    input  logic [31:0]        paddr,
    output logic [N_SLAVE-1:0] psel,
    output logic               dec_err
);

    always_comb
    begin
        psel = '0;

        case(paddr[31:28])

            // 0x1000_0000 ~ : RAM
            4'h1 : psel[SLV_RAM] = 1'b1;

            // 0x2000_0000 ~ : 주변장치. 256 바이트씩 끊어 쓴다.
            // [27:12] 가 0 이 아니면 우리가 만든 주변장치 영역이 아니다.
            4'h2 :
            begin
                if(paddr[27:12] == 16'h0000)
                begin
                    case(paddr[11:8])
                        4'h1    : psel[SLV_GPO]  = 1'b1;
                        4'h3    : psel[SLV_UART] = 1'b1;
                        default : ; // 없는 주소
                    endcase
                end
            end

            // 0x3000_0000 ~ 0x3000_0FFF : NAND 컨트롤러 (레지스터 4KB)
            4'h3 :
            begin
                if(paddr[27:12] == 16'h0000) psel[SLV_NAND] = 1'b1;
            end

            default : ; // 없는 주소
        endcase
    end

    // 아무도 안 걸렸다 = 없는 주소
    assign dec_err = (psel == '0);

endmodule
