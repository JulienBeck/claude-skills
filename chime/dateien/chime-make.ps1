param(
  [string]$OutDir = (Join-Path $PSScriptRoot 'chimes'),
  [switch]$Preview
)

$ErrorActionPreference = 'Stop'
$rate = 44100

# The pitch gesture carries the meaning: falling = closed, rising = open
# question, a single held tone = someone is waiting for you.
# Tweak f/t/d here and re-run; nothing else needs touching.
# Per motif, 'partials' and 'attack' may override the defaults below.
$motifs = @(
  @{ name = 'done';    gain = 0.30; notes = @(
       @{ f =  880.00; t = 0.000; d = 0.22 },
       @{ f =  739.99; t = 0.085; d = 0.22 },
       @{ f =  587.33; t = 0.170; d = 0.50 }) },
  @{ name = 'ask';     gain = 0.30; notes = @(
       @{ f =  587.33; t = 0.000; d = 0.22 },
       @{ f =  880.00; t = 0.105; d = 0.45 }) },
  # Warm on purpose: low fundamental, quiet upper partials, slow attack and a
  # long tail - it asks rather than knocks.
  @{ name = 'approve'; gain = 0.34; attack = 0.016;
     partials = @(@(1.0, 1.00), @(2.0, 0.14), @(3.0, 0.04)); decay = 2.6; notes = @(
       @{ f =  493.88; t = 0.000; d = 0.75 }) }
)

# Harmonic partials, steeply rolled off - a bare sine sounds like a test tone,
# the third partial is what makes it read as a bell.
$partials = @(@(1.0, 1.00), @(2.0, 0.26), @(3.0, 0.10))

function New-Chime {
  param($motif)

  $end = 0.0
  foreach ($n in $motif.notes) {
    $e = $n.t + $n.d
    if ($e -gt $end) { $end = $e }
  }
  $count = [int]([math]::Ceiling(($end + 0.02) * $rate))
  $buf = New-Object double[] $count

  $voice  = if ($motif.partials) { $motif.partials } else { $partials }
  $attack = if ($motif.attack)   { $motif.attack }   else { 0.005 }
  $decay  = if ($motif.decay)    { $motif.decay }    else { 3.2 }

  foreach ($n in $motif.notes) {
    $start = [int]($n.t * $rate)
    $len   = [int]($n.d * $rate)
    $tau   = $n.d / $decay
    for ($k = 0; $k -lt $len; $k++) {
      $t = $k / $rate
      $env = [math]::Exp(-$t / $tau)
      if ($t -lt $attack) { $env *= $t / $attack }
      $tail = ($len - $k) / $rate
      if ($tail -lt 0.010) { $env *= $tail / 0.010 }
      $v = 0.0
      foreach ($p in $voice) {
        $v += $p[1] * [math]::Sin(2 * [math]::PI * $n.f * $p[0] * $t)
      }
      $buf[$start + $k] += $v * $env
    }
  }

  $peak = 0.0
  foreach ($s in $buf) { $a = [math]::Abs($s); if ($a -gt $peak) { $peak = $a } }
  if ($peak -gt 0) {
    $scale = $motif.gain / $peak
    for ($i = 0; $i -lt $count; $i++) { $buf[$i] *= $scale }
  }
  return $buf
}

function Write-Wav {
  param([string]$Path, [double[]]$Samples)

  $dataLen = $Samples.Length * 2
  $fs = [System.IO.File]::Create($Path)
  try {
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([char[]]'RIFF');  $bw.Write([int](36 + $dataLen)); $bw.Write([char[]]'WAVE')
    $bw.Write([char[]]'fmt ');  $bw.Write([int]16)
    $bw.Write([int16]1);        $bw.Write([int16]1)
    $bw.Write([int]$rate);      $bw.Write([int]($rate * 2))
    $bw.Write([int16]2);        $bw.Write([int16]16)
    $bw.Write([char[]]'data');  $bw.Write([int]$dataLen)
    foreach ($s in $Samples) {
      $v = $s
      if ($v -gt 1.0) { $v = 1.0 } elseif ($v -lt -1.0) { $v = -1.0 }
      $bw.Write([int16][math]::Round($v * 32767))
    }
    $bw.Flush()
  } finally { $fs.Dispose() }
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

foreach ($m in $motifs) {
  $path = Join-Path $OutDir "$($m.name).wav"
  Write-Wav -Path $path -Samples (New-Chime $m)
  $kb = [math]::Round((Get-Item $path).Length / 1KB)
  Write-Host ("{0,-8} {1,5} kB  {2}" -f $m.name, $kb, $path)
  if ($Preview) {
    (New-Object System.Media.SoundPlayer $path).PlaySync()
    Start-Sleep -Milliseconds 400
  }
}
