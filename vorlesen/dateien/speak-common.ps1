# Gemeinsame Bausteine fuer speak-prewarm.ps1 (produziert vor) und
# speak-last.ps1 (spielt ab). Beide muessen dieselbe Quelle lesen und denselben
# Cache-Schluessel bilden - weichen sie voneinander ab, trifft der Tastendruck
# nie den vorproduzierten Ton und die Wartezeit ist zurueck.

$CloudVoice = 'de-DE-KillianNeural'
$CloudRate = '+0%'

$SpeakCacheDir = Join-Path $env:TEMP 'claude-speak-cache'

function Find-NewestTranscript {
  $root = Join-Path $env:USERPROFILE '.claude\projects'
  if (-not (Test-Path $root)) { return $null }
  $file = Get-ChildItem $root -Recurse -Filter '*.jsonl' -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -notmatch '\\subagents$' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($file) { return $file.FullName }
  return $null
}

# --- Sitzung am Fenster festmachen ------------------------------------------
#
# Das global juengste Transkript ist die falsche Quelle, sobald mehrere
# Sitzungen laufen: es gewinnt, wer zuletzt geschrieben hat, und nicht die
# Sitzung, die man gerade ansieht. Claude Code legt pro Prozess eine Datei
# unter ~/.claude/sessions/<pid>.json ab, die sessionId und cwd nennt - damit
# laesst sich vom Fenster ueber den Prozessbaum bis zum Transkript laufen.
#
# Grenze, die bleibt: Windows Terminal und IntelliJ halten alle Tabs eines
# Fensters unter *einem* Fensterprozess. Zwei Sitzungen in zwei Tabs desselben
# Fensters sind von aussen nicht zu trennen; dort entscheidet dann wieder die
# juengste Schreibzeit - also die Sitzung, in der zuletzt eine Antwort fertig
# wurde. Das ist in der Praxis genau die, die man ansieht.

function Get-ProcessParentMap {
  $map = @{}
  try {
    foreach ($p in Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId -ErrorAction Stop) {
      $map[[int]$p.ProcessId] = [int]$p.ParentProcessId
    }
  } catch { }
  return $map
}

# Lebende Sitzungen samt Transkript. Die sessionId ist eindeutig, deshalb wird
# der Transkriptpfad gesucht statt aus cwd zusammengebaut - die Regel, nach der
# Claude Code den Projektordner benennt, muss hier dann nicht nachgebildet
# werden und kann sich aendern, ohne das Vorlesen zu zerlegen.
function Get-LiveClaudeSessions {
  $dir = Join-Path $env:USERPROFILE '.claude\sessions'
  $root = Join-Path $env:USERPROFILE '.claude\projects'
  if (-not (Test-Path $dir) -or -not (Test-Path $root)) { return @() }

  $out = @()
  foreach ($f in Get-ChildItem $dir -Filter '*.json' -ErrorAction SilentlyContinue) {
    try { $j = Get-Content $f.FullName -Raw -ErrorAction Stop | ConvertFrom-Json } catch { continue }
    if (-not $j.pid -or -not $j.sessionId) { continue }

    $proc = Get-Process -Id ([int]$j.pid) -ErrorAction SilentlyContinue
    if (-not $proc) { continue }

    # PID-Wiederverwendung: Windows vergibt Nummern neu. Ohne diesen Vergleich
    # koennte ein fremder Prozess die Sitzung eines laengst beendeten claude
    # erben und das Vorlesen auf ein totes Transkript schicken.
    if ($j.procStart) {
      try {
        if ($proc.StartTime.ToFileTime().ToString() -ne $j.procStart.ToString()) { continue }
      } catch { }
    }

    $hit = Get-ChildItem $root -Recurse -Filter ($j.sessionId + '.jsonl') -ErrorAction SilentlyContinue |
      Where-Object { $_.DirectoryName -notmatch '\\subagents$' } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $hit) { continue }

    $out += [pscustomobject]@{
      Pid        = [int]$j.pid
      SessionId  = [string]$j.sessionId
      Transcript = $hit.FullName
      Written    = $hit.LastWriteTime
    }
  }
  return $out
}

# --- Die Zuordnung wird vorgehalten, nicht bei jedem Tastendruck berechnet ---
#
# Der Prozessbaum ist teuer: Win32_Process zu lesen kostet auf dieser Maschine
# gemessen 0,8 bis 1,1 Sekunden, einzeln abgefragt sogar ueber drei. Das ist
# mehr, als die Vorproduktion einspart - der Tastendruck waere wieder langsam.
#
# Deshalb dieselbe Arbeitsteilung wie beim Ton: Der Stop-Hook laeuft ohnehin
# nach jeder Antwort, abgekoppelt und ohne dass jemand wartet. Er legt die
# Ahnenkette seiner Sitzung ab; der Tastendruck schlaegt darin nur noch nach.
#
# Die Kette endet beim ersten Prozess mit sichtbarem Fenster. Ohne diesen
# Schnitt stuenden auch svchost und wininit darin - und die sind Vorfahren von
# allem, jeder Treffer waere also richtig und damit wertlos.

