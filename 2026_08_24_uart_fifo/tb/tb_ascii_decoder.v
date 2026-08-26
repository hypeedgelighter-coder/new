`timescale 1ns / 1ps

//=====================================================================
// tb_ascii_decoder  -  ascii_decoder 단독 무작위 테스트벤치
//
//  대상 : ascii_decoder.v
//
//  RX FIFO 에서 한 바이트씩 스스로 꺼내(rx_pop) 1클럭 폭 명령 펄스로
//  바꾼다. 테스트벤치가 RX FIFO 역할을 한다 (r_data 는 조합 출력이라
//  rx_empty=0 이면 그 자리에서 머리 바이트가 보이는 구조까지 흉내낸다).
//
//  명령 문자표 (대소문자 구분)
//    r=RUN  s=STOP  c=CLEAR  m=업다운토글
//    U=UP   D=DOWN  L=LEFT   R=RIGHT
//    S=초선택  M=분선택  H=시선택   t=센서측정
//    g=값 전송 요청(GET). 'G' 도 같이 받는다. 이것만 Control Unit 이 아니라
//                        ascii_sender 의 send_start 로 나간다
//
//  [무작위로 만드는 것]
//    1) 바이트 열 : 절반 남짓은 위 13개 명령(g/G 포함) 중 무작위,
//       나머지는 완전 무작위 바이트(개행, 숫자, 소문자 등 매핑 안 된 문자)
//    2) FIFO 가 잠깐 비는 구간을 무작위로 끼워 넣는다 (rx_empty=1)
//
//  [검사]
//    - pop 이 일어난 그 클럭에 그 바이트에 해당하는 명령만 1 인가
//      (13개 중 정확히 하나. 나머지 12개는 0)
//    - 매핑 안 된 문자는 명령을 하나도 안 내면서도 pop 은 되는가
//      (안 그러면 그 바이트에 걸려서 이후 명령이 전부 막힌다)
//    - pop 이 없는 클럭에는 어떤 명령도 뜨지 않는가
//    - 보낸 바이트가 전부 소비되었는가
//=====================================================================
module tb_ascii_decoder ();

    localparam integer N_BYTE = 300;

    reg        clk = 1'b0;
    reg        reset;
    reg  [7:0] rx_data;
    reg        rx_empty;
    wire       rx_pop;

    wire cmd_run, cmd_stop, cmd_clear, cmd_mode;
    wire cmd_up, cmd_down, cmd_left, cmd_right;
    wire cmd_sel_s, cmd_sel_m, cmd_sel_h, cmd_start, cmd_get;

    wire [12:0] cmd_vec = {cmd_get, cmd_start, cmd_sel_h, cmd_sel_m, cmd_sel_s,
                           cmd_right, cmd_left, cmd_down, cmd_up,
                           cmd_mode, cmd_clear, cmd_stop, cmd_run};

    reg [7:0] arr[0:N_BYTE-1];
    integer   qi;      // 다음에 내보낼 바이트 위치
    reg       gap;     // FIFO 가 잠깐 비는 구간

    reg [7:0] cmd_tbl[0:13];

    integer seed, seed2, seed0;
    integer errors, checks;
    integer i;
    reg     monitor_on;
    reg [12:0] expv;

    always #5 clk = ~clk;

    ascii_decoder DUT (
        .clk      (clk),
        .reset    (reset),
        .rx_data  (rx_data),
        .rx_empty (rx_empty),
        .rx_pop   (rx_pop),
        .cmd_run  (cmd_run),
        .cmd_stop (cmd_stop),
        .cmd_clear(cmd_clear),
        .cmd_mode (cmd_mode),
        .cmd_up   (cmd_up),
        .cmd_down (cmd_down),
        .cmd_left (cmd_left),
        .cmd_right(cmd_right),
        .cmd_sel_s(cmd_sel_s),
        .cmd_sel_m(cmd_sel_m),
        .cmd_sel_h(cmd_sel_h),
        .cmd_start(cmd_start),
        .cmd_get  (cmd_get)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  byte=%h(%c) cmd=%b exp=%b",
                             $time, tag, rx_data, rx_data, cmd_vec, expv);
            end
        end
    endtask

    function [12:0] decode(input [7:0] b);
        begin
            case (b)
                "r": decode = 13'b0_0000_0000_0001;
                "s": decode = 13'b0_0000_0000_0010;
                "c": decode = 13'b0_0000_0000_0100;
                "m": decode = 13'b0_0000_0000_1000;
                "U": decode = 13'b0_0000_0001_0000;
                "D": decode = 13'b0_0000_0010_0000;
                "L": decode = 13'b0_0000_0100_0000;
                "R": decode = 13'b0_0000_1000_0000;
                "S": decode = 13'b0_0001_0000_0000;
                "M": decode = 13'b0_0010_0000_0000;
                "H": decode = 13'b0_0100_0000_0000;
                "t": decode = 13'b0_1000_0000_0000;
                // 'g' 는 Control Unit 이 아니라 ascii_sender 로 가는 전송 요청 펄스
                "g", "G": decode = 13'b1_0000_0000_0000;
                default: decode = 13'b0_0000_0000_0000;
            endcase
        end
    endfunction

    // 테스트벤치가 RX FIFO 역할 : 조합 출력
    always @(*) begin
        rx_empty = (qi >= N_BYTE) | gap;
        rx_data  = (qi < N_BYTE) ? arr[qi] : 8'h00;
    end

    //---------------- 감시 ----------------
    always @(posedge clk) begin
        if (monitor_on && !reset) begin
            if (rx_pop) begin
                expv = decode(rx_data);
                chk(cmd_vec === expv, "wrong command for byte");
                qi = qi + 1;
                chk(qi <= N_BYTE, "popped more than was queued");
            end else begin
                expv = 13'b0;
                chk(cmd_vec === 13'b0, "command pulse without pop");
            end
        end
    end

    //---------------- FIFO 가 잠깐 비는 구간 ----------------
    initial begin : gap_gen
        gap = 1'b0;
        @(negedge reset);
        forever begin
            repeat (2 + ({$random(seed2)} % 25)) @(negedge clk);
            gap = 1'b1;
            repeat (1 + ({$random(seed2)} % 10)) @(negedge clk);
            gap = 1'b0;
        end
    end

    initial begin
        seed0  = 32'h0A5C_11DE;
        seed   = seed0;
        seed2  = 32'h1357_9BDF;
        errors = 0;
        checks = 0;
        qi     = 0;

        cmd_tbl[0]="r"; cmd_tbl[1]="s"; cmd_tbl[2]="c"; cmd_tbl[3]="m";
        cmd_tbl[4]="U"; cmd_tbl[5]="D"; cmd_tbl[6]="L"; cmd_tbl[7]="R";
        cmd_tbl[8]="S"; cmd_tbl[9]="M"; cmd_tbl[10]="H"; cmd_tbl[11]="t";
        cmd_tbl[12]="g"; cmd_tbl[13]="G";  // 값 전송 요청

        // 바이트 열 만들기 : 60% 는 진짜 명령, 40% 는 아무 바이트
        for (i = 0; i < N_BYTE; i = i + 1) begin
            if (({$random(seed)} % 10) < 6) arr[i] = cmd_tbl[{$random(seed)} % 14];
            else                            arr[i] = {$random(seed)} % 256;
        end
        // 개행/공백처럼 실제로 자주 섞여 들어오는 것도 확실히 넣는다
        arr[3] = 8'h0d; arr[4] = 8'h0a; arr[10] = " "; arr[11] = "0";

        monitor_on = 1'b0;
        reset      = 1'b1;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        monitor_on = 1'b1;

        // 전부 소비될 때까지 기다린다
        i = 0;
        while (qi < N_BYTE && i < 200 * N_BYTE) begin
            @(negedge clk);
            i = i + 1;
        end
        repeat (20) @(negedge clk);

        chk(qi == N_BYTE, "not all bytes were consumed");
        $display("  consumed %0d / %0d bytes", qi, N_BYTE);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_ascii_decoder : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_ascii_decoder : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #3_000_000;
        $display("  tb_ascii_decoder : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
