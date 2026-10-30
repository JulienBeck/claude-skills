---
name: chime
description: Richtet kurze Signaltöne auf einer Windows-Maschine ein - einen, wenn eine Antwort fertig ist, einen, wenn eine Rückfrage oder ein Plan zur Entscheidung ansteht, und einen, wenn ein Werkzeug um Freigabe bittet. Erzeugt die drei WAV-Dateien lokal aus einem Skript, kopiert die Dateien nach ~/.claude und trägt Stop-, PreToolUse- und Notification-Hook in settings.json ein. Auch nutzen zum Umstimmen, Prüfen oder Deinstallieren einer bestehenden Einrichtung.
---

# Chime einrichten

Drei kurze Töne, damit man nicht auf das Terminal starren muss. Alles entsteht
lokal; nichts wird geladen, nichts verlässt den Rechner.

## Was am Ende läuft

| Ereignis | Hook | Ton | Gestalt |
|---|---|---|---|
| Antwort fertig | `Stop` | `done.wav` | drei Töne abwärts, A5–F♯5–D5 — abgeschlossen |
| Rückfrage oder Plan zur Entscheidung | `PreToolUse`, Matcher `AskUserQuestion\|ExitPlanMode` | `ask.wav` | zwei Töne aufwärts, D5–A5, der letzte offen stehend |
| Werkzeug bittet um Freigabe | `Notification` | `approve.wav` | ein einzelner Ton, H4, weich und stehend — wartend |

Unterschieden werden sie über die **Tonbewegung** — fallend, steigend,
stehend. Das ist auch nebenbei hörbar, Klangfarbenunterschiede sind es nicht.
`done` und `ask` teilen sich die Klangfarbe: Grundton plus zweite und dritte
Teilschwingung, exponentiell abklingend. `approve` ist bewusst wärmer — tiefer,
leisere Obertöne, langsamer Einsatz.

## Vor dem Einrichten fragen

Der `Stop`-Hook feuert nach **jeder** Antwort, auch nach einer einzeiligen.
Wer viel in kurzen Schritten arbeitet, hört ihn oft. Fragen, ob

1. alle drei (Vorgabe), oder
2. nur Rückfrage und Freigabe — dann bleibt der `Stop`-Hook weg und es tönt nur,
   wenn wirklich jemand gebraucht wird, oder
3. nur fertig — für lange Läufe, bei denen man weggeht.

## Voraussetzungen

| Prüfen mit | Erwartung |
|---|---|
| `powershell -NoProfile -Command '$PSVersionTable.PSVersion'` | 5.1 oder höher |
| `where wscript.exe` | ein Pfad |

Mehr nicht. `System.Media.SoundPlayer` gehört zu .NET Framework, die WAVs
erzeugt `chime-make.ps1` selbst.

## Schritte

### 1. Dateien kopieren

`chime.ps1`, `chime-run.vbs`, `chime-make.ps1` und `chime` aus `dateien/` nach
`~/.claude/`. Sie finden einander über ihren eigenen Ablageort — es steckt kein
Benutzername darin.

### 2. Töne erzeugen

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<HOME>\.claude\chime-make.ps1" -Preview
```

Schreibt `~/.claude/chimes/{done,ask,approve}.wav` und spielt sie der Reihe
nach vor. Dauert wenige Sekunden — die Sinusberechnung läuft in PowerShell.
`-Preview` weglassen, wenn es still bleiben soll.

**Dem Benutzer vorspielen und fragen, ob es gefällt**, bevor die Hooks
eingetragen werden. Einen Ton beschreiben hilft niemandem; gehört wird in einer
Sekunde entschieden.

### 3. Hooks eintragen

`~/.claude/settings.json` **lesen**, dann einfügen, ohne vorhandene Schlüssel
anzufassen. `Stop` ist beim Benutzer oft schon belegt (Vorlesen) — dann einen
**zweiten Eintrag** in das vorhandene Array hängen, nicht ersetzen.

```json
"hooks": {
  "Stop": [
    { "hooks": [ { "type": "command", "async": true, "timeout": 10,
                   "command": "wscript.exe \"<HOME>\\.claude\\chime-run.vbs\" done" } ] }
  ],
  "PreToolUse": [
    { "matcher": "*",
      "hooks": [ { "type": "command", "async": true, "timeout": 10,
                   "command": "wscript.exe \"<HOME>\\.claude\\chime-run.vbs\" mark" } ] },
    { "matcher": "AskUserQuestion|ExitPlanMode",
      "hooks": [ { "type": "command", "async": true, "timeout": 10,
                   "command": "wscript.exe \"<HOME>\\.claude\\chime-run.vbs\" ask" } ] }
  ],
  "Notification": [
    { "hooks": [ { "type": "command", "async": true, "timeout": 10,
                   "command": "wscript.exe \"<HOME>\\.claude\\chime-run.vbs\" approve" } ] }
  ]
}
```

`<HOME>` durch das echte Benutzerverzeichnis ersetzen — Hooks brauchen absolute
Pfade. Danach mit einem JSON-Parser gegenlesen: eine kaputte `settings.json`
schaltet **alle** Einstellungen daraus still ab.

### 4. Abnahme

| Prüfung | Erwartung |
|---|---|
| `wscript.exe "<HOME>\.claude\chime-run.vbs" ask` | Ton, Aufruf kehrt sofort zurück |
| zweimal schnell hintereinander `approve` nach `ask` | der zweite bleibt still (Entprellung) |
| `approve` ohne vorheriges `mark` | still — das ist der Leerlauffall |
| `mark`, dann `approve` | Ton |
| `/hooks` im laufenden Claude Code | die vier Einträge stehen da |

Hooks werden beim Start gelesen. Nach dem Eintragen einmal `/hooks` öffnen oder
die Sitzung neu starten, sonst feuert nichts.

## Wie es zusammenhängt

```
Stop ───────────► chime-run.vbs done ──┐
PreToolUse ─────► chime-run.vbs ask ───┼─► chime.ps1 ─► Entprellung ─► chimes\<name>.wav
Notification ───► chime-run.vbs approve┘            │      │
PreToolUse * ───► chime-run.vbs mark ──────────────►│      │
                           │          %TEMP%\claude-chime-tool.txt
                           └─────────► %TEMP%\claude-chime-last.txt
