# Laeuft als Stop-Hook, sobald eine Antwort fertig ist, und legt den Ton fuer
# die letzte Kurzfassung in den Cache. Der Tastendruck findet ihn dann fertig
# vor und muss nicht mehr auf die Synthese warten.
#
# Bewusst still: schlaegt irgendetwas fehl, passiert nichts weiter - der
# Abspielweg synthetisiert dann eben selbst, wie vorher auch.

param([string]$Transcript)

$ErrorActionPreference = 'Stop'

. (Join-Path (Split-Path -Parent $PSCommandPath) 'speak-common.ps1')

try {
  # Erst die eigene Sitzung - der Hook ist ein Nachfahre genau des claude, der
  # gerade fertig geworden ist. Derselbe Aufruf legt die Ahnenkette fuer den
  # Tastendruck ab: hier darf das knapp eine Sekunde dauern, dort nicht.
  # Nur wenn die Kette reisst (verwaister Prozess), bleibt das global juengste
  # Transkript als Notnagel.
  if (-not $Transcript) { $Transcript = Update-SessionWindowLink }
  if (-not $Transcript) { $Transcript = Find-NewestTranscript }
  if (-not $Transcript) { exit 0 }

  $say = Get-LastSpeakBlock $Transcript
  if ([string]::IsNullOrWhiteSpace($say)) { exit 0 }

  $cache = Get-SpeakCachePath $say
  if (Test-SpeakCacheHit $cache) { exit 0 }

  Write-Mp3EdgeTts $say $cache
  Clear-OldSpeakCache
} catch {
} finally {
  exit 0
}
