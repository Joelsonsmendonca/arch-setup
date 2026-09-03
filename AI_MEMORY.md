# 🧠 AI-Memory (Arquitetura P2P GitOps)

Este repositório contém o `setup_ai_memory_sync.sh` (e a seção `ai-memory` do
`postinstall.sh`) para configurar uma rede de nós autônomos do
[ai-memory](https://github.com/akitaonrails/ai-memory).

A arquitetura transforma qualquer máquina (PC, Notebook) em um nó independente:

1. **Push Instantâneo:** ao gravar uma memória, o `systemd.path` (inotify no ref
   git do wiki) commita e envia para o GitHub na hora (0% de CPU quando ocioso).
2. **Pull Passivo:** um timer de 10 min (e no boot) puxa o que outras máquinas
   escreveram.
3. **Reindex automático:** o servidor `ai-memory` roda com um watcher de
   filesystem — arquivos novos vindos do pull entram no índice sozinhos. O script
   de sync **não** chama `ai-memory reindex` (o 2.x recusa reindexar sobre um DB
   não-vazio; reindex é só para reconstrução limpa).

O **`postinstall.sh` já faz tudo isto de forma idempotente**. Os passos manuais
abaixo são a referência do que ele executa.

## Layout na máquina

| O quê | Onde |
| --- | --- |
| Binário | `/usr/local/bin/ai-memory` |
| Config + env (Ollama) | `~/.config/ai-memory/{config.toml,env}` |
| Data-dir (SQLite, índice) | `~/.local/share/ai-memory/` |
| Wiki (markdown, git) | `~/github/meu-cerebro-ia` ← `~/.local/share/ai-memory/wiki` (symlink) |
| Servidor | `~/.config/systemd/user/ai-memory.service` (HTTP em `127.0.0.1:49374`) |
| Sync GitOps | `~/.config/systemd/user/ai-memory-sync.{path,timer,service}` + `~/.local/bin/ai-memory-sync` |

## 🚀 Configurar uma máquina NOVA (Nó)

### Passo 1 — Instalar o binário
```bash
yay -S ai-memory-bin          # traz também a unit systemd
# ou, via release:
curl -fsSL https://github.com/akitaonrails/ai-memory/releases/download/v2.0.1/ai-memory-linux-x86_64.tar.gz \
  | sudo tar -xz -C /usr/local/bin/
```

### Passo 2 — Config + clonar o Cérebro
```bash
mkdir -p ~/.config/ai-memory ~/.local/share/ai-memory ~/github
ai-memory --data-dir ~/.local/share/ai-memory --config ~/.config/ai-memory/config.toml init
cat > ~/.config/ai-memory/env <<'EOF'
AI_MEMORY_LLM_PROVIDER=openai-compat
AI_MEMORY_LLM_MODEL=qwen2.5-coder:7b
AI_MEMORY_LLM_BASE_URL=http://127.0.0.1:11434/v1
AI_MEMORY_LLM_COMPAT_STRICT=false
EOF

git clone git@github.com:Joelsonsmendonca/meu-cerebro-ia.git ~/github/meu-cerebro-ia
ln -sfn ~/github/meu-cerebro-ia ~/.local/share/ai-memory/wiki
```

### Passo 3 — Servidor systemd
Se instalou por release (sem a unit do pacote), crie-a:
```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/ai-memory.service <<'EOF'
[Unit]
Description=ai-memory MCP server (HTTP, local)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=-%h/.config/ai-memory/env
ExecStart=/usr/local/bin/ai-memory --data-dir %h/.local/share/ai-memory serve --transport http
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now ai-memory.service
```

### Passo 4 — Sincronizador bidirecional
```bash
./setup_ai_memory_sync.sh
```

### Passo 5 — Plugar nos agentes CLI (Claude Code + Antigravity)
O servidor local não exige token (bind em loopback). Idempotente:
```bash
for agent in claude-code antigravity-cli; do
  ai-memory install-mcp   --client "$agent" --apply --server-url http://127.0.0.1:49374/mcp
  ai-memory install-hooks --agent  "$agent" --apply --server-url http://127.0.0.1:49374 \
      --project-strategy repo-root
done
```

`--project-strategy repo-root` faz cada sessão resolver o projeto pela raiz do
repo git (colapsa subdiretórios/worktrees) — evita memórias caírem num projeto
espúrio "github" quando o agente é aberto no diretório-pai `~/github`.

Onde cada coisa é escrita:

| Agente | MCP | Hooks |
| --- | --- | --- |
| Claude Code | `~/.claude.json` | `~/.claude/settings.json` |
| Antigravity (`agy`) | `~/.gemini/config/mcp_config.json` | `~/.gemini/config/hooks.json` |

Se precisar de token (ex.: servidor exposto na LAN): `ai-memory generate-auth-token`,
guarde em `AI_MEMORY_AUTH_TOKEN` no `env` do servidor **e** passe
`--auth-token <TOKEN>` nos comandos acima.

### Passo 6 — Instruções por repositório
Dentro de cada projeto que usa o cérebro:
```bash
ai-memory install-instructions --target AGENTS.md --skills-scope project --skills-agent agents
```
Idempotente — mantém o bloco entre `<!-- ai-memory:start -->` / `<!-- ai-memory:end -->`
e instala as Agent Skills em `.agents/skills/`.

Pronto — a máquina é uma réplica do Cérebro.
