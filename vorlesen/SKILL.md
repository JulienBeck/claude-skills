---
name: vorlesen
description: Richtet das Vorlesen von Antworten auf einer Windows-Maschine ein - Kurzfassung als speak-Block, vorproduziert per Stop-Hook, abgespielt per Medientaste mit der Stimme Killian über edge-tts. Installiert die Skripte nach ~/.claude, ergänzt den Stop-Hook in settings.json, trägt die Antwort- und Vorleseregeln in die globale CLAUDE.md ein und richtet die Tastenbelegung ein. Auch nutzen zum Prüfen, Reparieren oder Deinstallieren einer bestehenden Einrichtung.
---

# Vorlesen einrichten

Portiert die Vorlese-Einrichtung auf eine neue Windows-Maschine. Alles Nötige
liegt in diesem Skill-Verzeichnis; nichts muss aus dem Netz geladen werden.

## Was am Ende läuft

| Teil | Zweck |
|---|---|
| Regeln in `CLAUDE.md` | Antwort wird knapp und tabellarisch, die Erklärung wandert in einen ```speak-Block |
| Stop-Hook | erzeugt den Ton, sobald eine Antwort fertig ist — **bevor** die Taste gedrückt wird |
| Cache in `%TEMP%\claude-speak-cache` | Schlüssel ist der SHA-256 des Textes, die zwölf jüngsten Dateien bleiben liegen |
| Medientasten / `Strg+Alt+V,P,S` | lösen Vorlesen, Pause und Abbruch aus |

Ohne Vorproduktion dauert es vom Tastendruck bis zum Ton rund sechs Sekunden,
mit rund anderthalb. Der Unterschied ist fast vollständig die Synthese.

## Vor dem Einrichten fragen

Der `speak`-Block geht an **Microsofts Sprachdienst**, und mit dem Stop-Hook
geht er dorthin nach *jeder* längeren Antwort — auch nach einer, die nie
angehört wird. Das muss der Benutzer wissen und wollen. Fragen, ob

1. mit Vorproduktion (schnell, jede Kurzfassung verlässt den Rechner) oder
2. ohne Hook (nur auf Tastendruck, dafür die volle Wartezeit) oder
3. lokal — dann die Offline-Fassung aus
   `~/.claude/backups/vorlesen-offline-stefan` nehmen: nichts verlässt den
   Rechner, dafür nur die Windows-Stimmen Stefan, Katja, Hedda.

Es gibt **keinen Mischbetrieb**. Ist edge-tts nicht erreichbar, bleibt es
stumm, statt still auf eine Windows-Stimme auszuweichen. Der Grund: der
Rückfall war von außen nicht zu hören als das, was er war — er klang nur
plötzlich blechern, ohne dass erkennbar war, dass der Cloud-Weg ausgefallen
ist. Stille ist das ehrlichere Signal.

## Voraussetzungen prüfen

| Prüfen mit | Erwartung | Wenn es fehlt |
|---|---|---|
| `python -m edge_tts --list-voices` | Liste von Stimmen | `pip install edge-tts`; ohne das gibt es überhaupt keinen Ton |
| `powershell -NoProfile -Command '$PSVersionTable.PSVersion'` | 5.1 oder höher | gehört zu Windows |
| `where wscript.exe` | ein Pfad | gehört zu Windows |
| AutoHotkey v2 | für die Medientasten | ohne AHK bleiben nur die Startmenü-Verknüpfungen |

`de-DE-KillianNeural` ist die Stimme. Ob sie noch angeboten wird, zeigt
`python -m edge_tts --list-voices | grep -i killian`.

## Schritte

### 1. Skripte kopieren

Alle sieben Dateien aus `dateien/` nach `~/.claude/` kopieren. Sie finden
einander über ihren eigenen Ablageort — es steckt kein Benutzername darin.

### 2. Stop-Hook eintragen

`~/.claude/settings.json` **lesen**, dann den Hook **einfügen**, ohne
vorhandene Schlüssel anzufassen. Ist schon ein `Stop`-Hook vorhanden: zeigen
und fragen, statt zu überschreiben.

```json
"hooks": {
  "Stop": [
    { "hooks": [ { "type": "command",
                   "command": "wscript.exe \"<HOME>\\.claude\\speak-run.vbs\" prewarm",
                   "async": true, "timeout": 20 } ] }
  ]
}
```

`<HOME>` durch das echte Benutzerverzeichnis ersetzen — der Hook braucht einen
absoluten Pfad. Danach die Datei mit einem JSON-Parser gegenlesen: eine kaputte
`settings.json` schaltet **alle** Einstellungen daraus still ab.

### 3. Regeln in die CLAUDE.md

Den Inhalt von `claude-md-abschnitt.md` an `~/.claude/CLAUDE.md` anhängen.
Gibt es die Abschnitte `## Antworten` oder `## Vorlesen` schon: dem Benutzer
den Unterschied zeigen und fragen, ob ersetzt werden soll.

