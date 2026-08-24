`timescale 1ns / 1ps

//=====================================================================
// btn_debounce_top
//   Basys3 버튼의 실제 채터링을 ILA로 관찰하기 위한 top.
//   btn_debounce.v 는 손대지 않고 인스턴스만 한다.
//
//   [ILA 방식]
//     mark_debug + Set Up Debug (자동 삽입) 가 아니라,
//     IP Catalog 에서 만든 ila_0 를 직접 인스턴스한다.
//     -> Set Up Debug 를 따로 돌릴 필요가 없다.
//
//   [왜 capture control 이 필요한가]
//     채터링은 수 ms 인데 100MHz 로 그냥 찍으면
//     32768 샘플 = 0.33ms 밖에 못 본다.
//     tick_1us 를 probe1 로 빼두고 ILA Capture Setup 에서
//     "probe1 == 1 일 때만 저장" 을 걸면 1샘플 = 1us,
//     32768 샘플 = 32.7ms 창이 된다.
//=====================================================================
module btn_debounce_top (
    input  clk,        // W5,  100MHz
    input  reset,      // btnU (T18)
    input  i_btn,      // btnC (U18)  <- 채터링 관찰 대상
    output o_btn_led,  // led0  : 디바운스 펄스마다 토글
    output raw_led     // led15 : 동기화된 raw 버튼 상태
);

    //-----------------------------------------------------------------
    // 1) 입력 동기화 (2FF)
    //    ILA 는 fabric 안의 net 만 찍을 수 있고, 비동기 패드를 그대로
    //    쓰면 메타스테이블 위험도 있다. 지연 2clk(20ns) 라 ms 단위
    //    채터링 관찰에는 영향 없음.
    //-----------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg btn_meta;
    (* ASYNC_REG = "TRUE" *) reg btn_sync;

    always @(posedge clk) begin
        btn_meta <= i_btn;
        btn_sync <= btn_meta;
    end

    //-----------------------------------------------------------------
    // 2) 1us tick : ILA capture control 용 (샘플 솎아내기)
    //-----------------------------------------------------------------
    reg [6:0] us_cnt;
    reg       tick_1us;

    always @(posedge clk) begin
        if (us_cnt == 7'd99) begin
            us_cnt   <= 7'd0;
            tick_1us <= 1'b1;
        end else begin
            us_cnt   <= us_cnt + 1'b1;
            tick_1us <= 1'b0;
        end
    end

    //-----------------------------------------------------------------
    // 3) 100MHz 자유주행 타임스탬프 (10ns 단위, 24bit -> 167ms 랩)
    //    엣지 사이 간격을 눈금 세지 말고 뺄셈으로 읽으려고 둔다.
    //-----------------------------------------------------------------
    reg [23:0] ts_clk;
    always @(posedge clk) ts_clk <= ts_clk + 1'b1;

    //-----------------------------------------------------------------
    // 4) 관찰 대상 DUT
    //-----------------------------------------------------------------
    wire o_btn;

    btn_debounce U_DEB (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_sync),
        .o_btn(o_btn)
    );

    //-----------------------------------------------------------------
    // 5) ILA
    //    probe0 : btn_sync  <- 채터링 원본
    //    probe1 : tick_1us  <- capture 조건용
    //    probe2 : ts_clk    <- 10ns 단위 타임스탬프
    //    probe3 : o_btn     <- 디바운스 결과 펄스
    //-----------------------------------------------------------------
    ila_0 U_ILA (
        .clk   (clk),
        .probe0(btn_sync),
        .probe1(tick_1us),
        .probe2(ts_clk),
        .probe3(o_btn)
    );

    //-----------------------------------------------------------------
    // 6) o_btn 은 1클럭(10ns) 펄스라 눈으로는 안 보인다 -> 토글로 확인
    //-----------------------------------------------------------------
    reg led_tgl;
    always @(posedge clk) begin
        if (reset)      led_tgl <= 1'b0;
        else if (o_btn) led_tgl <= ~led_tgl;
    end

    assign o_btn_led = led_tgl;
    assign raw_led   = btn_sync;

endmodule
