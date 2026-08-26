#=====================================================================
#  add_tb.tcl  -  tb/ 폴더의 테스트벤치를 Vivado 프로젝트에 한 번에 등록
#
#  쓰는 법
#    1) Vivado 로 2026_08_15_all.xpr 를 연다
#    2) 아래 Tcl Console 에 이 줄을 붙여넣는다 (경로는 이 파일 위치)
#
#         source d:/work/26_AI_COMP_1/2026-08-15_all_in_one/tb/add_tb.tcl
#
#  하는 일
#    - sim_1 에 남아있던 예전 tb_top.v 등록을 떼어낸다
#    - tb/*.v 를 전부 Simulation Sources (sim_1) 로 넣는다
#    - 시뮬레이션 실행 시간을 "all" 로 바꾼다
#        (기본값 1000ns 로는 대부분의 테스트벤치가 끝까지 못 간다.
#         테스트벤치가 스스로 $finish 를 부르므로 all 로 두면 된다)
#    - 첫 Simulation Top 을 tb_top 으로 잡아 둔다
#
#  이후에는 Sources 창 > Simulation Sources 에서 돌리고 싶은 테스트벤치를
#  오른쪽 클릭 > Set as Top 하고 Run Simulation 하면 된다.
#=====================================================================

set tb_dir [file normalize [file dirname [info script]]]
puts "  tb 폴더 : $tb_dir"

# ---- 예전에 등록돼 있던 테스트벤치 정리 ----
foreach f [get_files -quiet -of_objects [get_filesets sim_1] *tb_*.v] {
    puts "  제거 : $f"
    remove_files -fileset sim_1 $f
}

# ---- tb/*.v 전부 등록 ----
set tb_files [lsort [glob -nocomplain -directory $tb_dir *.v]]
if {[llength $tb_files] == 0} {
    puts "  \[!\] tb 폴더에 .v 파일이 없습니다"
    return
}
add_files -fileset sim_1 -norecurse $tb_files
puts "  등록 : [llength $tb_files] 개"

# ---- 시뮬레이션은 $finish 까지 끝까지 돌린다 ----
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

# ---- 첫 Simulation Top ----
set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

update_compile_order -fileset sim_1

puts ""
puts "  끝났습니다. Sources > Simulation Sources 에서"
puts "  돌리고 싶은 테스트벤치를 Set as Top 하고 Run Simulation 하세요."
