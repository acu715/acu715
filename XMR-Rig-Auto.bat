@echo off
setlocal enabledelayedexpansion

echo XMRig 6.24.0 bat-script
echo ================================
echo.

:: ���ù̶��汾��
set VERSION=6.24.0
echo [��Ϣ] ʹ�ù̶��汾: %VERSION%
echo.

:: ���Լ��ϵͳ���Ƿ��Ѱ�װcurl
where curl >nul 2>nul
if !errorlevel! == 0 (
    echo [��Ϣ] ϵͳ�Ѱ�װcurl���ߡ�
    goto :DOWNLOAD_XMR
)

echo [��Ϣ] ϵͳ��δ�ҵ�curl���ߣ������Զ���װ...
echo.

:: ������ʱĿ¼�����curl
set "TEMP_CURL_DIR=%TEMP%\curl_install"
if not exist "%TEMP_CURL_DIR%" (
    mkdir "%TEMP_CURL_DIR%"
)

:: ʹ�ù̶��汾��curl��������
set "CURL_DOWNLOAD_URL=https://curl.se/windows/dl-8.8.0_5/curl-8.8.0_5-win64-mingw.zip"
set "CURL_ZIP=%TEMP_CURL_DIR%\curl.zip"

echo [��Ϣ] ��������curl...
:: ʹ��bitsadmin����curl����Ϊ��ʱ���ܻ�û��curl
bitsadmin /transfer downloadCurl /download /priority normal "%CURL_DOWNLOAD_URL%" "%CURL_ZIP%"

if not exist "%CURL_ZIP%" (
    echo [����] ����curlʧ�ܣ������������ӻ��ֶ���װcurl��
    echo         curl������https://curl.se/windows/
    pause
    exit /b 1
)

:: ��ѹcurl.zip
echo [��Ϣ] ���ڽ�ѹcurl...
powershell -command "Expand-Archive -Path '%CURL_ZIP%' -DestinationPath '%TEMP_CURL_DIR%' -Force"

:: ����ѹ���curl�������ļ�·����ӵ���ǰ�Ự��PATH����������
for /d %%i in ("%TEMP_CURL_DIR%\curl-*") do (
    set "CURL_EXTRACTED_DIR=%%i"
)
set "PATH=%CURL_EXTRACTED_DIR%\bin;%PATH%"

:: �ٴμ��curl�Ƿ����
where curl >nul 2>nul
if !errorlevel! neq 0 (
    echo [����] �Զ���װcurl�����޷��ҵ�curl���
    echo        ���ֶ����ز���װcurl������ű���
    pause
    exit /b 1
)

echo [��Ϣ] curl��������ʱ��װ��������ɡ�
echo.

:DOWNLOAD_XMR
:: ��������URL���ļ���
set "FILENAME=xmrig-%VERSION%-windows-x64.zip"
set "DOWNLOAD_URL=https://github.com/xmrig/xmrig/releases/download/v%VERSION%/%FILENAME%"

:: ����ļ��Ƿ��Ѵ���
if exist "%FILENAME%" (
    echo [��Ϣ] �����Ѵ��ڵ�XMRigѹ�������������ء�
    goto :EXTRACT_XMR
)

:: ����XMRig
echo [��Ϣ] ��������XMRig: %FILENAME%
curl -L -o "%FILENAME%" "%DOWNLOAD_URL%"

if not exist "%FILENAME%" (
    echo [����] XMRig����ʧ�ܡ�
    pause
    exit /b 1
)

echo [��Ϣ] ������ɡ�
echo.

:EXTRACT_XMR
:: ��ѹ�ļ�
echo [��Ϣ] ���ڽ�ѹ�ļ�...
set "DIRNAME=xmrig-%VERSION%"

:: ���Ŀ¼�Ѵ��ڣ���ɾ��
if exist "%DIRNAME%" (
    echo [��Ϣ] �����Ѵ��ڵ�Ŀ¼����ɾ��...
    rmdir /s /q "%DIRNAME%"
)

powershell -command "Expand-Archive -Path '%FILENAME%' -DestinationPath . -Force"

if !errorlevel! neq 0 (
    echo [����] ��ѹ�ļ�ʧ�ܡ�
    pause
    exit /b 1
)

:: ��ȡ��ǰ���������Ϊ�󹤱�ʶ
set "RIG_NAME=SCH-PC-%COMPUTERNAME%"

:: ����Ŀ¼������xmrig
if exist "%DIRNAME%" (
    cd "%DIRNAME%"
    echo [��Ϣ] ��������XMRig...
    echo        ���: xmr.kryptex.network:7029
    echo        �û�: qiuzhaojinting@gmail.com/%RIG_NAME%
    echo.
    xmrig.exe --coin XMR --url "xmr.kryptex.network:7029" --user "qiuzhaojinting@gmail.com/%RIG_NAME%"
) else (
    echo [����] ��ѹ���Ŀ¼������: %DIRNAME%
    pause
    exit /b 1
)

endlocal