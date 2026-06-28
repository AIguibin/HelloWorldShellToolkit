@echo off
REM ============================================================
REM  AIguibin Agent System v3.5 - Global Entry Point
REM
REM  Python search priority:
REM    1. Embedded Python (AIGUIBIN_CLI_HOME\python\python.exe)
REM    2. .venv Python (AIGUIBIN_CLI_HOME\.venv\Scripts\python.exe)
REM    3. System Python (python)
REM
REM  Runtime bootstrap:
REM    If embedded Python exists, runs core/bootstrap.py to
REM    auto-download Git portable and Node.js if missing.
REM
REM  Usage:
REM    aiguibin              Start interactive CLI
REM    aiguibin /hello       Run a command
REM    aiguibin /build --target=release
REM
REM  Setup:
REM    1. Run install.bat to auto-configure
REM    2. Or add this file's directory to system PATH
REM ============================================================

REM AIGUIBIN_CLI_HOME: install directory (parent of bin/)
SET "AIGUIBIN_CLI_HOME=%~dp0.."

REM Resolve to absolute path (remove trailing backslash from %~dp0)
FOR %%I IN ("%AIGUIBIN_CLI_HOME%") DO SET "AIGUIBIN_CLI_HOME=%%~fI"

REM --- Bootstrap: ensure Git and Node exist ---
IF EXIST "%AIGUIBIN_CLI_HOME%\python\python.exe" (
    "%AIGUIBIN_CLI_HOME%\python\python.exe" "%AIGUIBIN_CLI_HOME%\core\bootstrap.py"
)

REM Set AIGUIBIN_BASH, AIGUIBIN_PYTHON, and AIGUIBIN_NODE environment variables
IF EXIST "%AIGUIBIN_CLI_HOME%\git\usr\bin\bash.exe" (
    SET "AIGUIBIN_BASH=%AIGUIBIN_CLI_HOME%\git\usr\bin\bash.exe"
)
IF EXIST "%AIGUIBIN_CLI_HOME%\python\python.exe" (
    SET "AIGUIBIN_PYTHON=%AIGUIBIN_CLI_HOME%\python\python.exe"
)
IF EXIST "%AIGUIBIN_CLI_HOME%\node\node.exe" (
    SET "AIGUIBIN_NODE=%AIGUIBIN_CLI_HOME%\node\node.exe"
)

REM Python search priority: embedded -> .venv -> system
IF EXIST "%AIGUIBIN_CLI_HOME%\python\python.exe" (
    SET "PYTHON=%AIGUIBIN_CLI_HOME%\python\python.exe"
) ELSE IF EXIST "%AIGUIBIN_CLI_HOME%\.venv\Scripts\python.exe" (
    SET "PYTHON=%AIGUIBIN_CLI_HOME%\.venv\Scripts\python.exe"
) ELSE (
    SET "PYTHON=python"
)

REM --- Python encoding for Chinese support ---
SET "PYTHONIOENCODING=utf-8"
SET "PYTHONUTF8=1"

REM Execute aiguibin.py, passing all command line arguments
"%PYTHON%" "%AIGUIBIN_CLI_HOME%\aiguibin.py" %*
