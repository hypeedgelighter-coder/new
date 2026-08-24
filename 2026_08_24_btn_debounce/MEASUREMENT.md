# btnC 접점 바운스 ILA 실측 (2026-08-24)

Basys3(XC7A35T-1CPG236) 중앙 푸시버튼 `btnC`(U18)의 접점 바운스를
Vivado ILA로 실측하고, `btn_debounce.v`의 판정 창 8 ms가 타당한지 검증했다.

## 계측 구성

| 항목 | 값 |
|---|---|
| 계측기 | Vivado 2020.2, ILA v6.2 (`ila_0`) |
| 버퍼 심도 | 32 768 samples |
| probe | `btn_sync`(1) / `tick_1us`(1) / `ts_clk`(24) / `o_btn`(1) |
| 시스템 클럭 | 100 MHz |

ILA 버퍼 심도가 32 768로 고정이라 100 MHz 전수 포착 시 관측 창이
327.68 µs 뿐이다. ms 오더의 바운스를 담을 수 없으므로 storage
qualification(capture condition `tick_1us == 1`)으로 100:1 데시메이션하여
관측 창을 32.77 ms까지 확보했다. 두 모드를 상황에 따라 전환해 사용했다.

| 모드 | Capture mode | 분해능 | 관측 창 |
|---|---|---|---|
| 광역 | `BASIC` + `tick_1us == 1` | 1 µs | 32.77 ms |
| 정밀 | `ALWAYS` | 10 ns | 327.68 µs |

## 결과

| 엣지 | 시행 | 바운스 검출 | 발생률 |
|---|---|---|---|
| 상승 (누름) | 20 | 0 | 0 % |
| 하강 (뗌) | 25 | 7 | 28 % |

접점 폐로는 20회 모두 단조(monotonic)했다. 10 ns 분해능에서도 전이가
1회뿐이었다. 바운스는 접점 개로 시에만 나타났으며, 가동편이 스프링
복원력으로 튕기며 재접촉(re-make)하는 것이 원인이다.

### 최악 케이스 — `relw_15`

| Sample | 트리거 기준 | 전이 | 해석 |
|---|---|---|---|
| 2 000 | +0 µs | 1 → 0 | 접점 개로 (트리거) |
| 2 520 | +520 µs | 0 → 1 | 재접촉 |
| 6 512 | +4 512 µs | 1 → 0 | 최종 개로 |
| — | +30 767 µs | 없음 | 정상 상태 |

파형 원본은 `relw_15.ila`에 있다. 다시 보려면:

```tcl
display_hw_ila_data [read_hw_ila_data {relw_15.ila}]
```

## 설계 판정

`debounce = &q_reg`(AND-reduction) 구조에서 오검출을 유발하는 것은 바운스의
총 길이가 아니라 **바운스 도중 입력이 논리 1을 연속 유지한 최장 구간**이다.
이 구간이 판정 창을 넘기면 가짜 `o_btn` 펄스가 나간다.

```
T_remake,max = 4 512 − 520 = 3.992 ms   (실측)
T_guard      = 8 tap × 1 ms = 8.000 ms  (설계)
```

| Tap | T_guard | 마진 | 판정 |
|---|---|---|---|
| 8 | 8.000 ms | 2.00× | 채택 |
| 4 | 4.000 ms | 1.00× | 기각 |
| 2 | 2.000 ms | 0.50× | 기각 |

`SAMPLE_COUNT = 100_000`(1 ms) × 8 tap 구성을 유지한다. 4 tap으로 줄이면
마진이 소멸해 최악 시나리오가 그대로 통과한다.

## 한계

- 25회 중 3건(`relw_02`/`04`/`11`)은 pre-trigger 2 ms를 초과해 사건 시작점이
  절단되었다. 실제 `T_remake,max`는 위 값 이상일 수 있다.
  `CONTROL.TRIGGER_POSITION`을 16 000으로 올려 재측정하면 보완된다.
- `probe3`가 10 ns 폭 펄스인 `o_btn`이라 1 µs 데시메이션 모드에서 포착
  확률이 1/100이다. 45회 캡처 내내 검출되지 않았다. 레벨 신호인 `led_tgl`로
  교체하는 편이 낫다.
- 원본 CSV 덤프 46건(40 MB)은 저장소에서 제외했다.

## 재현

```tcl
set ila [get_hw_ilas hw_ila_1]
catch {stop_hw_ila $ila}

foreach n {btn_sync tick_1us o_btn} {
    set p [get_hw_probes $n -of_objects $ila]
    set_property TRIGGER_COMPARE_VALUE eq1'bX $p
    set_property CAPTURE_COMPARE_VALUE eq1'bX $p
}

set_property CONTROL.DATA_DEPTH       32768 $ila
set_property CONTROL.TRIGGER_POSITION 2000  $ila
set_property CONTROL.CAPTURE_MODE     BASIC $ila

# 하강 엣지(뗌) 트리거 — 바운스는 여기서만 나온다
set_property TRIGGER_COMPARE_VALUE eq1'bF [get_hw_probes btn_sync -of_objects $ila]
set_property CAPTURE_COMPARE_VALUE eq1'b1 [get_hw_probes tick_1us -of_objects $ila]

run_hw_ila $ila
wait_on_hw_ila $ila
display_hw_ila_data [upload_hw_ila_data $ila]
```
