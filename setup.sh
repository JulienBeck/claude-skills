#!/usr/bin/env bash
set -euo pipefail

FREMD=(
  agents-sdk
  cloudflare
  cloudflare-email-service
  cloudflare-one
  cloudflare-one-migrations
  durable-objects
  sandbox-sdk
  turnstile-spin
  web-perf
  workers-best-practices
  wrangler
)

cd "$(dirname "$0")"
REMOTE="${1:-}"

schreibe_gitignore() {
  {
    echo "# Fremde Skills - kommen aus dem Marketplace, nicht aus diesem Repo."
    echo "# Neue eigene Skills tauchen automatisch im git status auf."
    printf '%s/\n' "${FREMD[@]}"
    echo
    echo ".DS_Store"
    echo "Thumbs.db"
  } > .gitignore
}

schreibe_gitattributes() {
  cat > .gitattributes <<'EOF'
# say ist ein Shell-Skript ohne Endung und bricht unter bash mit CRLF.
# Deshalb LF fuer alles; die Windows-Hosts kommen damit zurecht.
* text=auto eol=lf
*.wav binary
EOF
}

schreibe_readme() {
  [ -f README.md ] && return
  cat > README.md <<'EOF'
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
EOF
}

if [ -d .git ]; then
  echo "== Repo besteht bereits, aktualisiere nur .gitignore =="
else
  echo "== git init =="
  git init -b main
fi

schreibe_gitignore
schreibe_gitattributes
schreibe_readme

if [ -n "$REMOTE" ]; then
  if git remote get-url origin >/dev/null 2>&1; then
    echo "== origin steht schon auf $(git remote get-url origin), unveraendert =="
  else
    git remote add origin "$REMOTE"
    echo "== origin gesetzt: $REMOTE =="
  fi
fi

git add -A

echo
echo "== Was im Repo landet =="
git status --short
echo
echo "== Groesse =="
du -sh --exclude=.git . 2>/dev/null || true
echo
echo "== Noch zu tun (macht dieses Skript bewusst nicht) =="
echo "  git commit -m 'Add vorlesen and chime skills'"
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "  git remote add origin <url>"
fi
echo "  git push -u origin main"