Diese Regeln gehören in die `CLAUDE.md` und **nicht** in diesen Skill: sie
müssen bei *jeder* Antwort gelten, ein Skill wird aber nur bei Bedarf geladen.

### 4. Tastenbelegung

`speak-hotkeys.ahk` in den Autostart legen (`shell:startup`). Es belegt die
Medientasten, solange Windows Terminal, IntelliJ oder VS Code im Vordergrund
sind — sonst behalten Spotify und Teams sie.

Zusätzlich drei Startmenü-Verknüpfungen auf `wscript.exe "<HOME>\.claude\speak-run.vbs" <aktion>`
mit den Aktionen `read`, `toggle`, `stop` und den Tastenkürzeln
`Strg+Alt+V`, `Strg+Alt+P`, `Strg+Alt+S`. Diese wirken systemweit.
Verknüpfungen kann der Benutzer schneller selbst anlegen als du — anbieten,
nicht erzwingen.

### 5. Abnahme

| Prüfung | Erwartung |
|---|---|
| `echo '{}' \| wscript.exe "<HOME>\.claude\speak-run.vbs" prewarm` | kehrt in unter einer Sekunde zurück |
| danach `%TEMP%\claude-speak-cache` | nach wenigen Sekunden eine `.mp3` über 100 kB |
| Medientaste drücken | Ton nach etwa anderthalb Sekunden |

Erst messen, dann melden. Eine Zeitangabe ohne Messung ist wertlos.

## Wie es zusammenhängt

```
Stop-Hook ──► speak-run.vbs prewarm ──► speak-ctl.ps1 ──► speak-prewarm.ps1 ──► Cache
                                                                            └─► Fenstertabelle
Medientaste ► speak-run.vbs media   ──► speak-ctl.ps1 ──► speak-last.ps1 ────► Cache ──► Wiedergabe
   │                                                            ▲
   └── WinGetPID("A") ───────── Fensterprozess ─────────────────┘
```

| Datei | Aufgabe |
|---|---|
| `speak-common.ps1` | Transkript finden, letzten ```speak-Block lesen, Cache-Schlüssel bilden, edge-tts rufen |
| `speak-prewarm.ps1` | füllt den Cache, still; jeder Fehler bleibt folgenlos |
| `speak-last.ps1` | Cache-Treffer abspielen, sonst selbst synthetisieren; Wiedergabe über MCI mit Pause und Stopp. Kein lokaler Rückfall — schlägt edge-tts fehl, bleibt es still |
| `speak-ctl.ps1` | Aktionen `read`, `pause`, `resume`, `toggle`, `stop`, `status`, `prewarm`, `media` |
| `speak-run.vbs` | startet PowerShell ohne Fenster und abgekoppelt, reicht `-Inline` durch |
| `speak-hotkeys.ahk` | Medientasten, nur bei passendem Vordergrundfenster |
| `say` | dasselbe von Hand aus der Bash |

### Welche Sitzung wird vorgelesen

Bei mehreren offenen Sitzungen ist das global jüngste Transkript die falsche
Quelle — es gewinnt, wer zuletzt geschrieben hat, nicht das Fenster, das man
gerade ansieht. Deshalb:

| Schritt | Wo |
|---|---|
| AHK gibt den Prozess des aktiven Fensters mit (`WinGetPID("A")`) | `speak-hotkeys.ahk` |
| Stop-Hook legt für jede lebende Sitzung Ahnenkette und Kennung der letzten Antwort ab | `Update-SessionWindowLink`, `New-SpeakLink` |
| Tastendruck schlägt die Fenster-PID in dieser Tabelle nach | `Find-SessionForWindow` |

Die Tabelle liegt in `%TEMP%\claude-speak-windows.json`, die Sitzungsdaten
kommen aus `~/.claude/sessions/<pid>.json` (Feld `sessionId`, dazu `procStart`
gegen wiederverwendete PIDs). Die Kennung ist der SHA-256 des letzten
```speak-Blocks — derselbe Schlüssel wie im Cache.

### Play/Pause ist fensterbezogen

