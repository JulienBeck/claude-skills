Option Explicit
Dim action, winpid, shell, script, args
If WScript.Arguments.Count > 0 Then
  action = WScript.Arguments(0)
Else
  action = "toggle"
End If
' Zweites Argument: der Prozess des Fensters, das beim Tastendruck vorne war.
' AHK kennt ihn im Moment des Drueckens sicher; bis diese Kette durchgelaufen
' ist, koennte der Fokus schon woanders sein. Fehlt er, fragt speak-last.ps1
' selbst nach dem Vordergrundfenster.
If WScript.Arguments.Count > 1 Then
  winpid = WScript.Arguments(1)
Else
  winpid = "0"
End If
script = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & "speak-ctl.ps1"
Set shell = CreateObject("WScript.Shell")
' -Inline: wir laufen hier schon versteckt und abgekoppelt, also darf
' speak-ctl.ps1 das Vorlesen im eigenen Prozess erledigen statt noch einen
' PowerShell zu starten.
args = " " & action & " -Inline -WindowPid " & winpid
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & script & """" & args, 0, False
