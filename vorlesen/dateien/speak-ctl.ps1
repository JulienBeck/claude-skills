# -Inline: speak-last.ps1 im selben Prozess ausfuehren statt einen zweiten
# PowerShell zu starten. Das spart rund eine halbe Sekunde und ist genau dann
# richtig, wenn wir ohnehin schon versteckt und abgekoppelt laufen - also auf
# dem Tastenweg ueber speak-run.vbs. Ruft man das Skript von Hand im Terminal
# auf, bleibt der Start als eigener Prozess, sonst blockiert die Eingabe bis
# zum Ende des Vorlesens.
param(
  [Parameter(Position = 0)][string]$Action = 'toggle',
  [switch]$Inline,
  # Prozess des Fensters, das beim Tastendruck vorne war. AHK kennt es sicher;
  # wird es nicht durchgereicht, wird hier das Vordergrundfenster gefragt.
  [int]$WindowPid = 0
)

. (Join-Path (Split-Path -Parent $PSCommandPath) 'speak-common.ps1')

$ctlFile = Join-Path $env:TEMP 'claude-speak.ctl'

function Get-State {
  if (-not (Test-Path $ctlFile)) { return 'run' }
  try { return (Get-Content $ctlFile -ErrorAction Stop | Select-Object -First 1).Trim() } catch { return 'run' }
}

$speaker = Get-ActiveSpeaker

# Die Medientaste ist fensterbezogen: sie pausiert nur, was zum Fenster im
# Vordergrund gehoert und dort auch noch die letzte Antwort ist. Klickt man ein
# anderes Terminal an - oder ist inzwischen eine neue Antwort fertig geworden -,
# wird stattdessen von vorn vorgelesen, was dort zuletzt steht.
if ($Action.ToLower() -in 'media', 'playpause') {
  if (-not $speaker) {
    $Action = 'read'
  } else {
    if ($WindowPid -le 0) { $WindowPid = Get-ForegroundProcessId }
    $sameWindow = ($WindowPid -gt 0 -and $speaker.WindowPid -gt 0 -and $WindowPid -eq $speaker.WindowPid)
    if (-not $sameWindow) {
      $Action = 'read'
    } else {
      # Nur die vorgehaltene Tabelle befragen. Steht dort nichts, bleibt es
      # beim Umschalten - lieber einmal pausieren als eine Sekunde warten.
      $latest = Find-SessionForWindow $WindowPid -FastOnly
      if ($latest -and $latest.Hash -and $speaker.Hash -and $latest.Hash -ne $speaker.Hash) {
        $Action = 'read'
      } else {
        $Action = 'toggle'
      }
    }
  }
}

switch ($Action.ToLower()) {
  { $_ -in 'read', 'vorlesen', 'start' } {
    if ($speaker) {
      Set-Content -Path $ctlFile -Value 'stop' -Encoding ascii
      Start-Sleep -Milliseconds 250
      if (Get-ActiveSpeaker) { Stop-Process -Id $speaker.Pid -Force -ErrorAction SilentlyContinue }
    }
    $script = Join-Path (Split-Path -Parent $PSCommandPath) 'speak-last.ps1'
    Write-Output 'liest vor'
    if ($Inline) {
      & $script -WindowPid $WindowPid
    } else {
      Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script`"",
        '-WindowPid', $WindowPid
      )
    }
  }
  'prewarm' {
    # Vom Stop-Hook gerufen: erzeugt den Ton zur letzten Kurzfassung im
    # Voraus. Laeuft still und ohne Ausgabe, damit nichts im Terminal landet.
    & (Join-Path (Split-Path -Parent $PSCommandPath) 'speak-prewarm.ps1')
  }
  'pause' {
    Set-Content -Path $ctlFile -Value 'pause' -Encoding ascii
    Write-Output 'pausiert'
  }
  { $_ -in 'resume', 'weiter' } {
    Set-Content -Path $ctlFile -Value 'run' -Encoding ascii
    Write-Output 'weiter'
  }
  'toggle' {
    if ((Get-State) -eq 'pause') {
      Set-Content -Path $ctlFile -Value 'run' -Encoding ascii
      Write-Output 'weiter'
    } else {
      Set-Content -Path $ctlFile -Value 'pause' -Encoding ascii
      Write-Output 'pausiert'
    }
  }
  'stop' {
    Set-Content -Path $ctlFile -Value 'stop' -Encoding ascii
    if ($speaker) {
      Start-Sleep -Milliseconds 250
      if (Get-ActiveSpeaker) { Stop-Process -Id $speaker.Pid -Force -ErrorAction SilentlyContinue }
    }
    Write-Output 'gestoppt'
  }
  'status' {
    if ($speaker) {
      Write-Output ("liest vor (pid " + $speaker.Pid + ", Fenster " + $speaker.WindowPid + "), Zustand: " + (Get-State))
    }
    else { Write-Output 'nichts aktiv' }
  }
  default {
    Write-Output 'Verwendung: read | pause | resume | toggle | stop | status'
  }
}
