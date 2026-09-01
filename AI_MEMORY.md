# 🧠 AI-Memory (Arquitetura P2P GitOps)

Este repositório contém o script `setup_ai_memory_sync.sh` para configurar uma rede de nós autônomos do [ai-memory](https://github.com/akitaonrails/ai-memory).

A arquitetura transforma qualquer máquina (PC, Notebook) em um nó independente, onde:
1. **Push Instantâneo:** Ao editar memórias localmente, o `systemd.path` (inotify) captura a gravação e envia para o GitHub imediatamente (0% de uso de CPU quando inativo).
2. **Pull Passivo:** Um timer de 10 minutos (e no boot) puxa alterações feitas por outras máquinas silenciosamente.
3. **Reindex Inteligente:** O script de pull só reindexa o SQLite se um commit novo de fato for baixado.

## 🚀 Como configurar uma máquina NOVA (Nó)

Siga os passos abaixo quando estiver em uma máquina nova (ex: notebook recém-formatado):

### Passo 1: Instalar o ai-memory
```bash
# Se tiver o yay instalado:
yay -S ai-memory-bin

# Ou via download direto:
curl -LO https://github.com/akitaonrails/ai-memory/releases/download/v1.38.0/ai-memory-linux-x86_64.tar.gz
tar -xzf ai-memory-linux-x86_64.tar.gz
sudo mv ai-memory /usr/local/bin/
```

### Passo 2: Clonar o Cérebro Central
Crie a estrutura local vazia e baixe os dados do repositório privado do GitHub.
```bash
ai-memory init
rm -rf ~/.local/share/ai-memory/wiki
# Altere para a sua chave Git:
git clone git@github.com:Joelsonsmendonca/meu-cerebro-ia.git ~/.local/share/ai-memory/wiki
ai-memory reindex
```

### Passo 3: Ativar o Sincronizador Bidirecional
Rode o script que está neste repositório para injetar os serviços no Linux:
```bash
./setup_ai_memory_sync.sh
```

### Passo 4: Plugar nos Agentes (Claude Code / Antigravity)
Conecte o servidor de memórias aos seus agentes CLI. Substitua o token pelo que foi gerado (`AI_MEMORY_AUTH_TOKEN`):

**Para o Claude Code:**
```bash
claude mcp add --transport http ai-memory http://127.0.0.1:49374/mcp --header "Authorization: Bearer <SEU_TOKEN>"
ai-memory install-hooks --agent claude-code --apply --server-url "http://127.0.0.1:49374" --auth-token "<SEU_TOKEN>"
```

**Para o Antigravity (agy):**
```bash
ai-memory install-mcp --client agy --apply --server-url "http://127.0.0.1:49374/mcp" --auth-token "<SEU_TOKEN>"
ai-memory install-hooks --agent agy --apply --server-url "http://127.0.0.1:49374" --auth-token "<SEU_TOKEN>"
```

Tudo pronto! Sua máquina agora é uma réplica exata do Cérebro.
