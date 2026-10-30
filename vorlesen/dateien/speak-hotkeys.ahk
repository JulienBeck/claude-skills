#Requires AutoHotkey v2.0
#SingleInstance Force

; Medientasten greifen nur, solange das Terminal im Vordergrund ist - damit
; Spotify, Teams und jeder andere Player sie behalten, sobald du woanders bist.
;
; Play/Pause ist eine Taste fuer alles: laeuft nichts, wird vorgelesen;
; laeuft etwas, wird pausiert; nochmal druecken setzt fort.

; A_ScriptDir statt fester Pfad: das Skript liegt neben speak-run.vbs, egal
; unter welchem Benutzernamen.
vbs := A_ScriptDir . "\speak-run.vbs"

; Der Prozess des aktiven Fensters wird mitgegeben, nicht erst hinten in der
; Kette ermittelt: hier steht fest, welches Fenster beim Tastendruck vorne war.
; Danach laufen VBS und PowerShell an, und bis die so weit sind, kann der Fokus
; schon gewandert sein. Aus dem Prozess findet speak-common.ps1 ueber den
; Prozessbaum die Sitzung und damit deren Transkript.
Speak(action) {
    global vbs
    Run('wscript.exe "' vbs '" ' action ' ' WinGetPID("A"))
}

#HotIf WinActive("ahk_exe WindowsTerminal.exe") || WinActive("ahk_exe idea64.exe") || WinActive("ahk_exe Code.exe")

Media_Play_Pause:: Speak("media")
Media_Stop::       Speak("stop")
Media_Next::       Speak("read")

#HotIf

; Die Verknuepfungen im Startmenue (Strg+Alt+V / P / S) bleiben daneben
; bestehen und wirken systemweit, auch ohne fokussiertes Terminal. Sie reichen
; keinen Fensterprozess durch - dort wird das Vordergrundfenster gefragt.
