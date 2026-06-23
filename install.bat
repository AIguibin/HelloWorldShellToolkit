@echo off
REM ============================================================
REM   AIguibin Agent System v3.5 - Installer
REM
REM   What it installs:
REM     1. Python Embeddable (standalone Python interpreter)
REM     2. Python packages (rich, pyyaml, pyreadline3, openpyxl)
REM     3. PortableGit (Git Bash + git CLI)
REM     4. Node.js 22.x LTS (portable)
REM     5. PATH environment variable
REM     6. Application data directory (.agent/)
REM
REM   Usage: Double-click this file, or run from cmd
REM ============================================================

echo.
echo ============================================================
echo   AIguibin Agent System v3.5 - Installer
echo ============================================================
echo.

REM --- 0. Determine install directory ---
SET "INSTALL_DIR=%~dp0"
IF "%INSTALL_DIR:~-1%"=="\" SET "INSTALL_DIR=%INSTALL_DIR:~0,-1%"

echo [0/14] Install directory: %INSTALL_DIR%
echo.

REM --- 1. Validate install path ---
echo [1/14] Validating install path...

REM Check for spaces in path
echo %INSTALL_DIR% | findstr /C:" " >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo [WARN] Path contains spaces - may cause issues
    echo        Recommended: use a path without spaces, e.g. D:\AIguibinCLI
    echo.
)

echo        Path validation passed
echo.

REM --- 2. Set AIGUIBIN_CLI_HOME environment variable ---
echo [2/14] Setting AIGUIBIN_CLI_HOME environment variable...
powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('AIGUIBIN_CLI_HOME', '%INSTALL_DIR%', 'User')"
SET "AIGUIBIN_CLI_HOME=%INSTALL_DIR%"
echo        AIGUIBIN_CLI_HOME = %AIGUIBIN_CLI_HOME%
echo.

REM --- 2.1 Set AIGUIBIN_AGENT_DIR environment variable and create directories ---
echo [2.1/14] Setting up application data directory...
powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('AIGUIBIN_AGENT_DIR', '%INSTALL_DIR%\.agent', 'User')"
SET "AIGUIBIN_AGENT_DIR=%INSTALL_DIR%\.agent"
echo        AIGUIBIN_AGENT_DIR = %AIGUIBIN_AGENT_DIR%

REM Create .agent/ directory structure
IF NOT EXIST "%AIGUIBIN_AGENT_DIR%" (
    mkdir "%AIGUIBIN_AGENT_DIR%"
    echo        Created .agent/ directory
)
IF NOT EXIST "%AIGUIBIN_AGENT_DIR%\logs" (
    mkdir "%AIGUIBIN_AGENT_DIR%\logs"
    echo        Created .agent/logs/ directory
)
echo        Application data directories ready
echo.

REM --- 2.2 Create dependency management directories ---
echo [2.2/14] Setting up dependency management directories...

REM Create config/dependencies/ directory
IF NOT EXIST "%INSTALL_DIR%\config" (
    mkdir "%INSTALL_DIR%\config"
    echo        Created config/ directory
)
IF NOT EXIST "%INSTALL_DIR%\config\dependencies" (
    mkdir "%INSTALL_DIR%\config\dependencies"
    echo        Created config/dependencies/ directory
)

REM Create tools/ directory structure
IF NOT EXIST "%INSTALL_DIR%\tools" (
    mkdir "%INSTALL_DIR%\tools"
    echo        Created tools/ directory
)
IF NOT EXIST "%INSTALL_DIR%\tools\binaries" (
    mkdir "%INSTALL_DIR%\tools\binaries"
    echo        Created tools/binaries/ directory
)
IF NOT EXIST "%INSTALL_DIR%\tools\python" (
    mkdir "%INSTALL_DIR%\tools\python"
    echo        Created tools/python/ directory
)
IF NOT EXIST "%INSTALL_DIR%\tools\nodejs" (
    mkdir "%INSTALL_DIR%\tools\nodejs"
    echo        Created tools/nodejs/ directory
)
IF NOT EXIST "%INSTALL_DIR%\tools\shell" (
    mkdir "%INSTALL_DIR%\tools\shell"
    echo        Created tools/shell/ directory
)

echo        Dependency management directories ready
echo.

REM --- 3. Download Python Embeddable ---
SET "PYTHON_VERSION=3.13.3"
SET "PYTHON_ZIP=%INSTALL_DIR%\python-%PYTHON_VERSION%-embed-amd64.zip"
SET "PYTHON_URL=https://mirrors.tuna.tsinghua.edu.cn/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-embed-amd64.zip"
SET "PYTHON_DIR=%INSTALL_DIR%\python"

