# CLAUDE.md-Sicherungen

Beide Dateien heissen `CLAUDE.md` und koennen deshalb nicht nebeneinander liegen.
Jede bekommt ein eigenes Verzeichnis, benannt nach ihrem Zielort.

| Verzeichnis | gehoert nach | Geltung |
|---|---|---|
| `global/` | `~/.claude/CLAUDE.md` | alle Projekte auf der Maschine |

Zurueckspielen auf einer neuen Maschine:

```bash
cp ~/.claude/skills/claude-md/global/CLAUDE.md ~/.claude/CLAUDE.md
```

Das ist eine Sicherung, kein aktiver Ort: Claude liest hier nichts. Nach einer
Aenderung an `~/.claude/CLAUDE.md` muss die Kopie von Hand nachgezogen werden.
