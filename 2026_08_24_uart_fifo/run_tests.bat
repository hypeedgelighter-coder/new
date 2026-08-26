@echo off
setlocal enabledelayedexpansion
chcp 65001 > nul
REM =====================================================================
REM  UART / FIFO / ASCII 경로만 따로 떼어 낸 폴더의 테스트 실행기
REM
REM   사용법 : 이 폴더에서 그냥 실행
REM              run_tests.bat                 전부 돌리기
REM              run_tests.bat tb_fifo         하나만 돌리기
REM              run_tests.bat tb_fifo tb_uart_rx   여러 개
REM
REM   설계는 이 폴더의 *.v, 테스트벤치는 tb\*.v 를 컴파일한다.
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
    set LIST=tb_register_file tb_fifo_control_unit tb_fifo
    set LIST=!LIST! tb_baud_tick_gen tb_uart_rx tb_uart_tx tb_uart_fifo
    set LIST=!LIST! tb_ascii_decoder tb_ascii_sender tb_uart_comm
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
