# =============================================================================
# aio_fpga_top.xdc : Basys3 (xc7a35tcpg236-1) 핀 + 타이밍 제약
#
#   NAND 인터페이스는 "클럭 없는" 비동기 버스다. 타이밍은 컨트롤러가 클럭 수로
#   만들어 낸다 (nand_onfi_cycle 의 T_SU / T_PW / T_HD). 그래서 제약의 목적은
#   "플롭에서 핀까지의 지연이 그 클럭 수 계산을 깨지 않게 묶어 두는 것" 이다.
# =============================================================================

# ---------------- 클럭 ----------------
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -name sys_clk -period 10.000 [get_ports clk]

# ---------------- 핀 ----------------
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports btn_rst]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports sw_wp]
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports uart_rx]
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports uart_tx]

set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports {led[9]}]

# Pmod JB : DQ[7:0]
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports {nand_dq[0]}]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports {nand_dq[1]}]
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports {nand_dq[2]}]
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports {nand_dq[3]}]
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports {nand_dq[4]}]
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports {nand_dq[5]}]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports {nand_dq[6]}]
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports {nand_dq[7]}]

# Pmod JC : 제어
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports nand_ce_n]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports nand_cle]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports nand_ale]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports nand_we_n]
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports nand_re_n]
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports nand_wp_n]
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports nand_rb_n]

# R/B# 는 open-drain 이다. 밖에 풀업이 없으면 떠 버린다.
set_property PULLUP true [get_ports nand_rb_n]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# =============================================================================
# CPU : 멀티사이클 경로
#
#   이 CPU 는 명령 하나를 fetch -> decode -> execute (-> mem -> wb) 로 나눠 실행한다.
#   PC 와 레지스터 파일은 명령의 마지막 클럭에만 바뀌고, 거기서 출발한 값
#   (PC -> ROM -> 레지스터 읽기 -> ALU -> ...)이 어딘가에 "잡히는" 것은 빨라야
#   execute 의 끝, 즉 3 클럭 뒤다.
#       B-type          : PC 갱신                    execute 끝 (3 클럭 뒤)
#       Load / Store    : APB 마스터가 주소를 잡음   mem 첫 클럭 끝 (4 클럭 뒤)
#       그 외           : 레지스터 파일 쓰기         wb 끝 (4 클럭 이상 뒤)
#   fetch / decode 에서는 PC 에도, 레지스터 파일에도, 버스에도 아무것도 잡히지 않는다.
#   STA 는 이 사정을 모르고 1 클럭 경로로 본다 (제약 없이 돌리면 WNS -4.6 ns).
#   그래서 "PC / 레지스터 파일에서 출발하는 경로는 3 클럭짜리" 라고 알려 준다.
#
#   -hold 2 : setup 을 3 클럭으로 늘리면 hold 검사 엣지도 같이 밀린다.
#             hold 는 원래대로 출발 엣지에서 검사하도록 되돌린다 (setup N 이면 hold N-1).
#
#   [이 제약은 "fetch 와 decode 가 있다" 는 가정 위에 서 있다]
#   control_unit 의 상태를 줄이면 이 제약은 거짓이 되고, STA 는 통과하는데 칩은
#   죽는다. 그래서 tb_aio_soc 의 a_cpu_multicycle assertion 이 "PC 가 바뀐 뒤
#   2 클럭 동안은 아무것도 잡지 않는다" 를 시뮬레이션에서 계속 확인한다.
#
#   반대 방향(버스에서 읽어 온 값 -> 레지스터 파일, 상태기계 -> enable)은
#   1 클럭 경로 그대로다. -from 만 걸었기 때문에 영향받지 않는다.
# =============================================================================
set cpu_state_regs [get_cells -hierarchical -filter {IS_SEQUENTIAL && (NAME =~ *U0_DATAPATH/U4_PC/register_pc_reg* || NAME =~ *U0_DATAPATH/U0_REG_FILE/ram_file_reg*)}]
set_multicycle_path -setup 3 -from $cpu_state_regs
set_multicycle_path -hold  2 -from $cpu_state_regs

