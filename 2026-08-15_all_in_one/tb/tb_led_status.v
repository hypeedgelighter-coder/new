`timescale 1ns / 1ps

//=====================================================================
// tb_led_status  -  led_status 단독 무작위 테스트벤치
//
//  대상 : led_status.v  (조합회로. 클럭 없음)
//
//  평소
//    led[3:0] 현재 모드 one-hot   led[5:4] 시계 편집 자리
//    led[6]   DHT11 체크섬 정상    led[7]   SR04 valid 또는 스톱워치 RUN
//  DHT11 모드일 때만 LED 전체를 진단 표시로 갈아끼운다
//    led = {0, dht_valid, dht_dbg_step}
//
//  [검사 방법]
//    입력이 전부 합쳐 13비트뿐이라 8192가지를 "전수" 확인한다.
//    그 위에 무작위 확인을 한 번 더 얹는다 (전수 루프의 순서 때문에
//    가려지는 실수가 없게).
//=====================================================================
module tb_led_status ();

    localparam integer N_RAND = 2000;

    localparam [1:0] MODE_SR04  = 2'd2,
                     MODE_DHT11 = 2'd3;

    reg  [1:0] mode_sel;
    reg  [1:0] wt_edit_sel;
    reg        sw_run_stop;
    reg        sr04_valid;
    reg        dht_valid;
    reg  [5:0] dht_dbg_step;
    wire [7:0] led;

    reg [7:0] exp, norm;

    integer seed, seed0;
    integer errors, checks;
    integer i;

    led_status DUT (
        .mode_sel    (mode_sel),
        .wt_edit_sel (wt_edit_sel),
        .sw_run_stop (sw_run_stop),
        .sr04_valid  (sr04_valid),
        .dht_valid   (dht_valid),
        .dht_dbg_step(dht_dbg_step),
        .led         (led)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  led=%b exp=%b (mode=%0d)",
                             $time, tag, led, exp, mode_sel);
            end
        end
    endtask

    task check_now;
        begin
            #1;
            norm[3:0] = 4'b0001 << mode_sel;
            norm[5:4] = wt_edit_sel;
            norm[6]   = dht_valid;
            norm[7]   = (mode_sel == MODE_SR04) ? sr04_valid : sw_run_stop;
            exp       = (mode_sel == MODE_DHT11) ? {1'b0, dht_valid, dht_dbg_step}
                                                 : norm;
            chk(led === exp, "led mismatch");
        end
    endtask

    initial begin
        seed0  = 32'h1ED5_7A70;
        seed   = seed0;
        errors = 0;
        checks = 0;

        //---------------- 전수 (13비트 = 8192가지) ----------------
        for (i = 0; i < 8192; i = i + 1) begin
            {dht_dbg_step, dht_valid, sr04_valid, sw_run_stop,
             wt_edit_sel, mode_sel} = i[12:0];
            check_now;
        end

        //---------------- 무작위 ----------------
        for (i = 0; i < N_RAND; i = i + 1) begin
            mode_sel     = {$random(seed)} % 4;
            wt_edit_sel  = {$random(seed)} % 4;
            sw_run_stop  = {$random(seed)} % 2;
            sr04_valid   = {$random(seed)} % 2;
            dht_valid    = {$random(seed)} % 2;
            dht_dbg_step = {$random(seed)} % 64;
            check_now;
        end

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_led_status : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_led_status : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #500_000;
        $display("  tb_led_status : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
