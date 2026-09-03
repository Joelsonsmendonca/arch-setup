# Instruções para Agentes — arch-setup

Infraestrutura de automação e configuração para Arch Linux (Lenovo Legion híbrido AMD+NVIDIA e Desktop).
Mantém PC e notebook padronizados e idênticos, provê script de pós-instalação idempotente (`postinstall.sh`), automação de ISO personalizada e sincronização GitOps do cérebro de memórias (`ai-memory`).

---

## 1. Visão Geral e Arquitetura

O repositório opera de forma independente de domínios externos ou servidores proprietários, confiando exclusivamente em:
- **Repositórios Oficiais do Arch Linux**: `core`, `extra`, `multilib` (habilitado no `pacman.conf`).
- **GitHub**: Código fonte, releases da ISO e hospedagem raw dos scripts.
- **GitOps Local / P2P**: Sincronização de memórias (`ai-memory`) com o repositório privado `meu-cerebro-ia`.

### Componentes Principais:
1. **`postinstall.sh`**:
   - Ponto de entrada universal para novas máquinas e alinhamento de máquinas existentes.
   - Idempotente: pode ser executado repetidas vezes sem quebrar o sistema.
   - URL canônica de execução:
     ```bash
     curl -fsSL https://raw.githubusercontent.com/Joelsonsmendonca/arch-setup/main/postinstall.sh | bash
     ```
   - Instala: Hyprland, Waybar, Kitty, Rofi, Wofi, Fuzzel, SwayNC, SDDM, PipeWire, fontes Nerd Font (`ttf-jetbrains-mono-nerd`, `noto-fonts-*`), ícones (`breeze-icons`), ferramentas de desktop (`wl-clipboard`, `grim`, `slurp`, `dolphin`, `btop`) e ferramentas de desenvolvimento (`uv`, `docker`, `docker-compose`, `jq`).
   - Clona os dotfiles (`hyprdots`) em `~/dotfiles` e roda o `bootstrap.sh`.
   - Baixa e ativa o `ai-memory`.
2. **`setup_ai_memory_sync.sh`**:
   - Cria os serviços systemd (`ai-memory-sync.path`, `ai-memory-sync.timer`, `ai-memory-sync.service`) e o binário `~/.local/bin/ai-memory-sync`.
   - Garante push imediato via inotify (`.git/refs/heads/main`) e pull periódico a cada 10 minutos.
3. **`iso/`**:
   - Profile customizado derivado do `releng` do Arch Linux.
   - `build.sh`: Script de montagem da ISO com archinstall customizado (`iso/airootfs/root/joelson.json`).
4. **CI / CD (`.github/workflows/`)**:
   - `test.yml`: Valida a sintaxe dos scripts, testa `postinstall.sh` com `pacman -Sw` e valida o schema de `joelson.json`.
   - `iso.yml`: Workflow para gerar e publicar releases mensais da ISO.

---

## 2. Regras e Convenções para Agentes

### A. Repositórios e Domínios
- **NUNCA** reintroduzir dependências do domínio antigo `www.joelsonmendonca.com`.
- Todos os downloads de scripts e configurações públicas devem apontar para URLs oficiais do GitHub (`raw.githubusercontent.com/Joelsonsmendonca/arch-setup/main/...` ou releases do GitHub).
- Toda dependência de pacotes de sistema deve vir dos repositórios oficiais do Arch (`core`, `extra`, `multilib`), a menos que seja um binário baixado explicitamente de release oficial (como `ai-memory`).

### B. Fontes e Ícones
- A tipografia padrão do ecossistema é **`JetBrainsMono Nerd Font`** (`ttf-jetbrains-mono-nerd`).
- O tema de ícones esperado pelo `fuzzel` e ambiente Wayland é **`breeze-icons`** (`breeze-dark`).
- Ao adicionar novas ferramentas à interface que dependam de fontes ou ícones, declare-as explicitamente no array `pkgs` do `postinstall.sh`.

### C. Commits e Versionamento
- Ao finalizar qualquer alteração neste repositório, execute commits atômicos padronizados (Conventional Commits) usando a IA local (Ollama) via `git aicommit -s -y`.

---

<!-- ai-memory:start -->
## Memória de Longo Prazo (ai-memory)

Este repositório utiliza o [ai-memory](https://github.com/akitaonrails/ai-memory) para continuidade entre sessões.
- As anotações de decisões e mudanças duradouras devem ser registradas nas memórias do projeto.
- Não registre transcrições triviais ou notas rotineiras; registre regras e fatos estruturais.
<!-- ai-memory:end -->
