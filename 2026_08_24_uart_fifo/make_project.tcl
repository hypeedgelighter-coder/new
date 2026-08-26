#=====================================================================
#  make_project.tcl  -  이 폴더만으로 Vivado 프로젝트를 새로 만든다
#
#  쓰는 법
#    Vivado 를 열고 Tcl Console 에 아래 한 줄
#
#      source d:/work/26_AI_COMP_1/2026_08_24_uart_fifo/make_project.tcl
#
#  하는 일
#    - 이 폴더에 2026_08_24_uart_fifo.xpr 프로젝트를 만든다 (Basys3)
#    - 설계 파일 6개를 Design Sources 로, tb/*.v 를 Simulation Sources 로 넣는다
#    - 시뮬레이션 실행 시간을 all 로 바꾼다
#        (기본값 1000ns 로는 테스트벤치가 끝까지 못 간다.
#         테스트벤치가 스스로 $finish 를 부르므로 all 로 두면 된다)
#    - Simulation Top 을 tb_uart_comm 으로 잡아 둔다
#
#  이후에는 Sources 창 > Simulation Sources 에서 돌리고 싶은 테스트벤치를
#  오른쪽 클릭 > Set as Top 하고 Run Simulation 하면 된다.
#
#  ※ 이 폴더는 UART 경로만 떼어 낸 것이라 top.v / xdc 가 없다. 합성용이
#     아니라 시뮬레이션 전용이다. 최상위는 uart_comm.
#=====================================================================

set here [file normalize [file dirname [info script]]]
set pname 2026_08_24_uart_fifo

if {[file exists $here/$pname.xpr]} {
    puts "  이미 있습니다 : $here/$pname.xpr"
    puts "  지우고 다시 만들려면 파일과 ${pname}.cache/.sim/.srcs 폴더를 삭제하세요."
    return
}

create_project $pname $here -part xc7a35tcpg236-1

add_files -norecurse [list \
    $here/uart.v \
    $here/fifo.v \
    $here/uart_fifo.v \
    $here/ascii_decoder.v \
    $here/ascii_sender.v \
    $here/uart_comm.v ]
set_property top uart_comm [get_filesets sources_1]

set tb_files [lsort [glob -nocomplain -directory $here/tb *.v]]
add_files -fileset sim_1 -norecurse $tb_files
puts "  테스트벤치 [llength $tb_files] 개 등록"

# 테스트벤치가 스스로 $finish 를 부른다. 끝까지 돌린다.
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
set_property top tb_uart_comm [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "  끝났습니다. Sources > Simulation Sources 에서"
puts "  돌리고 싶은 테스트벤치를 Set as Top 하고 Run Simulation 하세요."
