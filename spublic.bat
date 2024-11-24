@echo off
echo connecting to spublic...
timeout /t 3 /nobreak
net use t: /delete
net use s: /delete
net use t: \\ecfile2\spublic cl24683680 /user:elegantia\classroom /p:no