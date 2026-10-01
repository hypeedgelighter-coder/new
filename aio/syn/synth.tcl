set root_dir [file normalize [file join [file dirname [info script]] ..]]
set out_dir  [file normalize [file join $root_dir build synth]]
file mkdir $out_dir

read_verilog -sv [file join $root_dir rtl ecc secded_ecc_32.sv]
read_verilog -sv [file join $root_dir rtl aio_nand_dma_ctrl.sv]
read_xdc [file join $root_dir syn timing.xdc]

synth_design -top aio_nand_dma_ctrl -part xc7a35tcpg236-1 -flatten_hierarchy rebuilt
opt_design

report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $out_dir timing_summary.rpt]
report_methodology -file [file join $out_dir methodology.rpt]
write_checkpoint -force [file join $out_dir aio_nand_dma_ctrl_synth.dcp]

set timing_paths [get_timing_paths -delay_type max -max_paths 1]
if {[llength $timing_paths] > 0} {
    set worst_slack [get_property SLACK [lindex $timing_paths 0]]
    puts "SYNTHESIS_RESULT: worst setup slack = $worst_slack ns"
}
puts "SYNTHESIS_RESULT: reports written to $out_dir"