echo [3/14] Downloading Python %PYTHON_VERSION% Embeddable...

IF EXIST "%PYTHON_DIR%\python.exe" GOTO :py_dl_done
echo        URL: %PYTHON_URL%

IF EXIST "%PYTHON_ZIP%" GOTO :py_dl_found
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_ZIP%' -UseBasicParsing"
IF %ERRORLEVEL% NEQ 0 GOTO :py_dl_error
echo        Download complete
GOTO :py_dl_found

:py_dl_error
echo [ERROR] Python download failed. Check your network connection.
pause
exit /b 1

:py_dl_found
echo        Found existing download, skipping
GOTO :py_dl_done

:py_dl_done
echo.

REM --- 4. Extract Python Embeddable ---
echo [4/14] Extracting Python to %PYTHON_DIR%\...

IF EXIST "%PYTHON_DIR%\python.exe" GOTO :py_ex_done
powershell -NoProfile -Command "Expand-Archive -Path '%PYTHON_ZIP%' -DestinationPath '%PYTHON_DIR%' -Force"
IF %ERRORLEVEL% NEQ 0 GOTO :py_ex_error
echo        Extraction complete
GOTO :py_ex_done

:py_ex_error
echo [ERROR] Python extraction failed
pause
exit /b 1

:py_ex_done
echo.

REM --- 5. Enable pip (modify python313._pth) ---
echo [5/14] Configuring Python to enable pip...

SET "PTH_FILE=%PYTHON_DIR%\python313._pth"
IF EXIST "%PTH_FILE%" GOTO :py_pth_write
echo [WARN] %PTH_FILE% not found
GOTO :py_pth_done

:py_pth_write
>"%PTH_FILE%" echo python313.zip
>>"%PTH_FILE%" echo .
>>"%PTH_FILE%" echo Lib\site-packages
>>"%PTH_FILE%" echo.
>>"%PTH_FILE%" echo # Enable site module for pip support
>>"%PTH_FILE%" echo import site
echo        python313._pth updated (import site + Lib\site-packages enabled)

:py_pth_done
echo.

REM --- 6. Install pip ---
SET "GET_PIP=%PYTHON_DIR%\get-pip.py"
SET "GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py"

echo [6/14] Installing pip...

IF EXIST "%PYTHON_DIR%\Scripts\pip.exe" GOTO :pip_done

IF EXIST "%GET_PIP%" GOTO :pip_run
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%GET_PIP_URL%' -OutFile '%GET_PIP%' -UseBasicParsing"
IF %ERRORLEVEL% NEQ 0 GOTO :pip_dl_error
GOTO :pip_run

:pip_dl_error
echo [ERROR] get-pip.py download failed
pause
exit /b 1

:pip_run
"%PYTHON_DIR%\python.exe" "%GET_PIP%"
IF %ERRORLEVEL% NEQ 0 GOTO :pip_error
echo        pip installed
GOTO :pip_done

:pip_error
echo [ERROR] pip installation failed
pause
exit /b 1

:pip_done
echo.

REM --- 7. Install Python dependencies ---
SET "SITE_PKGS=%PYTHON_DIR%\Lib\site-packages"

echo [7/14] Installing Python packages (rich, pyyaml, pyreadline3, openpyxl)...

"%PYTHON_DIR%\python.exe" -m pip install rich pyyaml pyreadline3 openpyxl --target "%SITE_PKGS%" -q
IF %ERRORLEVEL% NEQ 0 GOTO :pkg_error
echo        Packages installed to %SITE_PKGS%
GOTO :pkg_done

:pkg_error
echo [ERROR] Python package installation failed
echo        Try running manually:
echo        %PYTHON_DIR%\python.exe -m pip install rich pyyaml pyreadline3 openpyxl --target "%SITE_PKGS%"
pause
exit /b 1

:pkg_done
echo.

REM --- 8. Download PortableGit ---
echo [8/14] Downloading PortableGit from npmmirror...

IF EXIST "%INSTALL_DIR%\git\usr\bin\bash.exe" GOTO :git_dl_done
echo        Querying latest Git version...

