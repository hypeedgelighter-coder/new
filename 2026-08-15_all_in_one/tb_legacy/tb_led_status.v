`timescale 1ns / 1ps

//=====================================================================
// tb_led_status  -  LED 표시 로직 검증 (조합회로라 클럭 없음)
//
//  평소   : led[3:0] 모드 one-hot, led[5:4] 편집자리,
//           led[6] DHT valid, led[7] SR04 valid 또는 스톱워치 RUN
//  DHT 모드 : led = {0, dht_valid, dbg_step} 진단 표시
//=====================================================================
module tb_led_status ();

    reg  [1:0] mode_sel;
    reg  [1:0] wt_edit_sel;
    reg        sw_run_stop;
    reg        sr04_valid;
    reg        dht_valid;
    reg  [5:0] dht_dbg_step;
    wire [7:0] led;

    integer err;

    led_status DUT (
        .mode_sel    (mode_sel),
        .wt_edit_sel (wt_edit_sel),
        .sw_run_stop (sw_run_stop),
        .sr04_valid  (sr04_valid),
        .dht_valid   (dht_valid),
        .dht_dbg_step(dht_dbg_step),
        .led         (led)
    );

    task ok(input cond);
        begin
            if (cond) $write("  OK   : (led=%b) ", led);
            else begin
                $write("  FAIL : (led=%b) ", led);
                err = err + 1;
            end
        end
    endtask

    initial begin
        err          = 0;
        mode_sel     = 2'd0;
        wt_edit_sel  = 2'd0;
        sw_run_stop  = 1'b0;
        sr04_valid   = 1'b0;
        dht_valid    = 1'b0;
        dht_dbg_step = 6'd0;
        #10;

        $display("\n===== tb_led_status =====");

        //---------------- 1) 모드 one-hot ----------------
        $display("\n[1] led[3:0] 이 현재 모드 one-hot 인가");
        mode_sel = 2'd0; #1;
        ok(led[3:0] === 4'b0001); $display("스톱워치 -> 0001");
        mode_sel = 2'd1; #1;
        ok(led[3:0] === 4'b0010); $display("시계 -> 0010");
        mode_sel = 2'd2; #1;
        ok(led[3:0] === 4'b0100); $display("SR04 -> 0100");

        //---------------- 2) 시계 편집 자리 ----------------
        $display("\n[2] led[5:4] 가 시계 편집 자리인가");
        mode_sel    = 2'd1;
        wt_edit_sel = 2'd2; #1;
        ok(led[5:4] === 2'd2); $display("edit_sel=2(hour) -> led[5:4]=10");
        wt_edit_sel = 2'd1; #1;
        ok(led[5:4] === 2'd1); $display("edit_sel=1(min) -> led[5:4]=01");

        //---------------- 3) led[6] DHT 체크섬 ----------------
        $display("\n[3] led[6] 이 DHT11 체크섬 결과인가");
        dht_valid = 1'b1; #1;
        ok(led[6] === 1'b1); $display("dht_valid=1 -> led[6]=1");
        dht_valid = 1'b0; #1;
        ok(led[6] === 1'b0); $display("dht_valid=0 -> led[6]=0");

        //---------------- 4) led[7] 모드별 의미 ----------------
        $display("\n[4] led[7] 이 모드에 따라 바뀌는가");
        mode_sel    = 2'd0;
        sw_run_stop = 1'b1;
        sr04_valid  = 1'b0; #1;
        ok(led[7] === 1'b1); $display("스톱워치 모드 -> led[7] = run_stop");
        mode_sel    = 2'd2;
        sw_run_stop = 1'b1;
        sr04_valid  = 1'b0; #1;
        ok(led[7] === 1'b0); $display("SR04 모드 -> led[7] = sr04_valid (run_stop 무시)");
        sr04_valid  = 1'b1; #1;
        ok(led[7] === 1'b1); $display("SR04 valid=1 -> led[7]=1");

        //---------------- 5) DHT11 모드 진단 표시 ----------------
        $display("\n[5] DHT11 모드에서 진단 표시로 바뀌는가");
        mode_sel     = 2'd3;
        dht_dbg_step = 6'b001111;  // 싱크까지 통과
        dht_valid    = 1'b0;
        wt_edit_sel  = 2'd3;       // 진단 표시에서는 무시돼야 한다
        sw_run_stop  = 1'b1; #1;
        ok(led === 8'b0_0_001111); $display("led = {0, dht_valid, dbg_step}");
        dht_valid = 1'b1; #1;
        ok(led === 8'b0_1_001111); $display("체크섬 통과 -> led[6]=1");
        dht_dbg_step = 6'b111111; #1;
        ok(led === 8'b0_1_111111); $display("전 단계 통과 -> 하위 6비트 모두 1");

        if (err == 0) $display("\n===== tb_led_status : ALL PASS =====\n");
        else $display("\n===== tb_led_status : %0d FAIL =====\n", err);
        $finish;
    end

endmodule
