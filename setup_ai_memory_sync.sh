#!/bin/bash
# Configura a sincronização bidirecional do AI-Memory (GitOps P2P)

echo "=> Configurando sincronização bidirecional do AI-Memory..."
mkdir -p ~/.local/bin ~/.config/systemd/user

cat << 'INNER_EOF' > ~/.local/bin/ai-memory-sync
#!/bin/bash
cd ~/.local/share/ai-memory/wiki || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

echo "Sincronizando memórias com o GitHub..."
OLD_HEAD=$(git rev-parse HEAD 2>/dev/null)
git pull --rebase origin main >/dev/null 2>&1 || git pull --rebase origin master >/dev/null 2>&1
NEW_HEAD=$(git rev-parse HEAD 2>/dev/null)

if [ "$OLD_HEAD" != "$NEW_HEAD" ]; then
    echo "Novidades recebidas do GitHub! Atualizando o banco de dados local..."
    systemctl --user stop ai-memory
    ai-memory reindex >/dev/null 2>&1
    systemctl --user start ai-memory
fi

git push origin main >/dev/null 2>&1 || git push origin master >/dev/null 2>&1
echo "Sincronização bidirecional concluída!"
INNER_EOF

chmod +x ~/.local/bin/ai-memory-sync

cat << 'INNER_EOF' > ~/.config/systemd/user/ai-memory-sync.path
[Unit]
Description=Push ai-memory to GitHub when a commit happens

[Path]
PathChanged=%h/.local/share/ai-memory/wiki/.git/refs/heads/main

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
