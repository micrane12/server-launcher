@echo off
setlocal enabledelayedexpansion
title Server Launcher
cd /d "%~dp0"
set "ROOT=%~dp0"
set "CFG=%ROOT%servers.txt"

REM first run on a new machine: create servers.txt from the template
if not exist "%CFG%" (
    if exist "%ROOT%servers.example.txt" copy "%ROOT%servers.example.txt" "%CFG%" >nul
)

call :loadservers
if %COUNT%==0 (
    echo No servers found yet. Edit servers.txt or use /add to create one.
)

REM ---- enable ANSI colors (VT) and grab the ESC char ----
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

cls
call :banner
call :list
set "FRONT=1"

:loop
echo.
set "cmd="
set "arg="
set "inf=%TEMP%\sl_in.txt"
del "%inf%" 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%prompt.ps1" -Out "%inf%" -Front !FRONT!
set "input="
if exist "%inf%" set /p "input=" < "%inf%"

REM terminal was resized on the front page: redraw it at the new width
if "!input!"=="__redraw__" (
    cls
    call :banner
    call :list
    goto loop
)

set "arg2="
for /f "tokens=1,2,3" %%a in ("!input!") do ( set "cmd=%%a" & set "arg=%%b" & set "arg2=%%c" )
if "!cmd!"=="" goto loop

