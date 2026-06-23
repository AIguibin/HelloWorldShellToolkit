@echo off
echo ============================================================
echo   AIguibin Agent System v3.5 - Uninstaller
echo ============================================================
echo.

SET "INSTALL_DIR=%~dp0"
IF "%INSTALL_DIR:~-1%"=="\" SET "INSTALL_DIR=%INSTALL_DIR:~0,-1%"
SET "BIN_DIR=%INSTALL_DIR%\bin"

echo Install directory: %INSTALL_DIR%
echo.
echo The following will be removed:
echo   1. Remove %BIN_DIR% from user PATH
echo   2. Delete user environment variable AIGUIBIN_CLI_HOME
echo   3. Delete user environment variable AIGUIBIN_AGENT_DIR
echo   4. Delete .agent/ directory (application data)
echo   5. Delete git/ directory (Git Bash + git CLI)
echo   6. Delete node/ directory (embedded Node.js)
echo   7. Delete python/ directory (embedded Python)
echo   8. Delete .venv/ directory (if exists)
echo.
echo [NOTE] Config files, scripts, and task data will NOT be deleted
echo.

pause

REM --- 1. Remove from PATH ---
echo.
echo [1/8] Removing %BIN_DIR% from user PATH...
powershell -NoProfile -Command "$b='%BIN_DIR%'; $p=[Environment]::GetEnvironmentVariable('Path','User'); $n=(($p -split ';') | Where-Object {$_ -ne $b}) -join ';'; [Environment]::SetEnvironmentVariable('Path',$n,'User')"
echo        Done

REM --- 2. Delete AIGUIBIN_CLI_HOME env var ---
echo [2/8] Deleting user environment variable AIGUIBIN_CLI_HOME...
powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('AIGUIBIN_CLI_HOME',$null,'User')"
echo        Done

REM --- 3. Delete AIGUIBIN_AGENT_DIR env var ---
echo [3/8] Deleting user environment variable AIGUIBIN_AGENT_DIR...
powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('AIGUIBIN_AGENT_DIR',$null,'User')"
echo        Done

REM --- 4. Delete .agent/ ---
echo [4/8] Deleting .agent/ directory (application data)...
IF EXIST "%INSTALL_DIR%\.agent" (
    rmdir /s /q "%INSTALL_DIR%\.agent"
    echo        Deleted .agent/
) ELSE (
    echo        .agent/ does not exist, skipping
)

) ELSE (
    echo        .agent/ does not exist, skipping
)

REM --- 5. Delete git/ ---
echo [5/8] Deleting Git directory...
IF EXIST "%INSTALL_DIR%\git" (
    rmdir /s /q "%INSTALL_DIR%\git"
    echo        Deleted git/
) ELSE (
    echo        git/ does not exist, skipping
)

REM --- 6. Delete node/ ---
echo [6/8] Deleting Node.js directory...
IF EXIST "%INSTALL_DIR%\node" (
    rmdir /s /q "%INSTALL_DIR%\node"
    echo        Deleted node/
) ELSE (
    echo        node/ does not exist, skipping
)

REM --- 7. Delete python/ ---
echo [7/8] Deleting embedded Python directory...
IF EXIST "%INSTALL_DIR%\python" (
    rmdir /s /q "%INSTALL_DIR%\python"
    echo        Deleted python/
) ELSE (
    echo        python/ does not exist, skipping
)

REM --- 8. Delete .venv/ ---
echo [8/8] Deleting .venv directory...
IF EXIST "%INSTALL_DIR%\.venv" (
    rmdir /s /q "%INSTALL_DIR%\.venv"
    echo        Deleted .venv/
) ELSE (
    echo        .venv/ does not exist, skipping
)

echo.
echo ============================================================
echo   Uninstall complete! Please reopen your terminal.
echo ============================================================
pause