$SpeakLinkFile = Join-Path $env:TEMP 'claude-speak-windows.json'

function Get-SessionWindowLinks {
  if (-not (Test-Path $SpeakLinkFile)) { return @{} }
  try {
    $raw = Get-Content $SpeakLinkFile -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
    $obj = $raw | ConvertFrom-Json
    $out = @{}
    foreach ($p in $obj.PSObject.Properties) { $out[$p.Name] = $p.Value }
    return $out
  } catch { return @{} }
}

# Atomar schreiben: zwei Sitzungen koennen gleichzeitig fertig werden. Ohne
# Umbenennen laese der naechste Tastendruck eine halb geschriebene Datei.
function Save-SessionWindowLinks($links) {
  try {
    $tmp = "$SpeakLinkFile.$PID.part"
    ($links | ConvertTo-Json -Depth 6 -Compress) | Set-Content -Path $tmp -Encoding utf8 -ErrorAction Stop
    Move-Item -LiteralPath $tmp -Destination $SpeakLinkFile -Force -ErrorAction Stop
  } catch {
    Remove-Item "$SpeakLinkFile.$PID.part" -Force -ErrorAction SilentlyContinue
  }
}

# Ein Eintrag der Tabelle: wohin das Transkript zeigt, ueber welche Fenster die
# Sitzung erreichbar ist und welche Antwort dort zuletzt stand. Die Kennung der
# Antwort kostet einmal das Transkript lesen - das passiert im Hook, wo niemand
# wartet, und erspart dem Tastendruck genau diese Arbeit.
function New-SpeakLink($session, $parentMap) {
  $say = $null
  try { $say = Get-LastSpeakBlock $session.Transcript } catch { }
  $hash = $null
  if (-not [string]::IsNullOrWhiteSpace($say)) { $hash = Get-SpeakHash $say }
  return [pscustomobject]@{
    transcript = $session.Transcript
    ancestors  = @(Get-AncestryToWindow $session.Pid $parentMap)
    hash       = $hash
  }
}

function Get-AncestryToWindow([int]$leafPid, $parentMap) {
  $withWindow = @{}
  foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
    if ($p.MainWindowHandle -ne 0) { $withWindow[$p.Id] = $true }
  }
  $chain = @()
  $cur = $leafPid
  for ($i = 0; $i -lt 16; $i++) {
    $chain += $cur
    if ($withWindow.ContainsKey($cur)) { break }
    if (-not $parentMap.ContainsKey($cur)) { break }
    $next = $parentMap[$cur]
    if ($next -le 4 -or $next -eq $cur) { break }
    $cur = $next
  }
  return $chain
}

# Vom Stop-Hook gerufen. Teuer, aber niemand wartet darauf.
#
# Es wird die Tabelle fuer *alle* lebenden Sitzungen neu gebaut, nicht nur fuer
# die eigene. Der Grund ist der Weg hierher: speak-run.vbs startet PowerShell
# abgekoppelt und beendet sich sofort. Damit ist dieser Prozess verwaist - die
# Elternkette endet nach einem Schritt an einer toten PID, die eigene Sitzung
# ist von hier aus also gar nicht zu ermitteln.
#
# Alle zu erfassen loest das nicht nur, es ist auch billiger: der Prozessbaum
# wird ohnehin einmal gelesen, und wer den Hook ausgeloest hat, muss dann
# niemanden mehr interessieren.
function Update-SessionWindowLink {
  $sessions = @(Get-LiveClaudeSessions)
  if ($sessions.Count -eq 0) { return $null }
  $parentMap = Get-ProcessParentMap
  if ($parentMap.Count -eq 0) { return $null }

  $links = @{}
  foreach ($s in $sessions) {
    $links[$s.Pid.ToString()] = New-SpeakLink $s $parentMap
  }
  Save-SessionWindowLinks $links

  # Der Hook feuert unmittelbar nachdem die Antwort geschrieben wurde - das
  # juengste Transkript ist also seines. Fuer den Ton reicht das; die
  # Fensterzuordnung oben haengt ohnehin nicht daran.
  return (($sessions | Sort-Object Written -Descending | Select-Object -First 1).Transcript)
}

