create_clock -name pclk -period 10.000 [get_ports pclk]
set_false_path -from [get_ports presetn]
