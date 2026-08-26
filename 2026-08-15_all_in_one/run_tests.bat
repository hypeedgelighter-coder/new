@echo off
setlocal enabledelayedexpansion
chcp 65001 > nul
REM =====================================================================
REM  tb\ 안의 테스트벤치를 전부 순서대로 돌린다. (Vivado GUI 없이 명령줄로)
REM
REM   사용법 : 이 폴더에서 그냥 실행
REM              run_tests.bat              전부 돌리기
REM              run_tests.bat tb_fifo      하나만 돌리기
REM
REM   설계는 이 폴더의 *.v, 테스트벤치는 tb\*.v 를 컴파일한다.
REM   (tb_legacy\ 는 지금 것과 모듈 이름이 겹치므로 컴파일하지 않는다)
REM
REM   결과는 sim_work\<테스트벤치>.log 에 남는다.
REM   Vivado 설치 경로가 다르면 아래 VIVADO 만 고치면 된다.
REM =====================================================================

set VIVADO=C:\Xilinx\Vivado\2020.2\bin
set SRC=%~dp0
set WORK=%~dp0sim_work

if not exist "%VIVADO%\xvlog.bat" (
    echo [!] Vivado 를 못 찾았습니다 : %VIVADO%
    echo     이 파일 위쪽의 VIVADO 경로를 고쳐 주세요.
    exit /b 1
)

if not exist "%WORK%" mkdir "%WORK%"
cd /d "%WORK%"

REM ---------------- 컴파일 (한 번만) ----------------
set FILES=
for %%F in ("%SRC%*.v") do set FILES=!FILES! "%%F"
for %%F in ("%SRC%tb\*.v") do set FILES=!FILES! "%%F"

REM  xvlog 는 자기 로그를 xvlog.log 로 쓰므로 리다이렉트 파일명은 다르게 잡는다
REM  (같은 이름으로 겹치면 핸들을 못 열어서 실패로 끝난다)
echo === 컴파일 ===
call "%VIVADO%\xvlog.bat" !FILES! > compile.log 2>&1
if errorlevel 1 (
    echo [!] 컴파일 실패. sim_work\compile.log 를 보세요.
    findstr /C:"ERROR" compile.log
    exit /b 1
)
echo     OK

REM ---------------- 돌릴 목록 ----------------
REM  작은 모듈부터 큰 블록 순서. 인자를 주면 그것만 돌린다.
set LIST=%*
if "%~1"=="" (
    set LIST=tb_seg_decoder tb_decoder_2x4 tb_mux_4x1 tb_counter_4 tb_fnd_scan_tick
    set LIST=!LIST! tb_fnd_controller tb_fnd_display tb_led_status
    set LIST=!LIST! tb_tick_gen_1us tb_tick_gen_100hz tb_periodic_pulse tb_time_counter
    set LIST=!LIST! tb_btn_debounce tb_btn_unit
    set LIST=!LIST! tb_register_file tb_fifo_control_unit tb_fifo
    set LIST=!LIST! tb_baud_tick_gen tb_uart_rx tb_uart_tx tb_uart_fifo
    set LIST=!LIST! tb_ascii_decoder tb_ascii_sender tb_uart_comm
    set LIST=!LIST! tb_control_unit_stopwatch tb_control_unit_watch tb_main_control_unit
    set LIST=!LIST! tb_stopwatch_datapath tb_watch_datapath tb_time_datapath
    set LIST=!LIST! tb_sr04_controller tb_dht11_controller tb_sensor_unit
    set LIST=!LIST! tb_top
)

for %%T in (!LIST!) do (
    echo.
    echo ############################################################
    echo #  %%T
    echo ############################################################
    call "%VIVADO%\xelab.bat" -s %%T_sim %%T > %%T_elab.log 2>&1
    if errorlevel 1 (
        echo   [!] elaborate 실패 : sim_work\%%T_elab.log
    ) else (
        call "%VIVADO%\xsim.bat" %%T_sim -R > %%T.log 2>&1
        findstr /C:"ALL PASS" /C:"FAIL" /C:"TIMEOUT" %%T.log
    )
)

echo.
echo ============================================================
echo  요약
echo ============================================================
findstr /C:"ALL PASS" /C:"FAIL =====" tb_*.log
echo.
echo  (자세한 출력은 sim_work\ 안의 .log 파일)
endlocal
