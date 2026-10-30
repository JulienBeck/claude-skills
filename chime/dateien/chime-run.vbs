Option Explicit
Dim name, shell, script, fso, stamp
If WScript.Arguments.Count > 0 Then
  name = WScript.Arguments(0)
Else
  name = "done"
End If

' "mark" on every PreToolUse: touch a file and leave. A permission prompt is
' always preceded by one; the idle notification after a minute of silence is
' not. That timestamp is how chime.ps1 tells the two apart. No PowerShell here
' - this runs before every single tool call and has to stay cheap.
If name = "mark" Then
  Set fso = CreateObject("Scripting.FileSystemObject")
  stamp = fso.GetSpecialFolder(2) & "\claude-chime-tool.txt"
  fso.CreateTextFile(stamp, True).Close
  WScript.Quit 0
End If
script = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & "chime.ps1"
Set shell = CreateObject("WScript.Shell")
' Window style 0 and bWaitOnReturn false: the hook must return at once, the
' sound outlives it. A PowerShell started directly would flash a console.
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & script & """ -Name " & name, 0, False
