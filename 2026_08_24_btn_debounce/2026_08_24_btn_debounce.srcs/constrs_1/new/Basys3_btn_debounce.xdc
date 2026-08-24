## Basys3 - btn_debounce ILA 실험용 제약

## Clock 100MHz
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0.000 5.000} [get_ports clk]

## Buttons (Basys3 버튼은 pull-down, 누르면 '1')
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports i_btn]   ;# btnC
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports reset]   ;# btnU

## LEDs
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports o_btn_led] ;# led0
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports raw_led]   ;# led15

## Configuration
set_property CFGBVS VCCO        [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