Die Taste darf nicht einfach pausieren, was gerade läuft: wer ein anderes
Terminal anklickt, will dessen letzte Antwort hören, nicht die laufende
anhalten. `speak-last.ps1` legt deshalb in `%TEMP%\claude-speak.now.json` ab,
für welches Fenster und welche Antwort der Ton läuft (`Save-ActiveSpeaker`).

| Lage beim Druck | Was passiert |
|---|---|
| nichts läuft | vorlesen |
| läuft, aber für ein anderes Fenster | abbrechen, Antwort des aktiven Fensters von vorn vorlesen |
| läuft für dieses Fenster, Antwort ist noch die letzte | pausieren bzw. fortsetzen |
| läuft für dieses Fenster, inzwischen neue Antwort fertig | die neue von vorn vorlesen |

Der Vergleich geht über die Kennung, nicht über die Uhrzeit: das Transkript
wird während der Arbeit dauernd geschrieben, eine neue *Antwort* ist es erst,
wenn ein anderer ```speak-Block darin steht.

Nachgeschlagen wird dabei nur in der vorgehaltenen Tabelle (`-FastOnly`).
Fehlt sie, bleibt es beim Umschalten — lieber einmal falsch pausiert als eine
Sekunde im Prozessbaum gewartet.

Warum vorgehalten statt gerechnet: `Win32_Process` zu lesen kostet gemessen
0,8–1,1 s, einzeln abgefragt über 3 s. Das ist mehr, als die Vorproduktion
einspart. Im Hook wartet niemand, beim Tastendruck schon — gemessen rund 25 ms
für das Nachschlagen, gegen 1,1 s beim ersten Mal ohne Tabelle.

Zwei Grenzen, die bleiben:

- **Tabs sind keine Fenster.** Windows Terminal und IntelliJ halten alle Tabs
  eines Fensters unter einem Prozess. Zwei Sitzungen im selben Fenster sind von
  außen nicht zu trennen; dort entscheidet dann die jüngste Schreibzeit.
- **Sitzungen aus dem IntelliJ-Plugin** (`entrypoint: sdk-ts`) schreiben kein
  Transkript unter `projects/`. Dort gibt es nichts vorzulesen, der Tastendruck
  fällt auf das jüngste Terminal-Transkript zurück.

Zwei Feinheiten, die leicht verloren gehen:

`-Inline` lässt `speak-ctl.ps1` das Vorlesen im eigenen Prozess erledigen statt
einen zweiten PowerShell zu starten — das spart eine halbe Sekunde und ist nur
auf dem Tastenweg richtig, weil dort ohnehin schon abgekoppelt gelaufen wird.
Von Hand aus dem Terminal würde es die Eingabe blockieren.

edge-tts schreibt erst in eine `.part`-Datei und benennt sie dann um. Ohne das
sieht der Abspielweg eine halb geschriebene MP3 als Treffer an.

## Wenn etwas nicht geht

| Symptom | Ursache |
|---|---|
| Nichts passiert | kein ```speak-Block in der letzten Antwort — das ist bei kurzen Antworten richtig so |
| Volle Wartezeit trotz Hook | zu früh gedrückt; der Cache ist erst einige Sekunden nach Antwortende gefüllt |
| Hook feuert nie | `settings.json` kaputt oder noch nicht geladen — einmal `/hooks` öffnen oder neu starten |
| Stille, obwohl ein ```speak-Block da ist | edge-tts nicht erreichbar. Mit `python -m edge_tts -t test --write-media %TEMP%\t.mp3` nachsehen — einen lokalen Ersatz gibt es bewusst nicht |
| Medientasten wirken nicht | falsches Vordergrundfenster, oder AutoHotkey läuft nicht |
| Es liest die Antwort eines anderen Fensters vor | die Fenstertabelle fehlt oder ist kalt. Sie entsteht beim ersten Stop-Hook nach dem Start; ohne sie wird auf das jüngste Transkript zurückgefallen |
| Es liest den falschen Tab desselben Fensters vor | so gebaut — Tabs sind von außen nicht trennbar, es gewinnt der zuletzt fertige |
| Play/Pause pausiert, statt im neuen Fenster vorzulesen | die Fenstertabelle ist kalt, beide Fenster sehen gleich aus. Einmal auf den Stop-Hook warten |

## Deinstallieren

Stop-Hook aus `settings.json` entfernen, die sieben Dateien und den
Cache-Ordner löschen, AHK aus dem Autostart nehmen, die beiden Abschnitte aus
der `CLAUDE.md` streichen.