powershell -NoProfile -ExecutionPolicy Bypass -Command $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $api=Invoke-RestMethod -Uri 'https://registry.npmmirror.com/-/binary/git-for-windows/'; $vs=[System.Collections.ArrayList]::new(); foreach($i in $api){if($i.name -match '^v\d+\.\d+\.\d+\.windows\.\d+/$'){$null=$vs.Add($i)}}; $latest=$vs[-1]; $tag=$latest.name.TrimEnd('/'); $base=$tag -replace '^v','' -replace '\.windows\.\d+$',''; Write-Host 'Latest Git:' $tag; $url='https://registry.npmmirror.com/-/binary/git-for-windows/'+$tag+'/PortableGit-'+$base+'-64-bit.7z.exe'; Invoke-WebRequest -Uri $url -OutFile '%INSTALL_DIR%\portablegit.7z.exe' -UseBasicParsing; Write-Host 'Download complete'
IF %ERRORLEVEL% NEQ 0 GOTO :git_dl_error
GOTO :git_dl_done

:git_dl_error
echo [ERROR] PortableGit download failed. Check your network connection.
pause
exit /b 1

:git_dl_done
echo.

REM --- 9. Extract PortableGit ---
echo [9/14] Extracting PortableGit to %INSTALL_DIR%\git\...

IF EXIST "%INSTALL_DIR%\git\usr\bin\bash.exe" GOTO :git_ex_done
IF NOT EXIST "%INSTALL_DIR%\portablegit.7z.exe" GOTO :git_ex_error

echo        Extracting... this may take a moment...
"%INSTALL_DIR%\portablegit.7z.exe" -y -o"%INSTALL_DIR%\git"
IF %ERRORLEVEL% NEQ 0 GOTO :git_ex_error
del /f /q "%INSTALL_DIR%\portablegit.7z.exe" 2>nul
echo        Extraction complete
GOTO :git_ex_done

:git_ex_error
echo [ERROR] PortableGit extraction failed
del /f /q "%INSTALL_DIR%\portablegit.7z.exe" 2>nul
pause
exit /b 1

:git_ex_done
echo.

REM --- 10. Download Node.js ---
echo [10/14] Downloading Node.js from npmmirror...

IF EXIST "%INSTALL_DIR%\node\node.exe" GOTO :node_dl_done
echo        Querying latest Node.js LTS version...

powershell -NoProfile -ExecutionPolicy Bypass -Command $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $api=Invoke-RestMethod -Uri 'https://registry.npmmirror.com/-/binary/node/latest-v22.x/'; $ver=$api.version; Write-Host 'Latest Node.js:' $ver; $url='https://registry.npmmirror.com/-/binary/node/'+$ver+'/node-'+$ver+'-win-x64.zip'; Invoke-WebRequest -Uri $url -OutFile '%INSTALL_DIR%\node-portable.zip' -UseBasicParsing; Write-Host 'Download complete'
IF %ERRORLEVEL% NEQ 0 GOTO :node_dl_error
GOTO :node_dl_done

:node_dl_error
echo [ERROR] Node.js download failed. Check your network connection.
pause
exit /b 1

:node_dl_done
echo.

REM --- 11. Extract Node.js ---
echo [11/14] Extracting Node.js to %INSTALL_DIR%\node\...

IF EXIST "%INSTALL_DIR%\node\node.exe" GOTO :node_ex_done
IF NOT EXIST "%INSTALL_DIR%\node-portable.zip" GOTO :node_ex_error

echo        Extracting...
powershell -NoProfile -ExecutionPolicy Bypass -Command $ProgressPreference='SilentlyContinue'; Expand-Archive -Path '%INSTALL_DIR%\node-portable.zip' -DestinationPath '%INSTALL_DIR%' -Force; $dirs=Get-ChildItem -Path '%INSTALL_DIR%' -Directory -Filter 'node-v*'; if($dirs){if(Test-Path '%INSTALL_DIR%\node'){Remove-Item '%INSTALL_DIR%\node' -Recurse -Force};Move-Item $dirs[0].FullName '%INSTALL_DIR%\node'}; Remove-Item '%INSTALL_DIR%\node-portable.zip' -Force; Write-Host 'Extraction complete'
IF %ERRORLEVEL% NEQ 0 GOTO :node_ex_error
echo        Node.js extracted to node/
GOTO :node_ex_done

:node_ex_error
echo [ERROR] Node.js extraction failed
del /f /q "%INSTALL_DIR%\node-portable.zip" 2>nul
pause
exit /b 1

:node_ex_done
echo.

REM --- 12. Configure PATH environment variable ---
echo [12/14] Configuring PATH environment variable...

