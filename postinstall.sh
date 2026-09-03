#!/usr/bin/env bash
# Coloca uma máquina Arch no "trilho joelson": instala dependências oficiais,
# liga os serviços e monta os dotfiles.
#
# Rodar como USUÁRIO normal (pede sudo). Idempotente — pode rodar de novo, e
# serve tanto pós-instalação (ISO) quanto pra alinhar um PC que já roda Arch.
#
#   curl -fsSL https://raw.githubusercontent.com/Joelsonsmendonca/arch-setup/main/postinstall.sh | bash
set -euo pipefail

DOTFILES_GIT='https://github.com/Joelsonsmendonca/hyprdots.git'

msg(){ printf '\e[32m==>\e[0m %s\n' "$*"; }

[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo "rode como usuário normal (não root)"; exit 1; }
command -v sudo >/dev/null || { echo "instale 'sudo' e adicione seu usuário ao grupo wheel primeiro"; exit 1; }
command -v git  >/dev/null || sudo pacman -S --noconfirm --needed git

msg "Ajustando /etc/pacman.conf (multilib)"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  if grep -q '^#\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  else
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
  fi
fi

msg "Instalando pacotes da interface, fontes, ícones e ferramentas essenciais..."
pkgs=(
  # Desktop & Wayland
  hyprland kitty rofi waybar wofi fuzzel uwsm swaync sddm
  qt5-wayland qt6-wayland polkit-kde-agent

  # Áudio & Mídia
  pipewire-jack pipewire-pulse wireplumber pavucontrol playerctl

  # Rede & Conectividade
  network-manager-applet bluez bluez-utils firewalld

  # Fontes & Temas de Ícones
  ttf-jetbrains-mono-nerd breeze-icons noto-fonts-emoji noto-fonts-cjk

  # Utilitários de Desktop
  wl-clipboard grim slurp brightnessctl dolphin btop

  # Ferramentas de Desenvolvimento & Containers
  uv docker docker-compose jq
)
if lspci 2>/dev/null | grep -Eqi 'vga.*nvidia|3d.*nvidia'; then
  pkgs+=(nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland linux-headers)
  msg "  GPU NVIDIA detectada -> pacotes nvidia adicionados"
fi
sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"

msg "Habilitando serviços"
sudo systemctl enable NetworkManager sddm bluetooth firewalld docker
sudo usermod -aG docker "$USER" 2>/dev/null || true
sudo systemctl start NetworkManager 2>/dev/null || true   # no-op se rodando em chroot

msg "Dotfiles (hyprdots)"
if [[ -d "$HOME/dotfiles/.git" ]]; then
  git -C "$HOME/dotfiles" pull --ff-only || true
else
  git clone "$DOTFILES_GIT" "$HOME/dotfiles"
fi
# a lógica de symlink vive no próprio repo de dotfiles (fonte única)
bash "$HOME/dotfiles/bootstrap.sh"


msg "Configurando ai-memory e serviços do usuário"
AIM_VER='2.0.1'
AIM_DATA="$HOME/.local/share/ai-memory"
AIM_WIKI_REPO='git@github.com:Joelsonsmendonca/meu-cerebro-ia.git'
AIM_WIKI_DIR="$HOME/github/meu-cerebro-ia"
AIM_URL='http://127.0.0.1:49374'

if ! command -v ai-memory >/dev/null 2>&1; then
  msg "Instalando binário do ai-memory..."
  curl -fsSL "https://github.com/akitaonrails/ai-memory/releases/download/v${AIM_VER}/ai-memory-linux-x86_64.tar.gz" | sudo tar -xz -C /usr/local/bin/
  sudo chmod +x /usr/local/bin/ai-memory 2>/dev/null || true
fi

# Config base + plug do Ollama (só na primeira vez)
mkdir -p "$HOME/.config/ai-memory" "$AIM_DATA"
if [ ! -f "$HOME/.config/ai-memory/config.toml" ]; then
    ai-memory --data-dir "$AIM_DATA" --config "$HOME/.config/ai-memory/config.toml" init || true
fi
cat > "$HOME/.config/ai-memory/env" <<'EOF_ENV'
AI_MEMORY_LLM_PROVIDER=openai-compat
AI_MEMORY_LLM_MODEL=qwen2.5-coder:7b
AI_MEMORY_LLM_BASE_URL=http://127.0.0.1:11434/v1
AI_MEMORY_LLM_COMPAT_STRICT=false
EOF_ENV

# Clona o "cérebro" e liga como wiki do data-dir (o data-dir espera `wiki/`).
if [ ! -d "$AIM_WIKI_DIR/.git" ]; then
  mkdir -p "$HOME/github"
  git clone "$AIM_WIKI_REPO" "$AIM_WIKI_DIR" || msg "  (clone do meu-cerebro-ia falhou — checar chave SSH)"
fi
if [ -d "$AIM_WIKI_DIR/.git" ] && [ ! -e "$AIM_DATA/wiki" ]; then
  ln -s "$AIM_WIKI_DIR" "$AIM_DATA/wiki"
fi

# Unidade systemd do servidor (o pacote AUR ai-memory-bin também fornece uma;
# este fallback cobre a instalação via tarball).
if ! systemctl --user cat ai-memory.service >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/systemd/user"
  cat > "$HOME/.config/systemd/user/ai-memory.service" <<EOF_UNIT
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
EOF_UNIT
fi
systemctl --user daemon-reload
systemctl --user enable --now ai-memory.service 2>/dev/null || true
sleep 2

# Pluga nos agentes CLI: Claude Code e Antigravity (agy). Idempotente.
for agent in claude-code antigravity-cli; do
  ai-memory install-mcp   --client "$agent" --apply --server-url "$AIM_URL/mcp" 2>/dev/null || true
  ai-memory install-hooks --agent  "$agent" --apply --server-url "$AIM_URL" \
      --project-strategy repo-root 2>/dev/null || true
done

# Sincronização bidirecional GitOps (systemd path+timer)
if [ -f "$HOME/github/arch-setup/setup_ai_memory_sync.sh" ]; then
  bash "$HOME/github/arch-setup/setup_ai_memory_sync.sh" || true
fi

cat <<EOF

$(msg "Feito.")
  • Reinicie (ou 'systemctl start sddm') e escolha a sessão Hyprland.
  • Notebook híbrido: ajuste o PCI da GPU em ~/dotfiles/common/uwsm/env-hyprland
    (ver README do hyprdots) e faça logout/login.
  • Dia a dia, nos dois PCs:  sudo pacman -Syu
EOF
