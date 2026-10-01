# =============================================================================
# impl_fpga.tcl : aio_fpga_top (SoC 전체) 을 합성 -> 배치 -> 배선까지 돌리고 보고서를 남긴다
#
#   vivado -mode batch -source syn/impl_fpga.tcl
#   (또는 scripts/run_impl.ps1)
#
#   syn/synth.tcl 은 NAND 코어만 합성해서 "합성 직후 추정치" 를 본다.
#   이 스크립트는 CPU 까지 포함한 칩 전체를 실제 핀 / I/O 타이밍 제약과 함께
#   배선까지 끝낸 뒤의 숫자(post-route)를 본다. 타이밍은 이 숫자가 진짜다.
#
#   결과 : build/impl/
#     utilization.rpt           자원 사용량
#     utilization_hier.rpt      블록별 사용량 (CPU / NAND 코어 / PHY ...)
#     timing_summary.rpt        WNS / WHS
#     timing_nand_io.rpt        NAND 핀 입출력 경로
#     timing_worst_paths.rpt    가장 느린 경로 10 개
#     aio_fpga_top_routed.dcp
# =============================================================================
set root_dir [file normalize [file join [file dirname [info script]] ..]]
set out_dir  [file normalize [file join $root_dir build impl]]
file mkdir $out_dir

set part xc7a35tcpg236-1
set top  aio_fpga_top

# ---- 소스 : flist/soc.f 가 컴파일 순서(패키지 먼저)를 쥐고 있다 ----
set fh [open [file join $root_dir flist soc.f] r]
while {[gets $fh line] >= 0} {
    set line [string trim $line]
    if {$line eq "" || [string index $line 0] eq "#"} { continue }
    read_verilog -sv [file join $root_dir $line]
}
close $fh
read_verilog -sv [file join $root_dir rtl soc aio_fpga_top.sv]
read_xdc [file join $root_dir syn aio_fpga_top.xdc]

# ---- 펌웨어 : $readmemh 가 찾을 수 있게 절대 경로를 generic 으로 넘긴다 ----
set rom_file [file join $root_dir sw fw.hex]
if {![file exists $rom_file]} {
    error "sw/fw.hex 가 없다. sw/ 에서 make 를 먼저 돌려라."
}

synth_design -top $top -part $part -generic "ROM_FILE=\"$rom_file\"" -verilog_define SYNTHESIS
report_utilization -file [file join $out_dir utilization_synth.rpt]

opt_design
place_design
phys_opt_design
route_design

report_utilization                 -file [file join $out_dir utilization.rpt]
report_utilization -hierarchical   -file [file join $out_dir utilization_hier.rpt]
report_timing_summary -delay_type min_max -max_paths 10 -file [file join $out_dir timing_summary.rpt]
report_timing -delay_type max -max_paths 10 -nworst 1 -file [file join $out_dir timing_worst_paths.rpt]
report_timing -delay_type min_max -max_paths 40 \
    -through [get_ports {nand_*}] -file [file join $out_dir timing_nand_io.rpt]
report_methodology -file [file join $out_dir methodology.rpt]
write_checkpoint -force [file join $out_dir ${top}_routed.dcp]

# ---- 요약 (로그에서 바로 읽을 수 있게) ----
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
puts "IMPL_RESULT: setup WNS = $wns ns"
puts "IMPL_RESULT: hold  WHS = $whs ns"
set worst [get_timing_paths -delay_type max -max_paths 1]
puts "IMPL_RESULT: worst path  [get_property STARTPOINT_PIN $worst] -> [get_property ENDPOINT_PIN $worst]"
puts "IMPL_RESULT: logic levels = [get_property LOGIC_LEVELS $worst]"

# ---- 경로 종류별 최악 slack ----
set cpu_regs [get_cells -hierarchical -filter {IS_SEQUENTIAL && (NAME =~ *U0_DATAPATH/U4_PC/register_pc_reg* || NAME =~ *U0_DATAPATH/U0_REG_FILE/ram_file_reg*)}]
set p [get_timing_paths -delay_type max -max_paths 1 -from $cpu_regs]
puts "IMPL_RESULT: CPU multicycle paths    slack = [get_property SLACK $p] ns  (datapath [get_property DATAPATH_DELAY $p] ns, [get_property LOGIC_LEVELS $p] levels)"
set p [get_timing_paths -delay_type max -max_paths 1 -from [get_cells -hierarchical -filter {IS_SEQUENTIAL && NAME =~ *U6_NAND*}] -to [all_registers -data_pins]]
puts "IMPL_RESULT: NAND IP internal paths  slack = [get_property SLACK $p] ns  ([get_property STARTPOINT_PIN $p] -> [get_property ENDPOINT_PIN $p], [get_property LOGIC_LEVELS $p] levels)"
set p [get_timing_paths -delay_type max -max_paths 1 -to [get_ports {nand_*}]]
puts "IMPL_RESULT: NAND outputs latest     slack = [get_property SLACK $p] ns  ([get_property ENDPOINT_PIN $p])"
set p [get_timing_paths -delay_type min -max_paths 1 -to [get_ports {nand_*}]]
puts "IMPL_RESULT: NAND outputs earliest   slack = [get_property SLACK $p] ns  ([get_property ENDPOINT_PIN $p])"
set p [get_timing_paths -delay_type max -max_paths 1 -from [get_ports {nand_dq[*]}]]
puts "IMPL_RESULT: NAND DQ input setup     slack = [get_property SLACK $p] ns"
set p [get_timing_paths -delay_type min -max_paths 1 -from [get_ports {nand_dq[*]}]]
puts "IMPL_RESULT: NAND DQ input hold      slack = [get_property SLACK $p] ns"
set p [get_timing_paths -delay_type max -max_paths 1 -from [get_cells rst_sync_reg*]]
puts "IMPL_RESULT: reset recovery          slack = [get_property SLACK $p] ns  ([get_property ENDPOINT_PIN $p])"
puts "IMPL_RESULT: reports written to $out_dir"
