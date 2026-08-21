## Basys3 제약 파일 - 통합 top.v 용
## 보드 실물 배치
##   보드 정면 기준, 스위치는 오른쪽 끝이 SW0 이고 왼쪽으로 갈수록 번호가 커진다.
##
##   sw[0] 오른쪽 1번째 : 자릿수 표시모드 (0 = SS.mm 초.밀리초 / 1 = HH.MM 시.분)
##   sw[1] 오른쪽 2번째 : 시계
##   sw[2] 오른쪽 3번째 : SR04 (거리)
##   sw[3] 오른쪽 4번째 : DHT11 (온습도)
##      -> sw[3:1] one-hot, 낮은 번호 우선. 전부 내리면 스톱워치.
##   BTNC 가운데 버튼  : 전체 reset (SW15는 사용하지 않음)
##
##   Pmod JB1(A14) = SR04 trigger
##   Pmod JB2(A16) = SR04 echo
##   Pmod JA1(J1)  = DHT11 data (양방향)
##   ※ SR04 는 5V 센서다. echo 출력을 그대로 FPGA 에 물리면 안 되고
##     분압저항(예: 1k / 2k) 으로 3.3V 로 낮춰서 넣을 것.

## ------------------------- Clock -------------------------
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ------------------------- Switches -------------------------
## Basys3 실크스크린은 오른쪽 끝이 SW0, 왼쪽 끝이 SW15 다.
## 아래 주석의 "오른쪽 N번째" 는 보드를 정면에서 봤을 때 기준.
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]  ;# 오른쪽 1번째 : 자릿수 표시모드
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]  ;# 오른쪽 2번째 : 시계
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]  ;# 오른쪽 3번째 : SR04
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]  ;# 오른쪽 4번째 : DHT11

## ------------------------- LEDs -------------------------
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {led[7]}]

## ------------------------- 7 Segment Display -------------------------
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports {fnd_data[0]}]
set_property -dict { PACKAGE_PIN W6   IOSTANDARD LVCMOS33 } [get_ports {fnd_data[1]}]
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS33 } [get_ports {fnd_data[2]}]
set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS33 } [get_ports {fnd_data[3]}]
set_property -dict { PACKAGE_PIN U5   IOSTANDARD LVCMOS33 } [get_ports {fnd_data[4]}]
set_property -dict { PACKAGE_PIN V5   IOSTANDARD LVCMOS33 } [get_ports {fnd_data[5]}]
set_property -dict { PACKAGE_PIN U7   IOSTANDARD LVCMOS33 } [get_ports {fnd_data[6]}]
set_property -dict { PACKAGE_PIN V7   IOSTANDARD LVCMOS33 } [get_ports {fnd_data[7]}]

set_property -dict { PACKAGE_PIN U2   IOSTANDARD LVCMOS33 } [get_ports {fnd_com[0]}]
set_property -dict { PACKAGE_PIN U4   IOSTANDARD LVCMOS33 } [get_ports {fnd_com[1]}]
set_property -dict { PACKAGE_PIN V4   IOSTANDARD LVCMOS33 } [get_ports {fnd_com[2]}]
set_property -dict { PACKAGE_PIN W4   IOSTANDARD LVCMOS33 } [get_ports {fnd_com[3]}]

## ------------------------- Buttons -------------------------
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports reset]   ;# BTNC : 전체 reset
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports btn_U]
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports btn_L]
set_property -dict { PACKAGE_PIN T17  IOSTANDARD LVCMOS33 } [get_ports btn_R]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btn_D]

## ------------------------- USB-RS232 (PC UART) -------------------------
set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports rx]
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports tx]

## ------------------------- Pmod JB : HC-SR04 -------------------------
set_property -dict { PACKAGE_PIN A14  IOSTANDARD LVCMOS33 } [get_ports trigger]
set_property -dict { PACKAGE_PIN A16  IOSTANDARD LVCMOS33 } [get_ports echo]
set_property PULLDOWN true [get_ports echo]

## ------------------------- Pmod JA : DHT11 -------------------------
## 오픈드레인 1-wire. DATA-3.3V 사이 외부 4.7~5.1k 풀업 필요.
## 아래 내부 PULLUP은 약한 백업이며 외부 저항을 대체하지 않는다.
## DHT11 모듈을 5V로 구동해 DATA도 5V로 풀업되면 FPGA 핀에 연결 금지.
##
## JA 커넥터 핀 배치 (윗줄 왼쪽부터)
##   JA1=J1  JA2=L2  JA3=J2  JA4=G2  JA5=GND  JA6=VCC(3.3V)
## DATA 를 JA1, 전원을 JA6, 접지를 JA5 에 연결한다.
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports dht11_io]
set_property PULLUP true [get_ports dht11_io]

## ------------------------- Config -------------------------
set_property CFGBVS VCCO        [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
