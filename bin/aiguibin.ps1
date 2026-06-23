# ============================================================
#  AIguibin Agent System v3.5 - Global Entry Point (PowerShell)
#
#  Python search priority:
#    1. Embedded Python (AIGUIBIN_CLI_HOME\python\python.exe)
#    2. .venv Python (AIGUIBIN_CLI_HOME\.venv\Scripts\python.exe)
#    3. System Python (python)
#
#  Usage:
#    aiguibin              Start interactive CLI
#    aiguibin /hello       Run a command
#    aiguibin /build --target=release
#
#  Setup:
#    1. Run install.bat to auto-configure
#    2. Or add this file's directory to system PATH
#    3. To run directly: .\aiguibin.ps1  or  aiguibin.ps1
#    4. To add .PS1 to PATHEXT (run once in admin PS):
#       [Environment]::SetEnvironmentVariable('PATHEXT', "$env:PATHEXT;.PS1", 'User')
# ============================================================

# AIGUIBIN_CLI_HOME: install directory (parent of bin/)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AiguibinHome = (Resolve-Path (Join-Path $ScriptDir "..")).Path

# Set environment variables
$env:AIGUIBIN_CLI_HOME = $AiguibinHome

# Set AIGUIBIN_BASH
$BashPath = Join-Path $AiguibinHome "git\usr\bin\bash.exe"
if (Test-Path $BashPath) {
    $env:AIGUIBIN_BASH = $BashPath
}

# Set AIGUIBIN_NODE
$NodePath = Join-Path $AiguibinHome "node\node.exe"
if (Test-Path $NodePath) {
    $env:AIGUIBIN_NODE = $NodePath
}

# Python search priority: embedded -> .venv -> system
$EmbeddedPython = Join-Path $AiguibinHome "python\python.exe"
$VenvPython = Join-Path $AiguibinHome ".venv\Scripts\python.exe"

if (Test-Path $EmbeddedPython) {
    $Python = $EmbeddedPython
    $env:AIGUIBIN_PYTHON = $Python
} elseif (Test-Path $VenvPython) {
    $Python = $VenvPython
} else {
    $Python = "python"
}

# Execute aiguibin.py, passing all command line arguments
$AiguibinPy = Join-Path $AiguibinHome "aiguibin.py"

if (-not (Test-Path $AiguibinPy)) {
    Write-Host "ERROR: aiguibin.py not found at $AiguibinPy" -ForegroundColor Red
    Write-Host "  Please check your installation." -ForegroundColor Yellow
    exit 1
}

& $Python $AiguibinPy @args