# =============================================================================
# NAND 출력 : CE# CLE ALE WE# RE# WP# DQ(out)
#
#   NAND 가 보는 것은 출력 핀들 "사이의" 시간 관계다. 클럭 핀으로부터의 절대
#   지연은 의미가 없다 (NAND 에는 클럭이 가지 않는다).
#     예) tDH = WE# 가 올라간 뒤 DQ 가 유지되는 시간. 설계값은 2 클럭 = 20 ns,
#         부품 요구는 5 ns. 여유 15 ns. 이것이 가장 작은 여유다.
#   플롭 -> 핀 지연이 핀마다 다르면 그 차이(skew)만큼 여유가 깎인다.
#   그래서 모든 NAND 출력이 클럭 엣지 뒤 [2 ns, 13 ns] 창 안에 나오도록 묶는다.
#     -max -3.0 : 도착 <= 10 - (-3) = 13 ns
#     -min -2.0 : 도착 >= 2 ns
#   -> 출력 간 skew <= 11 ns < 15 ns.
#
#   창이 클럭 주기(10 ns)를 넘어가도 괜찮다. 받는 쪽이 우리 클럭으로 잡는 것이
#   아니기 때문이다. 처음에는 [1, 7] ns 로 잡았다가 post-route 에서 -4.3 ns 위반이
#   났다. 클럭 삽입 지연(핀 -> BUFG -> 플롭)과 출력 버퍼만으로 11 ns 가 나온다.
#   절대 지연을 조일 이유가 없는 곳을 조인 것이어서 제약 쪽을 고쳤다.
#
#   출력 플롭은 I/O 블록 안에 넣어(IOB) 지연을 고르게 만든다. DQ 의 3-state
#   제어(nand_dq_oe)는 플롭 하나가 8 핀을 몰아서 IOB 에 못 들어간다
#   ([Constraints 18-5573] 경고 8 건). 방향 전환이 1~2 ns 늦어질 뿐이고
#   위 창 안에 들어오므로 그대로 둔다.
# =============================================================================
set nand_outs [get_ports {nand_ce_n nand_cle nand_ale nand_we_n nand_re_n nand_wp_n nand_dq[*]}]
set_output_delay -clock sys_clk -max -3.000 $nand_outs
set_output_delay -clock sys_clk -min -2.000 $nand_outs
set_property IOB TRUE [get_ports {nand_ce_n nand_cle nand_ale nand_we_n nand_re_n nand_wp_n nand_dq[*]}]

# =============================================================================
# NAND 입력 : DQ(in)
#
#   컨트롤러는 RE# 를 내린 엣지(L)로부터 T_PW 클럭 뒤의 엣지에서 DQ 를 잡는다.
#
#       L : RE# 플롭이 0 으로 바뀐다
#       L + RE# 핀 도착 (최대 13 ns : 위 출력 창의 상한)
#         + tREA (NAND 가 데이터를 내놓는 시간, 20 ns)
#         + 보드 왕복 (1 ns 로 잡음)          = 34 ns 뒤에 DQ 핀에 데이터가 선다
#
#   T_PW = 3 (30 ns) 이면 데이터가 서기도 전에 잡는다. 시뮬레이션에서는 핀 지연이
#   0 이라 3 으로도 통과하지만, 실제 I/O 지연을 넣으면 모자란다.
#   그래서 FPGA 빌드는 T_PW = 4 (40 ns) 로 올렸다 (aio_fpga_top 의 파라미터).
#   읽기 한 바이트가 10 ns 느려지는 대신 6 ns 의 여유가 생긴다.
#
#   이것을 "입력 지연 34 ns + setup 4 cycle 경로" 로 적는다.
#   T_PW 를 바꾸면 아래 multicycle 값도 같이 바꿔야 한다.
#
#   hold 쪽 : 잡는 엣지에 RE# 가 올라가고, NAND 는 그 뒤로도 tRHOH(15 ns) 동안
#   데이터를 유지한다. 그래서 hold 는 구조적으로 넉넉하다. 데이터가 L 직후에
#   바뀌기 시작할 수 있다고 보고 min 을 0 으로 둔다.
# =============================================================================
set_input_delay -clock sys_clk -max 34.000 [get_ports {nand_dq[*]}]
set_input_delay -clock sys_clk -min  0.000 [get_ports {nand_dq[*]}]
set_multicycle_path -setup 4 -from [get_ports {nand_dq[*]}]
set_multicycle_path -hold  3 -from [get_ports {nand_dq[*]}]

# =============================================================================
# 비동기 입력 / 느린 출력 : 타이밍 분석에서 뺀다 (전부 2단 동기화기를 거친다)
# =============================================================================
set_false_path -from [get_ports btn_rst]
set_false_path -from [get_ports sw_wp]
set_false_path -from [get_ports nand_rb_n]
set_false_path -from [get_ports uart_rx]
set_false_path -to   [get_ports uart_tx]
set_false_path -to   [get_ports {led[*]}]