SET "BIN_DIR=%INSTALL_DIR%\bin"

REM Add bin/ to user PATH if not already present
powershell -NoProfile -Command "$b='%BIN_DIR%'; $p=[Environment]::GetEnvironmentVariable('Path','User'); if($p -notlike \"*$b*\"){[Environment]::SetEnvironmentVariable('Path',\"$p;$b\",'User'); Write-Host '       Added to user PATH'}else{Write-Host '       Already in user PATH'}"

REM Add .PS1 to PATHEXT so PowerShell can find aiguibin.ps1 directly
powershell -NoProfile -Command "$pe=[Environment]::GetEnvironmentVariable('PATHEXT','User'); if($pe -notlike '*PS1*'){[Environment]::SetEnvironmentVariable('PATHEXT',\"$pe;.PS1\",'User'); Write-Host '       Added .PS1 to PATHEXT'}else{Write-Host '       .PS1 already in PATHEXT'}"

REM Update current session
SET "PATH=%PATH%;%BIN_DIR%"

echo.

REM --- Cleanup ---
echo.
echo Cleaning up installer files...
IF EXIST "%INSTALL_DIR%\portablegit.7z.exe" del /f /q "%INSTALL_DIR%\portablegit.7z.exe" 2>nul
IF EXIST "%INSTALL_DIR%\node-portable.zip" del /f /q "%INSTALL_DIR%\node-portable.zip" 2>nul
IF EXIST "%PYTHON_ZIP%" del /f /q "%PYTHON_ZIP%" 2>nul
IF EXIST "%GET_PIP%" del /f /q "%GET_PIP%" 2>nul
echo        Cleanup done

REM --- Install report ---
echo.
echo ============================================================
echo   Installation complete! AIguibin Agent System v3.5
echo ============================================================
echo.
echo   Install directory:
echo     AIGUIBIN_CLI_HOME  = %AIGUIBIN_CLI_HOME%
echo.
echo   Runtime status:
IF EXIST "%INSTALL_DIR%\git\usr\bin\bash.exe" (
    echo     Git Bash     = %INSTALL_DIR%\git\usr\bin\bash.exe  [OK]
) ELSE (
    echo     Git Bash     = NOT INSTALLED  [FAIL]
)
IF EXIST "%INSTALL_DIR%\python\python.exe" (
    echo     Python       = %INSTALL_DIR%\python\python.exe  [OK]
) ELSE (
    echo     Python       = NOT INSTALLED  [FAIL]
)
IF EXIST "%INSTALL_DIR%\node\node.exe" (
    echo     Node.js      = %INSTALL_DIR%\node\node.exe  [OK]
) ELSE (
    echo     Node.js      = NOT INSTALLED  [FAIL]
)
echo.
echo   Usage (multiple shells supported):
echo.
echo     CMD / Windows Terminal:
echo       aiguibin              Start interactive CLI
echo       aiguibin /hello       Run a command
echo.
echo     PowerShell:
echo       aiguibin              Start interactive CLI (if .PS1 in PATHEXT)
echo       aiguibin.ps1          Run PowerShell entry directly
echo       .\aiguibin.ps1        Alternative invocation
echo.
echo     Git Bash:
echo       aiguibin              Start interactive CLI
echo       aiguibin /hello       Run a command
echo.
echo   Built-in commands:
echo     /help               Show help
echo     /shell              Start embedded Git Bash
echo     /install-pkg pkg    Install package via npm
echo     /env                Show runtime paths
echo     /doctor             Diagnose runtime
echo.
echo   Environment:
echo     AIGUIBIN_CLI_HOME   = %AIGUIBIN_CLI_HOME%
echo     AIGUIBIN_AGENT_DIR  = %AIGUIBIN_AGENT_DIR% (app data: logs, history)
echo     AIGUIBIN_WORKSPACE  = Current directory (auto-detected)
echo.
echo   Directory Structure:
echo     %%AIGUIBIN_CLI_HOME%%
echo       ├─ config/          (configuration files)
echo       ├─ .agent/          (application data)
echo       │   ├─ logs/         (application logs)
echo       │   └─ .aiguibin_history
echo       ├─ scripts/         (user scripts)
echo       └─ (runtime files)
echo     %%AIGUIBIN_WORKSPACE%%
echo       └─ .aiguibin/tasks/ (task outputs only)
echo.
echo   NOTE: Please reopen your terminal for PATH changes to take effect!
echo ============================================================
pause
