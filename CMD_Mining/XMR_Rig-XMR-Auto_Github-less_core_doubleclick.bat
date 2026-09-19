@echo off
setlocal enabledelayedexpansion

:: 全程无窗口:用 mshta 把自己以隐藏方式重跑一遍(带参数 h),原进程立刻退出。
:: .bat 藏不掉自己的窗口——cmd.exe 在第一行执行之前就把窗口建好了,而 win11 上
:: 那个窗口属于 Windows Terminal,是另一个进程,进程内部怎么调都藏不掉。所以只
:: 能不让它被建出来:由 mshta 以 window style 0 启动。
if "%1"=="h" goto begin
start mshta vbscript:createobject("wscript.shell").run("""%~nx0"" h",0)(window.close)&&exit
:begin

:: 解决部分win11/win10英文系统电脑打开为非正常中文字问题
:: 设置控制台代码页为UTF-8，确保中文正确显示
chcp 65001 >nul

:: 以脚本所在目录为工作目录。隐藏启动时由 mshta 拉起,继承的当前目录不一定是
:: 脚本所在目录,不写死的话下面按相对路径读写就会落到别的地方。
cd /d "%~dp0"

:: 设置控制台窗口标题
title XMRig 6.26.0 Self Single-File Auto_Mining

:: 显示脚本标题和信息
echo.
echo ========================================
echo        XMRig Self Single-File Auto_Mining
echo ========================================
echo XMRig版本: 6.26.0   (自编译,开发者手续费 0%%)
echo ========================================
echo.

:: 设置固定版本号变量
set "VERSION=6.26.0"

:: 单文件版:整个矿机就一个 exe,下载完直接跑,不需要解压
set "ASSET=windows-x64-doubleclick.exe"
set "EXE=%CD%\xmrig.exe"
set "LOG=%CD%\XMR_Rig_%VERSION%.log"

:: 下载地址指向仓库里的 Mining/Self_xmr/,那里放的是自编译产物
set "RAW_URL=https://github.com/acu715/acu715/raw/refs/heads/main/Mining/Self_xmr/%ASSET%"

:: 国内直连 github 基本不通(本机实测:直连和挂代理都是连不上/TLS 被切),
:: 所以镜像先试、直连留作回退。哪条路通就用哪条。
set "MIRROR_URL=https://gh-proxy.com/%RAW_URL%"

:: 这个 exe 的 SHA256。镜像对大文件偶尔会截断,而截断后 curl 仍然返回成功,
:: 只看"文件在不在"会拿到一个跑不起来的残次品,所以按内容校验。
:: 换新版本时这里必须跟着换,否则脚本会一直拒绝下载。
set "SHA256=3060770f13041a462852e6b360b9bf6cde81cad00fd958be2bc8901055471015"

echo [信息] 使用固定XMRig版本: %VERSION%
echo [信息] 目标文件: %EXE%
echo.

:: 已下载过且内容对得上就直接用,省一次网络往返
if exist "%EXE%" (
    echo [信息] 发现已存在的文件,校验SHA256...
    call :CHECK_HASH "%EXE%"
    if !HASH_OK! == 1 (
        echo [信息] 校验通过,跳过下载。
        goto :RUN_XMR
    )
    echo [警告] 校验不通过,删除后重新下载。
    del /q "%EXE%" 2>nul
)

:: 尝试检测系统中是否已安装curl
echo [信息] 检查系统中是否已安装curl工具...
where curl >nul 2>nul
if !errorlevel! neq 0 (
    echo [错误] 系统中未找到curl工具,无法下载。
    echo        Win10 1803 之前的系统不自带curl,请先升级或手动安装。
    goto :FAIL
)
echo [信息] 系统已安装curl工具。
echo.

:: 先把镜像和直连都试一遍,谁先成功用谁
set "GOT=0"
call :TRY_DOWNLOAD "%MIRROR_URL%" "镜像"
if !GOT! == 0 call :TRY_DOWNLOAD "%RAW_URL%" "直连"

if !GOT! == 0 (
    echo [错误] 镜像和直连都没能下载成功。
    goto :FAIL
)

echo [成功] 下载完成,校验SHA256...
call :CHECK_HASH "%EXE%"
if !HASH_OK! neq 1 (
    echo [错误] 下载到的文件SHA256对不上,说明内容不完整或被改动过。
    echo        期望: %SHA256%
    echo        实际: !HASH_ACTUAL!
    del /q "%EXE%" 2>nul
    goto :FAIL
)
echo [成功] 校验通过。
echo.

:RUN_XMR
echo ========================================
echo            XMRig 启动信息
echo ========================================
echo 矿池: 内置(默认 58.176.17.24:3334,加 --no-tls 走 3333)
echo 线程: 75%%(由程序按CPU核心数自动计算)
echo 日志: %LOG%
echo ========================================
echo.
echo [信息] 正在启动XMRig...
echo.

:: --75 是 --cpu-max-threads-hint=75 的简写,即用满 75%% 的线程。
:: 单文件版内置矿池地址,不需要 --url / --user 之类的参数。
"%EXE%" --75 >>"%LOG%" 2>&1

:: 单文件版是 GUI 子系统程序,cmd 不会等它,这里通常立刻就返回了。
echo [成功] 已启动,窗口即将关闭。
endlocal
exit /b 0

:: ---------------------------------------------------------------------------
:: 子过程
:: ---------------------------------------------------------------------------

:: 下载到临时文件,校验通过才落到正式路径,避免半个文件冒充成品
:TRY_DOWNLOAD
echo [信息] 正在从%~2下载: %~1
curl -fL --retry 2 --connect-timeout 15 -o "%EXE%.tmp" "%~1" >>"%LOG%" 2>&1
if !errorlevel! neq 0 (
    echo [警告] %~2 下载失败,换下一条路。
    del /q "%EXE%.tmp" 2>nul
    exit /b 1
)
call :CHECK_HASH "%EXE%.tmp"
if !HASH_OK! neq 1 (
    echo [警告] %~2 的文件校验不通过,换下一条路。
    del /q "%EXE%.tmp" 2>nul
    exit /b 1
)
move /y "%EXE%.tmp" "%EXE%" >nul
set "GOT=1"
exit /b 0

:: 按内容而不是按大小判断,残包和错页都挡得住
:CHECK_HASH
set "HASH_OK=0"
set "HASH_ACTUAL="
if not exist "%~1" exit /b 1
for /f "skip=1 delims=" %%H in ('certutil -hashfile "%~1" SHA256 ^| findstr /r /i "^[0-9a-f]"') do (
    if not defined HASH_ACTUAL set "HASH_ACTUAL=%%H"
)
if not defined HASH_ACTUAL exit /b 1
set "HASH_ACTUAL=!HASH_ACTUAL: =!"
if /i "!HASH_ACTUAL!" == "%SHA256%" set "HASH_OK=1"
exit /b 0

:: 隐藏运行时 pause 是看不见的,会变成一个永远挂着的进程,所以失败一律弹窗
:FAIL
echo [错误] 脚本执行失败,详见 %LOG%
mshta vbscript:msgbox("XMRig 下载或校验失败，请查看 " & "%LOG%",16,"XMRig")(window.close)
endlocal
exit /b 1
