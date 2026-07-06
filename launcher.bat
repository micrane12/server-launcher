@echo off
setlocal enabledelayedexpansion
title Server Launcher
cd /d "%~dp0"
set "ROOT=%~dp0"
set "ECO=%ROOT%ecosystem.config.js"

REM ================= server list =================
REM  To add a server: bump COUNT and add name#/port# lines.
REM  name# = pm2 app name, port# = browser port, dir# = project folder
REM  (dir# is scanned by /scripts for .bat/.cmd helper files)
set "COUNT=3"
set "name1=remote-desktop"  & set "port1=5000" & set "dir1=C:\Dev\REMOTE DESKTOP"
set "name2=hbs-systems"     & set "port2=3000" & set "dir2=C:\Dev\HOME BUILD SYSTEM\HOME BUILD SOLUTIONS"
set "name3=claude-bridge"   & set "port3=5765" & set "dir3=C:\Dev\CLAUDE BRIDGE\server"
REM ================================================

REM ---- enable ANSI colors (VT) and grab the ESC char ----
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

where pm2 >nul 2>&1
if errorlevel 1 (
    echo pm2 is not installed. Install with:  npm install -g pm2
    pause
    exit /b
)

cls
call :banner
call :list

:loop
echo.
set "cmd="
set "arg="
set /p "input=!ESC![92mserver !ESC![92m^>!ESC![0m "
for /f "tokens=1,2" %%a in ("!input!") do ( set "cmd=%%a" & set "arg=%%b" )
if "!cmd!"=="" goto loop

if /i "!cmd!"=="/help"    ( call :help & goto loop )
if "!cmd!"=="/"           ( call :help & goto loop )
if "!cmd!"=="/?"          ( call :help & goto loop )
if /i "!cmd!"=="/list"    ( call :list & goto loop )
if /i "!cmd!"=="/status"  ( call :watch & goto loop )
if /i "!cmd!"=="/watch"   ( call :watch & goto loop )
if /i "!cmd!"=="/monit"   ( call pm2 monit & goto loop )
if /i "!cmd!"=="/open"    ( call :resolve open    "!arg!" & goto loop )
if /i "!cmd!"=="/start"   ( call :resolve start   "!arg!" & goto loop )
if /i "!cmd!"=="/stop"    ( call :resolve stop    "!arg!" & goto loop )
if /i "!cmd!"=="/restart" ( call :resolve restart "!arg!" & goto loop )
if /i "!cmd!"=="/logs"    ( call :resolve logs    "!arg!" & goto loop )
if /i "!cmd!"=="/scripts" ( call :scripts & goto loop )
if /i "!cmd!"=="/run"     ( call :runscript "!arg!" & goto loop )
if /i "!cmd!"=="/quit"    ( exit /b )
if /i "!cmd!"=="/exit"    ( exit /b )

echo Unknown command: !cmd!   (type /help)
goto loop

REM ---------------- banner ----------------
:banner
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%ui.ps1" -Mode banner
exit /b

REM ---------------- help ----------------
:help
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%ui.ps1" -Mode help
exit /b

REM ---------------- show the list ----------------
:list
set "names="
set "ports="
for /l %%i in (1,1,%COUNT%) do ( set "names=!names!!name%%i!," & set "ports=!ports!!port%%i!," )
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%status.ps1" -Names "!names!" -Ports "!ports!"
echo !ESC![90m  (use 'all' with /start /stop /restart)!ESC![0m
exit /b

REM ------ scan each project folder for .bat/.cmd helpers ------
:scanscripts
set "RC=0"
for /l %%i in (1,1,%COUNT%) do (
    set "folder=!dir%%i!"
    if exist "!folder!" (
        for %%F in ("!folder!\*.bat" "!folder!\*.cmd") do (
            if /i not "%%~nxF"=="launcher.bat" (
                set /a RC+=1
                for %%n in (!RC!) do (
                    set "rname%%n=%%~nxF"
                    set "rpath%%n=%%~fF"
                    set "rproj%%n=!name%%i!"
                )
            )
        )
    )
)
exit /b

REM ------ list scripts found per project ------
:scripts
call :scanscripts
echo.
echo ==================================
echo   SCRIPTS  (found in project folders)
echo ==================================
if "!RC!"=="0" ( echo   (no .bat/.cmd files found in the project folders) & exit /b )
set "lastproj="
for /l %%i in (1,1,!RC!) do (
    if not "!rproj%%i!"=="!lastproj!" (
        echo.
        echo   [!rproj%%i!]
        set "lastproj=!rproj%%i!"
    )
    echo     %%i^) !rname%%i!
)
exit /b

REM ------ run a scanned script by number ------
:runscript
call :scanscripts
set "n=%~1"
if "%n%"=="" ( call :scripts & set /p "n=Pick a number: " )
set "sn=!rname%n!"
set "sp=!rpath%n!"
if "!sn!"=="" ( echo Invalid selection. & exit /b )
if not exist "!sp!" ( echo Script not found: !sp! & exit /b )
echo Running !sn!  ^(!sp!^) ...
call "!sp!"
echo --- done: !sn! ---
exit /b

REM ------ live auto-refreshing status ------
:watch
set "names="
set "ports="
for /l %%i in (1,1,%COUNT%) do ( set "names=!names!!name%%i!," & set "ports=!ports!!port%%i!," )
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%status.ps1" -Names "!names!" -Ports "!ports!" -Watch -Interval 2
exit /b

REM ------ resolve action + target, then run ------
REM  %1 = action   %2 = arg (number, "all", or empty)
:resolve
set "action=%~1"
set "target=%~2"

REM handle ALL for pm2 lifecycle actions
if /i "!target!"=="all" (
    if /i "!action!"=="start"   ( call pm2 start "%ECO%" & exit /b )
    if /i "!action!"=="stop"    ( call pm2 stop all      & exit /b )
    if /i "!action!"=="restart" ( call pm2 restart all   & exit /b )
    echo "all" is only valid for /start /stop /restart.
    exit /b
)

REM if no number given, show list and ask
if "!target!"=="" (
    call :list
    set /p "target=Pick a number: "
)

REM validate number
set "sel=!name%target%!"
if "!sel!"=="" ( echo Invalid selection. & exit /b )
set "selport=!port%target%!"

if /i "!action!"=="open" (
    echo Opening http://localhost:!selport! ...
    start "" "http://localhost:!selport!"
    exit /b
)
if /i "!action!"=="logs" (
    call pm2 logs "!sel!"
    exit /b
)
if /i "!action!"=="start" (
    REM start a single app defined in the ecosystem file (correct cwd)
    call pm2 start "%ECO%" --only "!sel!"
    exit /b
)
REM stop / restart one (app already registered by name)
call pm2 !action! "!sel!"
exit /b