REM fresh screen: entered command goes to the first row
cls
echo !ESC![92mserver ^>!ESC![0m !input!
set "FRONT=0"

if /i "!cmd!"=="/home"    ( cls & call :banner & call :list & set "FRONT=1" & goto loop )
if /i "!cmd!"=="/help"    ( call :help & goto loop )
if "!cmd!"=="/"           ( call :help & goto loop )
if "!cmd!"=="/?"          ( call :help & goto loop )
if /i "!cmd!"=="/list"    ( call :list & goto loop )
if /i "!cmd!"=="/status"  ( call :watch & goto loop )
if /i "!cmd!"=="/watch"   ( call :watch & goto loop )
if /i "!cmd!"=="/open"    ( call :resolve open    "!arg!" & goto loop )
if /i "!cmd!"=="/start"   ( call :resolve start   "!arg!" & goto loop )
if /i "!cmd!"=="/stop"    ( call :resolve stop    "!arg!" & goto loop )
if /i "!cmd!"=="/restart" ( call :resolve restart "!arg!" & goto loop )
if /i "!cmd!"=="/logs"    ( call :resolve logs    "!arg!" & goto loop )
if /i "!cmd!"=="/browser"    ( call :resolve browser   "!arg!" & goto loop )
if /i "!cmd!"=="/url"        ( call :resolve browser   "!arg!" & goto loop )
if /i "!cmd!"=="/env"        ( call :resolve env       "!arg!" & goto loop )
if /i "!cmd!"=="/edit"       ( call :resolve edit      "!arg!" & goto loop )
if /i "!cmd!"=="/clear-logs" ( call :resolve clearlogs "!arg!" & goto loop )
if /i "!cmd!"=="/info"       ( call :resolve info      "!arg!" & goto loop )
if /i "!cmd!"=="/launch"  ( call :runscript "!arg!" & goto loop )
if /i "!cmd!"=="/scripts" ( call :runscript "!arg!" & goto loop )
if /i "!cmd!"=="/run"     ( call :runscript "!arg!" & goto loop )
if /i "!cmd!"=="/add"     ( call :addserver & goto loop )
if /i "!cmd!"=="/scan"    ( call :scanfolder "!arg!" & goto loop )
if /i "!cmd!"=="/remove"  ( call :removeserver "!arg!" & goto loop )
if /i "!cmd!"=="/move"    ( call :moveserver "!arg!" "!arg2!" & goto loop )
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

REM ---------------- (re)load servers.txt into arrays ----------------
:loadservers
set "COUNT=0"
for /f "usebackq tokens=1-4 delims=|" %%a in (`findstr /v "^#" "%CFG%" 2^>nul`) do (
    if not "%%a"=="" (
        set /a COUNT+=1
        set "name!COUNT!=%%a"
        set "dir!COUNT!=%%b"
        set "cmd!COUNT!=%%c"
        set "port!COUNT!=%%d"
    )
)
exit /b

REM ---------------- add a server (guided) ----------------
:addserver
echo.
echo !ESC![92m  Add a server!ESC![0m  !ESC![90m(press Enter on a blank line to cancel)!ESC![0m
echo.
echo !ESC![90m  name: a short label shown in the dashboard, e.g. my-api!ESC![0m
set "nm="  & set /p "nm=  name          : "
if "!nm!"=="" ( echo   cancelled. & exit /b )
echo !ESC![90m  folder: full path to the project folder, e.g. C:\Dev\MY API!ESC![0m
set "dr="  & set /p "dr=  folder path   : "
if "!dr!"=="" ( echo   folder required - cancelled. & exit /b )
echo !ESC![90m  start command: what you type to run it from that folder,!ESC![0m
echo !ESC![90m                 e.g. python app.py  /  npm run dev  /  node index.js!ESC![0m
set "cm="  & set /p "cm=  start command : "
if "!cm!"=="" ( echo   command required - cancelled. & exit /b )
echo !ESC![90m  port: the localhost port it listens on, e.g. 8000!ESC![0m
set "pt="  & set /p "pt=  port          : "
set "lineout=!nm!|!dr!|!cm!|!pt!"
>>"%CFG%" echo(!lineout!
echo.
echo !ESC![92m  added "!nm!".!ESC![0m
call :loadservers
call :list
exit /b

REM ---------------- scan a folder for projects to add ----------------
:scanfolder
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scan.ps1" -Root "%~1" -Cfg "%CFG%"
call :loadservers
call :list
exit /b

REM ---------------- arrow-key pickers ----------------
REM pick.ps1 returns the chosen row via exit code (10 + index); 0 = cancelled
:pickserver
set "PICK="
set "itemsf=%TEMP%\sl_items.txt"
> "%itemsf%" (
    for /l %%i in (1,1,%COUNT%) do echo(%%i^|!name%%i!  :!port%%i!
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%pick.ps1" -File "%itemsf%" -Title "Select a server"
if !ERRORLEVEL! GEQ 10 set /a PICK=!ERRORLEVEL!-9
exit /b

:pickscript
set "PICK="
set "itemsf=%TEMP%\sl_items.txt"
set "lastproj="
> "%itemsf%" (
    for /l %%i in (1,1,!RC!) do (
        if not "!rproj%%i!"=="!lastproj!" (
            if defined lastproj echo(-
            set "lastproj=!rproj%%i!"
        )
        echo(%%i^|[!rproj%%i!] !rname%%i!
    )
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%pick.ps1" -File "%itemsf%" -Title "Launch which helper"
if !ERRORLEVEL! GEQ 10 set /a PICK=!ERRORLEVEL!-9
exit /b

REM ---------------- resolve a name-or-number arg to IDX ----------------
:findidx
set "IDX="
if "%~1"=="" exit /b
if defined name%~1 set "IDX=%~1"
if not defined IDX for /l %%i in (1,1,%COUNT%) do if /i "!name%%i!"=="%~1" set "IDX=%%i"
exit /b

REM ---------------- reorder servers ----------------
:moveserver
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%move.ps1" -Cfg "%CFG%" -From "%~1" -To "%~2"
call :loadservers
call :list
exit /b

REM ---------------- remove a server (immediate) ----------------
:removeserver
set "a=%~1"
if "%a%"=="" ( call :pickserver & set "a=!PICK!" )
if "%a%"=="" exit /b
call :findidx "%a%"
if not defined IDX ( echo   no server "%a%". & exit /b )
set "rmname=!name%IDX%!"
> "%CFG%.tmp" (
    for /f "usebackq delims=" %%L in ("%CFG%") do (
        set "ln=%%L"
        set "keep=1"
        for /f "tokens=1 delims=|" %%a in ("!ln!") do ( if /i "%%a"=="!rmname!" set "keep=0" )
        if "!keep!"=="1" echo(!ln!
    )
)
move /y "%CFG%.tmp" "%CFG%" >nul
echo !ESC![92m  removed "!rmname!".!ESC![0m
call :loadservers
exit /b

REM ---------------- show the list ----------------
:list
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%status.ps1"
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

REM ------ list helpers found per project ------
:scripts
call :scanscripts
echo.
echo !ESC![92m  LAUNCH!ESC![0m  !ESC![90m- helper scripts found in your project folders!ESC![0m
echo !ESC![90m  run one with:  /launch ^<number^>!ESC![0m
if "!RC!"=="0" (
    echo.
    echo !ESC![90m  no .bat/.cmd helper files found in your project folders!ESC![0m
    exit /b
)
set "lastproj="
for /l %%i in (1,1,!RC!) do (
    if not "!rproj%%i!"=="!lastproj!" (
        echo.
        echo !ESC![90m  !rproj%%i!!ESC![0m
        set "lastproj=!rproj%%i!"
    )
    echo     !ESC![92m%%i^)!ESC![0m !rname%%i!
)
echo.
exit /b

REM ------ run a scanned script by number ------
:runscript
call :scanscripts
if "!RC!"=="0" ( echo   no .bat/.cmd helper files found in your project folders. & exit /b )
set "n=%~1"
if "%n%"=="" (
    call :pickscript
    if "!PICK!"=="" exit /b
    for %%n in (!PICK!) do set "sp=!rpath%%n!"
) else (
    set "sp=!rpath%n%!"
    set "sn=!rname%n%!"
)
if "!sp!"=="" ( exit /b )
for %%F in ("!sp!") do set "sn=%%~nxF"
if "!sn!"=="" ( echo   invalid selection. & exit /b )
if not exist "!sp!" ( echo   not found: !sp! & exit /b )
echo !ESC![92m  running !sn! ...!ESC![0m
call "!sp!"
echo !ESC![90m  done: !sn!!ESC![0m
exit /b

REM ------ live auto-refreshing status ------
:watch
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%status.ps1" -Watch -Interval 2
exit /b

REM ------ resolve action + target, then run ------
REM  %1 = action   %2 = arg (number, "all", or empty)
:resolve
set "action=%~1"
set "target=%~2"

REM handle ALL
if /i "!target!"=="all" (
    if /i "!action!"=="open"    ( echo "all" is not valid for /open. & exit /b )
    if /i "!action!"=="browser" ( echo "all" is not valid for /browser. & exit /b )
    if /i "!action!"=="env"     ( echo "all" is not valid for /env. & exit /b )
    if /i "!action!"=="edit"    ( echo "all" is not valid for /edit. & exit /b )
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%manager.ps1" -Action !action! -Name all
    exit /b
)

REM if nothing given, pick with arrow keys
if "!target!"=="" ( call :pickserver & set "target=!PICK!" )
if "!target!"=="" exit /b

REM resolve name-or-number to an index
call :findidx "!target!"
if not defined IDX ( echo   no server "!target!". & exit /b )
set "sel=!name%IDX%!"
set "selport=!port%IDX%!"
set "seldir=!dir%IDX%!"

if /i "!action!"=="open" (
    if not exist "!seldir!" ( echo   folder not found: !seldir! & exit /b )
    echo Opening cmd at !seldir! ...  (type 'exit' to return to the launcher)
    pushd "!seldir!"
    cmd /k
    popd
    exit /b
)

if /i "!action!"=="browser" (
    if "!selport!"=="" ( echo   !sel! has no port set - nothing to open. & exit /b )
    echo Opening http://localhost:!selport! ...
    start "" "http://localhost:!selport!"
    exit /b
)

if /i "!action!"=="env" (
    if not exist "!seldir!\.env" ( echo   no .env file in !seldir! & exit /b )
    echo Opening !seldir!\.env ...
    start "" "!seldir!\.env"
    exit /b
)

if /i "!action!"=="edit" (
    if not exist "!seldir!" ( echo   folder not found: !seldir! & exit /b )
    where code >nul 2>nul || ( echo   VS Code ^('code'^) is not on your PATH. & exit /b )
    echo Opening !seldir! in VS Code ...
    code "!seldir!"
    exit /b
)

REM start / stop / restart / logs / info / clearlogs one, via the manager
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%manager.ps1" -Action !action! -Name "!sel!"
exit /b
