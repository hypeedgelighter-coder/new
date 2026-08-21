`timescale 1ns / 1ps

//=====================================================================
// tb_watch_datapath  -  watch_datapath 단독 무작위 테스트벤치
//
//  대상 : watch_datapath.v
//         항상 돌아가는 시계. edit_sel 로 고른 자리를 up/down 으로 조정.
//         hour 는 INIT_VAL=12 라서 리셋/클리어하면 12 시로 돌아간다.
//
//  시뮬에서는 TICK_100HZ 를 12 로 줄인다.
//  자리올림에 시간차가 있으므로(tb_stopwatch_datapath 주석 참고) tick 이
//  지나고 6클럭 뒤에만 비교하고, up/down/clear 도 그 시점에만 준다.
//  (실제로도 버튼은 tick 에 비하면 아주 가끔 눌린다)
//
//  [무작위로 만드는 것]
//    tick 한 칸마다 edit_sel(0~3) / up / down / clear 를 무작위로.
//    edit_sel=3 은 어느 자리도 고르지 않은 상태라 아무 것도 변하면 안 된다.
//
//  [검사]
//    1) 참조 모델과 msec/sec/min/hour 비교
//    2) 리셋/클리어 직후 hour 가 12 인가
//    3) up 으로 한 자리를 한 바퀴 돌려도 옆 자리로 자리올림이 새지 않는가
//       (초를 59 -> 0 으로 올려도 분은 그대로여야 한다)
//    4) 23:59:59.99 를 만들어 두고 tick 한 번 -> 00:00:00.00 자리올림 전수
//=====================================================================
module tb_watch_datapath ();

    localparam integer TICK   = 12;
    localparam integer SETTLE = 6;
    localparam integer N_STEP = 2500;

    reg clk = 1'b0;
    reg reset;
    reg [1:0] edit_sel;
    reg clear, up, down;

    wire [6:0] msec;
    wire [5:0] sec, min;
    wire [4:0] hour;

    wire ref_tick;

    integer m_ms, m_s, m_mi, m_h;

    integer seed, seed0;
    integer errors, checks;
    integer i;
    integer save_min;

    always #5 clk = ~clk;

    watch_datapath #(
        .TICK_100HZ(TICK)
    ) DUT (
        .clk     (clk),
        .reset   (reset),
        .edit_sel(edit_sel),
        .clear   (clear),
        .up      (up),
        .down    (down),
        .msec    (msec),
        .sec     (sec),
        .min     (min),
        .hour    (hour)
    );

    tick_gen_100hz #(
        .F_COUNT(TICK)
    ) REF_TICK (
        .clk   (clk),
        .reset (reset),
        .o_tick(ref_tick)
    );

    task chk(input cond, input [8*30:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  dut=%02d:%02d:%02d.%02d  ref=%02d:%02d:%02d.%02d",
                             $time, tag, hour, min, sec, msec, m_h, m_mi, m_s, m_ms);
            end
        end
    endtask

    //---------------- 참조 모델 ----------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            m_ms <= 0; m_s <= 0; m_mi <= 0; m_h <= 12;
        end else if (clear) begin
            m_ms <= 0; m_s <= 0; m_mi <= 0; m_h <= 12;
        end else if (up || down) begin
            // 고른 자리만 바뀐다. 자리올림은 나가지 않는다.
            // (msec 은 up/down 대상이 아니고, tick 없는 클럭에만 누른다)
            case (edit_sel)
                2'd0: m_s  <= up ? ((m_s  == 59) ? 0  : m_s  + 1)
                                 : ((m_s  == 0)  ? 59 : m_s  - 1);
                2'd1: m_mi <= up ? ((m_mi == 59) ? 0  : m_mi + 1)
                                 : ((m_mi == 0)  ? 59 : m_mi - 1);
                2'd2: m_h  <= up ? ((m_h  == 23) ? 0  : m_h  + 1)
                                 : ((m_h  == 0)  ? 23 : m_h  - 1);
                default: ;  // 아무 자리도 안 고름
            endcase
        end else if (ref_tick) begin
            if (m_ms == 99) begin
                m_ms <= 0;
                if (m_s == 59) begin
                    m_s <= 0;
                    if (m_mi == 59) begin
                        m_mi <= 0;
                        m_h  <= (m_h == 23) ? 0 : m_h + 1;
                    end else m_mi <= m_mi + 1;
                end else m_s <= m_s + 1;
            end else m_ms <= m_ms + 1;
        end
    end

    task step;
        begin
            @(negedge clk);
            while (ref_tick !== 1'b1) @(negedge clk);
            repeat (SETTLE) @(negedge clk);
        end
    endtask

    task compare;
        begin
            chk(msec === m_ms[6:0], "msec mismatch");
            chk(sec  === m_s[5:0],  "sec mismatch");
            chk(min  === m_mi[5:0], "min mismatch");
            chk(hour === m_h[4:0],  "hour mismatch");
        end
    endtask

    // tick 사이의 안전한 자리에서 1클럭 펄스를 준다
    task press(input is_up, input [1:0] s);
        begin
            edit_sel = s;
            up       = is_up;
            down     = ~is_up;
            @(negedge clk);
            up   = 1'b0;
            down = 1'b0;
        end
    endtask

    task do_clear;
        begin
            clear = 1'b1;
            @(negedge clk);
            clear = 1'b0;
        end
    endtask

    initial begin
        seed0  = 32'h3A_7C0C12;
        seed   = seed0;
        errors = 0;
        checks = 0;

        reset    = 1'b1;
        edit_sel = 2'd0;
        clear    = 1'b0;
        up       = 1'b0;
        down     = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);

        compare;
        chk(hour === 5'd12, "hour is not 12 after reset");

        //---------------- 1) 한 자리를 한 바퀴 돌려도 옆으로 안 샌다 ----------------
        do_clear;
        step;
        save_min = min;
        for (i = 0; i < 60; i = i + 1) begin  // 초를 60번 올리면 제자리
            step;
            press(1'b1, 2'd0);
            compare;
        end
        chk(min === save_min[5:0], "sec wrap leaked a carry into min");

        //---------------- 2) 23:59:59.99 만들어서 자리올림 전수 ----------------
        //  누르는 횟수를 최소로 한다. 누르는 동안에도 시계는 계속 돌기
        //  때문에 msec 이 한 바퀴(100칸) 돌기 전에 세팅을 끝내야 한다.
        //    hour 12 -> 23 : up 11번
        //    min  0  -> 59 : down 1번 (0 에서 내리면 59 로 랩)
        //    sec  0  -> 59 : down 1번
        do_clear;
        step;
        for (i = 0; i < 11; i = i + 1) begin press(1'b1, 2'd2); step; end  // 12 -> 23
        press(1'b0, 2'd1); step;                                          // min -> 59
        press(1'b0, 2'd0); step;                                          // sec -> 59
        compare;
        chk(hour === 5'd23 && min === 6'd59 && sec === 6'd59,
            "failed to set 23:59:59");

        // msec 이 99 가 될 때까지 그냥 돌린다
        while (msec !== 7'd99) begin
            step;
            compare;
        end
        step;  // 여기서 네 자리 전부 자리올림
        compare;
        chk(hour === 5'd0 && min === 6'd0 && sec === 6'd0 && msec === 7'd0,
            "carry chain at 23:59:59.99 failed");

        //---------------- 3) 무작위 ----------------
        for (i = 0; i < N_STEP; i = i + 1) begin
            step;
            compare;
            edit_sel = {$random(seed)} % 4;  // 3 = 아무 자리도 안 고름
            if (({$random(seed)} % 6) == 0) begin
                if (({$random(seed)} % 2) == 0) press(1'b1, edit_sel);
                else                            press(1'b0, edit_sel);
            end
            if (({$random(seed)} % 200) == 0) do_clear;
        end

        $display("  final %02d:%02d:%02d.%02d", hour, min, sec, msec);
        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_watch_datapath : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_watch_datapath : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #20_000_000;
        $display("  tb_watch_datapath : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
