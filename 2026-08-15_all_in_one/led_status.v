`timescale 1ns / 1ps

//=====================================================================
// led_status  -  LED 8개 표시 로직 (조합회로. 클럭 없음)
//
//  평소
//    led[3:0] 현재 모드 (one-hot)   led[5:4] 시계 편집 자리
//    led[6]   DHT11 체크섬 정상      led[7]   SR04 valid 또는 스톱워치 RUN
//
//  DHT11 모드에서는 LED 를 진단 표시로 돌린다. 어느 단계까지 갔는지
//  오른쪽부터 순서대로 채워지므로, 꺼진 첫 자리가 실패 지점이다.
//    led[0] 측정 시작됨      led[1] 라인 High 복귀
//    led[2] 센서 응답 있음    led[3] 싱크 통과
//    led[4] 40비트 수신 완료  led[5] 체크섬 통과
//    led[6] 마지막 측정 valid (평소와 동일)
//  모드 표시가 필요 없는 이유 : DHT11 모드는 스위치를 직접 올린 상태다.
//=====================================================================
module led_status (
    input  [1:0] mode_sel,
    input  [1:0] wt_edit_sel,
    input        sw_run_stop,
    input        sr04_valid,
    input        dht_valid,
    input  [5:0] dht_dbg_step,

    output [7:0] led
);

    localparam MODE_STOPWATCH = 2'd0,
               MODE_WATCH     = 2'd1,
               MODE_SR04      = 2'd2,
               MODE_DHT11     = 2'd3;

    wire [7:0] led_normal;
    assign led_normal[3:0] = 4'b0001 << mode_sel;  // 현재 모드
    assign led_normal[5:4] = wt_edit_sel;          // 시계 편집 자리
    assign led_normal[6]   = dht_valid;            // DHT11 체크섬 정상
    assign led_normal[7]   = (mode_sel == MODE_SR04) ? sr04_valid
                                                     : sw_run_stop;

    assign led = (mode_sel == MODE_DHT11)
               ? {1'b0, dht_valid, dht_dbg_step}
               : led_normal;

endmodule
