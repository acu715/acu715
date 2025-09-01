@echo off
setlocal enabledelayedexpansion

echo XMRig 6.24.0 bat-script
echo ================================
echo.

:: 设置固定版本号
set VERSION=6.24.0
echo [信息] 使用固定版本: %VERSION%
echo.

:: 尝试检测系统中是否已安装curl
where curl >nul 2>nul
if !errorlevel! == 0 (
    echo [信息] 系统已安装curl工具。
    goto :DOWNLOAD_XMR
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
    echo         curl官网：https://curl.se/windows/
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
    echo        请手动下载并安装curl，或检查脚本。
    pause
    exit /b 1
)

echo [信息] curl工具已临时安装并配置完成。
echo.

:DOWNLOAD_XMR
:: 设置下载URL和文件名
set "FILENAME=xmrig-%VERSION%-windows-x64.zip"
set "DOWNLOAD_URL=https://github.com/xmrig/xmrig/releases/download/v%VERSION%/%FILENAME%"

:: 检查文件是否已存在
if exist "%FILENAME%" (
    echo [信息] 发现已存在的XMRig压缩包，跳过下载。
    goto :EXTRACT_XMR
)

:: 下载XMRig
echo [信息] 正在下载XMRig: %FILENAME%
curl -L -o "%FILENAME%" "%DOWNLOAD_URL%"

if not exist "%FILENAME%" (
    echo [错误] XMRig下载失败。
    pause
    exit /b 1
)

echo [信息] 下载完成。
echo.

:EXTRACT_XMR
:: 解压文件
echo [信息] 正在解压文件...
set "DIRNAME=xmrig-%VERSION%"

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

:: 进入目录并运行xmrig
if exist "%DIRNAME%" (
    cd "%DIRNAME%"
    echo [信息] 正在启动XMRig...
    echo        矿池: xmr.kryptex.network:7029
    echo        用户: qiuzhaojinting@gmail.com/%RIG_NAME%
    echo.
    xmrig.exe --coin XMR --url "xmr.kryptex.network:7029" --user "qiuzhaojinting@gmail.com/%RIG_NAME%"
) else (
    echo [错误] 解压后的目录不存在: %DIRNAME%
    pause
    exit /b 1
)

endlocal