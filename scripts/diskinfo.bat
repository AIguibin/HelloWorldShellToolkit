@echo off
chcp 65001 >nul 2>&1
REM ============================================================
REM /diskinfo - 查看磁盘空间信息 (Batch)
REM
REM 用法:
REM   /diskinfo
REM ============================================================

setlocal enabledelayedexpansion

set "AIGUIBIN_TASK_ID=%AIGUIBIN_TASK_ID%"
set "AIGUIBIN_OUTPUT_DIR=%AIGUIBIN_OUTPUT_DIR%"

echo ==================================================
echo   Disk Space Information
echo ==================================================
echo.

REM Use wmic for clean output
for /f "tokens=1-3 delims=" %%a in ('wmic logicaldisk get caption^,freespace^,size /format:csv 2^>nul ^| findstr /r ".*:"') do (
    for /f "tokens=1-3 delims=," %%x in ("%%a") do (
        set "drive=%%x"
        set "free=%%y"
        set "size=%%z"
        if defined free (
            REM Convert bytes to GB (approximate)
            set /a "free_gb=!free:~0,-9!+0" 2>nul
            set /a "size_gb=!size:~0,-9!+0" 2>nul
            echo   !drive!  !free_gb! GB free / !size_gb! GB total
        )
    )
)

echo.

REM Output report
if defined AIGUIBIN_OUTPUT_DIR (
    echo Disk Space Report> "%AIGUIBIN_OUTPUT_DIR%\diskinfo_report.txt"
    echo Generated: %date% %time%>> "%AIGUIBIN_OUTPUT_DIR%\diskinfo_report.txt"
    echo.>> "%AIGUIBIN_OUTPUT_DIR%\diskinfo_report.txt"
    wmic logicaldisk get caption,freespace,size /format:list>> "%AIGUIBIN_OUTPUT_DIR%\diskinfo_report.txt" 2>nul
    echo   Report saved: %AIGUIBIN_OUTPUT_DIR%\diskinfo_report.txt
)

endlocal