# Welche Sitzung gehoert zum Fenster im Vordergrund? Erst die vorgehaltene
# Tabelle - das sind wenige Millisekunden. Nur wenn dort nichts steht (erster
# Lauf, Hook abgeschaltet), wird der teure Weg gegangen und das Ergebnis gleich
# abgelegt, damit es beim naechsten Mal schnell ist.
#
# -FastOnly schaltet den teuren Weg ab. Der Tastendruck entscheidet damit nur
# noch zwischen Pausieren und Neulesen - dafuer darf er keine Sekunde im
# Prozessbaum verbringen, lieber faellt er auf das gewohnte Umschalten zurueck.
function Find-SessionForWindow([int]$WindowPid = 0, [switch]$FastOnly) {
  if ($WindowPid -le 0) { $WindowPid = Get-ForegroundProcessId }
  if ($WindowPid -le 0) { return $null }

  $links = Get-SessionWindowLinks
  if ($links.Count -gt 0) {
    $hits = @()
    foreach ($k in $links.Keys) {
      $entry = $links[$k]
      if (-not $entry.ancestors -or -not $entry.transcript) { continue }
      if (@($entry.ancestors) -notcontains $WindowPid) { continue }
      if (-not (Get-Process -Id ([int]$k) -ErrorAction SilentlyContinue)) { continue }
      if (-not (Test-Path $entry.transcript)) { continue }
      $hits += [pscustomobject]@{
        Transcript = [string]$entry.transcript
        Hash       = [string]$entry.hash
        Written    = (Get-Item $entry.transcript).LastWriteTime
      }
    }
    if ($hits.Count -gt 0) {
      # Mehrere Tabs im selben Fenster: die zuletzt beschriebene gewinnt.
      return ($hits | Sort-Object Written -Descending | Select-Object -First 1)
    }
  }

  if ($FastOnly) { return $null }
  return (Find-SessionForWindowSlow $WindowPid)
}

function Find-SessionForWindowSlow([int]$WindowPid) {
  $sessions = @(Get-LiveClaudeSessions)
  if ($sessions.Count -eq 0) { return $null }
  $parentMap = Get-ProcessParentMap
  if ($parentMap.Count -eq 0) { return $null }

  $links = Get-SessionWindowLinks
  $matched = @()
  foreach ($s in $sessions) {
    $entry = New-SpeakLink $s $parentMap
    $links[$s.Pid.ToString()] = $entry
    if (@($entry.ancestors) -contains $WindowPid) {
      $matched += [pscustomobject]@{
        Transcript = $s.Transcript
        Hash       = $entry.hash
        Written    = $s.Written
      }
    }
  }
  Save-SessionWindowLinks $links

  if ($matched.Count -eq 0) { return $null }
  return ($matched | Sort-Object Written -Descending | Select-Object -First 1)
}

function Find-TranscriptForWindow([int]$WindowPid = 0) {
  $hit = Find-SessionForWindow $WindowPid
  if ($hit) { return $hit.Transcript }
  return $null
}

# --- Was laeuft gerade, und fuer welches Fenster? ----------------------------
#
# Ohne diese Angabe war die Medientaste blind: lief irgendwo etwas, wurde
# pausiert - auch wenn man gerade ein ganz anderes Terminal angeklickt hatte.
# Mit Fenster und Antwortkennung daneben kann der Tastendruck unterscheiden,
# ob er dasselbe pausieren oder etwas anderes vorlesen soll.
$SpeakNowFile = Join-Path $env:TEMP 'claude-speak.now.json'

function Get-ActiveSpeaker {
  if (-not (Test-Path $SpeakNowFile)) { return $null }
  try {
    $raw = Get-Content $SpeakNowFile -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $j = $raw | ConvertFrom-Json
    if (-not $j.pid) { return $null }
    $proc = Get-Process -Id ([int]$j.pid) -ErrorAction SilentlyContinue
    if (-not $proc -or $proc.ProcessName -notmatch '^(powershell|pwsh)$') { return $null }
    return [pscustomobject]@{
      Pid       = [int]$j.pid
      WindowPid = [int]$j.windowPid
      Hash      = [string]$j.hash
    }
  } catch { return $null }
}

function Save-ActiveSpeaker([int]$ownerPid, [int]$windowPid, [string]$hash) {
  try {
    $tmp = "$SpeakNowFile.$PID.part"
    ([pscustomobject]@{ pid = $ownerPid; windowPid = $windowPid; hash = $hash } |
      ConvertTo-Json -Compress) | Set-Content -Path $tmp -Encoding utf8 -ErrorAction Stop
    Move-Item -LiteralPath $tmp -Destination $SpeakNowFile -Force -ErrorAction Stop
  } catch {
    Remove-Item "$SpeakNowFile.$PID.part" -Force -ErrorAction SilentlyContinue
  }
}

