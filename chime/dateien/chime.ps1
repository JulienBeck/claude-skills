param([string]$Name = 'done')

$ErrorActionPreference = 'SilentlyContinue'

$wav = Join-Path (Join-Path $PSScriptRoot 'chimes') "$Name.wav"
if (-not (Test-Path $wav)) { exit 0 }

# Two hooks can describe the same moment - a question tool also raises a
# notification. Keep the first, drop the echo. Shape: "<name>|<utc ticks>".
$stamp = Join-Path $env:TEMP 'claude-chime-last.txt'
$prevName = ''
$gap = [double]::MaxValue
if (Test-Path $stamp) {
  $parts = (Get-Content $stamp -TotalCount 1) -split '\|'
  if ($parts.Length -eq 2) {
    $prevName = $parts[0]
    $prev = [datetime]::new([int64]$parts[1], [DateTimeKind]::Utc)
    $gap = ([datetime]::UtcNow - $prev).TotalSeconds
  }
}

# The notification hook also fires after a minute of idle input, with no tool
# waiting for anything. Only a fresh PreToolUse mark proves someone is asking.
$toolAge = [double]::MaxValue
$mark = Join-Path $env:TEMP 'claude-chime-tool.txt'
if (Test-Path $mark) {
  $toolAge = ([datetime]::Now - (Get-Item $mark).LastWriteTime).TotalSeconds
}

$suppress = $false
switch ($Name) {
  'done'    { $suppress = ($gap -lt 1.5) }
  'approve' { $suppress = ($toolAge -gt 20.0) -or ($prevName -eq 'ask' -and $gap -lt 5.0) }
}
if ($suppress) { exit 0 }

"$Name|$([datetime]::UtcNow.Ticks)" | Set-Content $stamp -Encoding ASCII
(New-Object System.Media.SoundPlayer $wav).PlaySync()
