#!/bin/bash
# Configura a sincronização bidirecional do AI-Memory (GitOps P2P).
#
# - push imediato: ai-memory-sync.path (inotify no ref do git do wiki)
# - pull periódico: ai-memory-sync.timer (a cada 10 min + no boot)
# O servidor ai-memory tem watcher de filesystem próprio, então arquivos novos
# vindos do pull são reindexados sozinhos — não forçamos `reindex` aqui
# (reindex 2.x recusa rodar sobre um DB não-vazio).
set -eu

WIKI_DIR="$HOME/github/meu-cerebro-ia"

echo "=> Configurando sincronização bidirecional do AI-Memory..."
mkdir -p ~/.local/bin ~/.config/systemd/user

cat << 'INNER_EOF' > ~/.local/bin/ai-memory-sync
#!/bin/bash
set -u
WIKI="$(readlink -f "$HOME/.local/share/ai-memory/wiki" 2>/dev/null)"
[ -d "$WIKI/.git" ] || WIKI="$HOME/github/meu-cerebro-ia"
cd "$WIKI" 2>/dev/null || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

exec 9>"$HOME/.local/share/ai-memory/.sync.lock"
flock -n 9 || exit 0

BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo main)"
echo "Sincronizando memórias com o GitHub (branch: $BRANCH)..."
OLD_HEAD=$(git rev-parse HEAD 2>/dev/null)

if ! git diff --quiet || ! git diff --cached --quiet || \
   [ -n "$(git ls-files --others --exclude-standard)" ]; then
    git add -A
    git commit -m "sync: alterações locais do ai-memory (${HOSTNAME:-$(uname -n)} $(date -Iseconds))" >/dev/null 2>&1
fi

git pull --rebase origin "$BRANCH" >/dev/null 2>&1
NEW_HEAD=$(git rev-parse HEAD 2>/dev/null)
[ "$OLD_HEAD" != "$NEW_HEAD" ] && echo "Novidades recebidas — o watcher do ai-memory vai reindexar."

git push origin "$BRANCH" >/dev/null 2>&1
echo "Sincronização bidirecional concluída!"
INNER_EOF

chmod +x ~/.local/bin/ai-memory-sync

cat << INNER_EOF > ~/.config/systemd/user/ai-memory-sync.path
[Unit]
Description=Push ai-memory to GitHub when a commit happens

[Path]
PathChanged=${WIKI_DIR}/.git/refs/heads/main

[Install]
WantedBy=default.target
INNER_EOF

cat << 'INNER_EOF' > ~/.config/systemd/user/ai-memory-sync.timer
[Unit]
Description=Sync ai-memory wiki from GitHub periodically

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min
Persistent=true

[Install]
WantedBy=timers.target
INNER_EOF

cat << 'INNER_EOF' > ~/.config/systemd/user/ai-memory-sync.service
[Unit]
Description=Sync ai-memory wiki to GitHub

[Service]
Type=oneshot
ExecStart=%h/.local/bin/ai-memory-sync
INNER_EOF

echo "=> Ativando serviços no Systemd..."
systemctl --user daemon-reload
systemctl --user enable --now ai-memory-sync.path
systemctl --user enable --now ai-memory-sync.timer

echo "=> Pronto! A arquitetura GitOps do AI-Memory está ativa."