```

| Datei | Aufgabe |
|---|---|
| `chime-make.ps1` | erzeugt die drei WAVs; hier stehen Tonhöhen, Längen und Lautstärke |
| `chime.ps1` | entprellt und spielt ab |
| `chime-run.vbs` | startet PowerShell ohne Fenster und abgekoppelt; `mark` setzt nur den Zeitstempel |
| `chime` | dasselbe von Hand aus der Bash |

### Warum entprellt wird

Dieselbe Situation kann zwei Hooks auslösen: eine Rückfrage ist ein Werkzeug
und erzeugt deshalb auch eine Benachrichtigung. `chime.ps1` merkt sich Name und
Zeitpunkt des letzten Tons und unterdrückt

| Ton | wenn |
|---|---|
| `approve` | zuletzt `ask` und keine 5 s her — oder die `mark`-Marke älter als 20 s |
| `done` | irgendein Ton und keine 1,5 s her |

`ask` wird nie unterdrückt — er trägt die meiste Information.

### Was der Notification-Hook sonst noch fängt

Er feuert auch, wenn die Eingabe länger als eine Minute still steht — dann
klänge `approve`, obwohl niemand um Freigabe bittet. Der Text der
Benachrichtigung läge zwar auf der Standardeingabe, aber `wscript.exe` ist
abgekoppelt und reicht ihn nicht durch.

Getrennt werden die beiden deshalb über die Zeit: ein `PreToolUse`-Hook mit
Matcher `*` ruft `chime-run.vbs mark` und setzt stumm einen Zeitstempel. Vor
jeder Freigabefrage läuft er, vor der Leerlaufmeldung nicht. `chime.ps1` spielt
`approve` nur, wenn die Marke jünger als 20 Sekunden ist. Nebenwirkung: auch
die Erinnerung an eine liegengebliebene Freigabe bleibt still.

Der Zweig läuft vor **jedem** Werkzeugaufruf, deshalb startet er keine
PowerShell, sondern legt die Datei in VBScript selbst an.

## Umstimmen

Tonhöhen, Einsatzzeiten, Längen und Lautstärke stehen als Tabelle oben in
`chime-make.ps1`. Ändern, `chime-make.ps1` neu laufen lassen, fertig — die
Hooks bleiben unberührt. Frequenzen in Hertz: H4 493,88 · D5 587,33 ·
F♯5 739,99 · A5 880,00 · D6 1174,66.

Leiser wird es über `gain` je Motiv (Spitzenpegel, 0…1). Dumpfer über die
Gewichte in `$partials`; nur der Grundton klingt nach Testton, deshalb stehen
dort drei. `partials`, `attack` und `decay` lassen sich je Motiv überschreiben
— genau daraus besteht die Wärme von `approve`.

## Wenn etwas nicht geht

| Symptom | Ursache |
|---|---|
| Nie ein Ton | `settings.json` kaputt oder noch nicht geladen — `/hooks` öffnen oder neu starten |
| Nur manche Töne | die passende WAV fehlt; `chime-make.ps1` erneut laufen lassen |
| Ton verspätet oder abgeschnitten | ein anderes Programm hält das Gerät; erster Ton nach dem Hochfahren kostet mehr |
| Doppelter Ton | Entprellung greift nur innerhalb der Fristen oben; bei echten zwei Ereignissen ist zweimal richtig |
| Fenster blitzt auf | der Hook ruft `chime.ps1` direkt statt `chime-run.vbs` |
| `approve` kommt aus dem Nichts, lange nach der letzten Antwort | der `mark`-Hook fehlt oder steht nicht auf Matcher `*` |
| Freigabefrage bleibt still | `%TEMP%\claude-chime-tool.txt` wird nicht geschrieben — `chime-run.vbs mark` von Hand prüfen |

## Deinstallieren

Die vier Hook-Einträge aus `settings.json` nehmen, `chime*.ps1`, `chime-run.vbs`,
`chime`, den Ordner `~/.claude/chimes` sowie `%TEMP%\claude-chime-last.txt` und
`%TEMP%\claude-chime-tool.txt` löschen.
