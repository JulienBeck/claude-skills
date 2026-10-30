param([string]$Transcript, [int]$WindowPid = 0)

$ErrorActionPreference = 'Stop'

# Quelle, Cache-Schluessel und der Weg zu edge-tts liegen in speak-common.ps1,
# damit der Stop-Hook exakt dieselbe Datei erzeugt, die hier gesucht wird.
. (Join-Path (Split-Path -Parent $PSCommandPath) 'speak-common.ps1')

# Kein lokaler Rueckfall. Die Windows-Stimmen klingen blechern genug, dass sie
# als Ersatz niemand hoeren will - und weil sie still einsprangen, war von
# aussen nicht zu erkennen, dass der Cloud-Weg gerade ausgefallen war. Ist
# edge-tts nicht erreichbar, bleibt es deshalb bewusst stumm: das ist das
# ehrlichere Signal. Die Offline-Fassung liegt unter
# ~/.claude/backups/vorlesen-offline-stefan, falls ohne Netz vorgefuehrt wird.
$ctlFile = Join-Path $env:TEMP 'claude-speak.ctl'

Add-Type -Name Winmm -Namespace Mci -MemberDefinition @'
[DllImport("winmm.dll", CharSet=CharSet.Auto)]
public static extern int mciSendString(string command, System.Text.StringBuilder ret, int len, System.IntPtr cb);
'@

$alias = "claudespeak$PID"

function Mci([string]$command) {
  $sb = New-Object System.Text.StringBuilder 256
  $null = [Mci.Winmm]::mciSendString($command, $sb, 256, [IntPtr]::Zero)
  return $sb.ToString()
}

function Stop-Previous {
  $old = Get-ActiveSpeaker
  if (-not $old -or $old.Pid -eq $PID) { return }
  Stop-Process -Id $old.Pid -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 120
}

$media = $null

try {
  # Reihenfolge der Quellen, von der genauesten zur groebsten:
  #   1. ausdruecklich uebergebenes Transkript
  #   2. die Sitzung im Fenster, das beim Tastendruck vorne war - AHK reicht
  #      dessen Prozess durch, sonst wird das Vordergrundfenster selbst gefragt
  #   3. JSON auf stdin (Hook-Aufruf von Hand)
  #   4. das global juengste Transkript
  #
  # Das Fenster wird hier festgehalten, nicht nur durchgereicht: der naechste
  # Tastendruck muss wissen, fuer welches Terminal dieser Ton laeuft.
  if ($WindowPid -le 0) { $WindowPid = Get-ForegroundProcessId }

  $transcript = $Transcript
  if (-not $transcript) { $transcript = Find-TranscriptForWindow $WindowPid }
  if (-not $transcript -and -not [Console]::IsInputRedirected) { $transcript = Find-NewestTranscript }
  if (-not $transcript) {
    $raw = [Console]::In.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      try { $transcript = ($raw | ConvertFrom-Json).transcript_path } catch { }
    }
    if (-not $transcript) { $transcript = Find-NewestTranscript }
  }
  if (-not $transcript) { exit 0 }

  $say = Get-LastSpeakBlock $transcript
  if ([string]::IsNullOrWhiteSpace($say)) { exit 0 }

  Stop-Previous
  Save-ActiveSpeaker $PID $WindowPid (Get-SpeakHash $say)
  Set-Content -Path $ctlFile -Value 'run' -Encoding ascii

  # Hat der Stop-Hook schon vorproduziert, faellt die Synthese hier ganz weg.
  # Sonst wird sie nachgeholt und landet im selben Cache - der zweite Anlauf
  # auf denselben Block ist dann ebenfalls sofort da.
  $cache = Get-SpeakCachePath $say
  if (Test-SpeakCacheHit $cache) {
    $media = $cache
  } else {
    # Schlaegt das fehl, bricht der aeussere catch ab und es bleibt still.
    Write-Mp3EdgeTts $say $cache
    $media = $cache
    Clear-OldSpeakCache
  }
  if (-not $media -or -not (Test-Path $media)) { exit 0 }

  $null = Mci ('open "' + $media + '" type mpegvideo alias ' + $alias)
  $null = Mci ("play $alias")

  $deadline = (Get-Date).AddMinutes(20)
  $paused = $false
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 120

    $want = 'run'
    try { $want = (Get-Content $ctlFile -ErrorAction Stop | Select-Object -First 1).Trim() } catch { }

    if ($want -eq 'stop') { $null = Mci ("stop $alias"); break }

    if ($want -eq 'pause' -and -not $paused) {
      $null = Mci ("pause $alias"); $paused = $true
    }
    elseif ($want -ne 'pause' -and $paused) {
      $null = Mci ("resume $alias"); $paused = $false
    }

    if (-not $paused) {
      $mode = Mci ("status $alias mode")
      if ($mode -notmatch 'playing') { break }
    }
  }

  $null = Mci ("close $alias")
} catch {
} finally {
  # Der Cache bleibt liegen - er ist der ganze Gewinn der Vorproduktion.
  Clear-ActiveSpeaker $PID
  exit 0
}