# Nur der eigene Eintrag wird geraeumt. Sonst loescht ein gerade beendeter
# Vorleser den Eintrag des Nachfolgers, der ihn eben abgeloest hat.
function Clear-ActiveSpeaker([int]$ownerPid) {
  try {
    $cur = Get-Content $SpeakNowFile -Raw -ErrorAction Stop | ConvertFrom-Json
    if ([int]$cur.pid -eq $ownerPid) { Remove-Item $SpeakNowFile -Force -ErrorAction SilentlyContinue }
  } catch { }
}

function Get-ForegroundProcessId {
  try {
    if (-not ('Speak.Fg' -as [type])) {
      Add-Type -Namespace Speak -Name Fg -MemberDefinition @'
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(System.IntPtr h, out int pid);
'@ -ErrorAction Stop
    }
    $h = [Speak.Fg]::GetForegroundWindow()
    if ($h -eq [IntPtr]::Zero) { return 0 }
    $id = 0
    $null = [Speak.Fg]::GetWindowThreadProcessId($h, [ref]$id)
    return [int]$id
  } catch { return 0 }
}

function Get-LastSpeakBlock([string]$path) {
  if (-not (Test-Path $path)) { return $null }
  $found = $null
  foreach ($line in [System.IO.File]::ReadLines($path, [System.Text.Encoding]::UTF8)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line -notmatch '```speak') { continue }
    try { $entry = $line | ConvertFrom-Json } catch { continue }
    if ($entry.type -ne 'assistant') { continue }
    $content = $entry.message.content
    if ($content -isnot [System.Collections.IEnumerable] -or $content -is [string]) { continue }
    foreach ($part in $content) {
      if ($part.type -ne 'text' -or -not $part.text) { continue }
      $hits = [regex]::Matches($part.text, '(?s)```speak\s*\r?\n(.*?)```')
      if ($hits.Count -gt 0) { $found = $hits[$hits.Count - 1].Groups[1].Value.Trim() }
    }
  }
  return $found
}

# Der Schluessel haengt nur am Text, nicht am Zeitpunkt: derselbe Block ergibt
# dieselbe Datei, egal ob ihn der Hook oder der Tastendruck erzeugt hat. Er
# dient zugleich als Kennung der Antwort - daran erkennt der Tastendruck, ob
# das, was gerade laeuft, noch die letzte Antwort des Fensters ist.
function Get-SpeakHash([string]$say) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($say)
    return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  } finally { $sha.Dispose() }
}

function Get-SpeakCachePath([string]$say) {
  return (Join-Path $SpeakCacheDir ((Get-SpeakHash $say) + '.mp3'))
}

function Test-SpeakCacheHit([string]$path) {
  return ((Test-Path $path) -and ((Get-Item $path -ErrorAction SilentlyContinue).Length -ge 512))
}

# Erst in eine Datei neben dem Ziel schreiben, dann umbenennen. Sonst sieht der
# Abspielweg eine halb geschriebene MP3 als Treffer an und spielt Bruchstueck.
function Write-Mp3EdgeTts([string]$say, [string]$target) {
  if (-not $CloudVoice) { throw 'Cloud-Stimme abgeschaltet' }
  $dir = Split-Path -Parent $target
  if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
  $txtFile = Join-Path $env:TEMP ("claude-speak-$PID.txt")
  $partial = "$target.$PID.part"
  [System.IO.File]::WriteAllText($txtFile, $say, (New-Object System.Text.UTF8Encoding $false))
  $env:PYTHONUTF8 = '1'
  try {
    $null = & python -m edge_tts --voice $CloudVoice --rate $CloudRate --file $txtFile --write-media $partial 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('edge-tts endete mit ' + $LASTEXITCODE) }
    if (-not (Test-Path $partial) -or (Get-Item $partial).Length -lt 512) { throw 'edge-tts lieferte keine Audiodatei' }
    Move-Item -LiteralPath $partial -Destination $target -Force
  } finally {
    Remove-Item $txtFile -Force -ErrorAction SilentlyContinue
    Remove-Item $partial -Force -ErrorAction SilentlyContinue
  }
}

function Clear-OldSpeakCache([int]$Keep = 12) {
  if (-not (Test-Path $SpeakCacheDir)) { return }
  Get-ChildItem $SpeakCacheDir -Filter '*.mp3' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -Skip $Keep |
    Remove-Item -Force -ErrorAction SilentlyContinue
}
