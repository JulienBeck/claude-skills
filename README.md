# Claude-Code-Skills

Eigene Skills fuer Claude Code. Das Verzeichnis ist zugleich `~/.claude/skills`,
die Skills liegen also dort, wo Claude sie liest - kein Kopierschritt.

Fremde Skills aus dem Marketplace stehen in `.gitignore` und gehoeren nicht hierher.
Ein neuer eigener Skill ist ein Verzeichnis mit `SKILL.md` und erscheint von selbst
im `git status`.

## Auf einer neuen Maschine

```bash
cd ~/.claude/skills
git init -b main
git remote add origin <url>
git fetch origin
git checkout -t origin/main -f
```

Das `-f` ist noetig, weil `~/.claude/skills` dort meist schon gefuellt ist.
