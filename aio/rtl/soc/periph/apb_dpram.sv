// =============================================================================
// apb_dpram : 포트가 둘인 데이터 메모리
//
//     포트 A : APB 슬레이브       <- CPU 가 lw / sw 로 쓴다
//     포트 B : DMA ready/valid    <- NAND 컨트롤러가 페이지를 실어 나른다
//
//   [왜 포트가 둘인가]
//   DMA 의 뜻이 "CPU 를 거치지 않고 메모리에 직접 닿는다" 이다. CPU 는
//   "어디서(HOST_ADDR) 얼마나(PAGE_WORDS)" 만 레지스터에 적어 주고, 데이터는
//   컨트롤러가 포트 B 로 직접 읽고 쓴다. CPU 가 워드마다 lw/sw 를 돌리지 않는다.
//
//   [동기 읽기 = Block RAM]
//   cpu/rtl/apb_ram.sv 는 조합 읽기(분산 RAM)였다. 여기서는 읽기를 플롭에 받는다.
//   APB 는 SETUP 사이클에 이미 주소가 나와 있으므로, SETUP 끝 엣지에서 읽어 두면
//   ACCESS 사이클 내내 prdata 가 유효하다. wait state 가 필요 없다.
//
//   [포트 B 규약]  aio_nand_dma_ctrl 의 mem_* 포트와 맞물린다
//     mem_req_valid && mem_req_ready  : 요청 수락
//     읽기  -> 다음 사이클에 mem_rsp_valid. mem_rsp_ready 가 올 때까지 유지한다
//     쓰기  -> 요청이 수락된 그 엣지에 끝난다 (응답 없음)
//     응답이 아직 안 나간 동안은 새 요청을 받지 않는다 (한 번에 하나)
//
//   주소는 RAM 크기만큼의 하위 비트만 본다. DMA 가 0x1000_0000 영역 밖을
//   가리켜도 RAM 안에서 접힌다 (이 SoC 에서 DMA 가 닿을 수 있는 곳은 RAM 뿐이다).
// =============================================================================
module apb_dpram #(
    parameter int WORDS = 1024
)(
    input  logic        clk,
    input  logic        rst_n,

    // ---------------- 포트 A : APB ----------------
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic [3:0]  pstrb,
    output logic [31:0] prdata,
    output logic        pready,

    // ---------------- 포트 B : DMA ----------------
    input  logic        mem_req_valid,
    output logic        mem_req_ready,
    input  logic        mem_req_write,
    input  logic [31:0] mem_req_addr,
    input  logic [31:0] mem_req_wdata,
    input  logic [3:0]  mem_req_wstrb,
    output logic        mem_rsp_valid,
    output logic [31:0] mem_rsp_rdata,
    input  logic        mem_rsp_ready
);

    localparam int AW = $clog2(WORDS);

    logic [31:0]   mem [0:WORDS-1];

    logic [AW-1:0] a_idx, b_idx;
    logic          a_we, b_req, b_we;
    logic [31:0]   a_rdata, b_rdata;

    // X 가 흘러다니지 않게 0 으로 채워 둔다 (FPGA 에서는 BRAM 초기값이 된다)
    initial
    begin
        for(int i = 0; i < WORDS; i++) mem[i] = 32'h0000_0000;
    end

    // ---------------- 포트 A ----------------
    assign a_idx  = paddr[AW+1:2];
    assign a_we   = psel && penable && pwrite;
    assign pready = 1'b1;
    assign prdata = a_rdata;

    // always_ff 가 아니라 always 다. initial 로도 쓰는 배열이라 always_ff 로 두면
    // VCS 가 ICPD 에러를 낸다.
    always @(posedge clk)
    begin
        if(psel)
        begin
            for(int b = 0; b < 4; b++)
            begin
                if(a_we && pstrb[b]) mem[a_idx][8*b +: 8] <= pwdata[8*b +: 8];
            end
            a_rdata <= mem[a_idx];
        end
    end

    // ---------------- 포트 B ----------------
    assign b_idx         = mem_req_addr[AW+1:2];
    assign mem_req_ready = !mem_rsp_valid || mem_rsp_ready;
    assign b_req         = mem_req_valid && mem_req_ready;
    assign b_we          = b_req && mem_req_write;
    assign mem_rsp_rdata = b_rdata;

    always @(posedge clk)
    begin
        if(b_req)
        begin
            for(int b = 0; b < 4; b++)
            begin
                if(b_we && mem_req_wstrb[b]) mem[b_idx][8*b +: 8] <= mem_req_wdata[8*b +: 8];
            end
            b_rdata <= mem[b_idx];
        end
    end

    always_ff @(posedge clk)
    begin
        if(!rst_n)                          mem_rsp_valid <= 1'b0;
        else if(b_req && !mem_req_write)    mem_rsp_valid <= 1'b1;
        else if(mem_rsp_ready)              mem_rsp_valid <= 1'b0;
    end

endmodule
