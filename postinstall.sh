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
if ! command -v ai-memory >/dev/null 2>&1; then
  msg "Instalando binário do ai-memory..."
  curl -fsSL https://github.com/akitaonrails/ai-memory/releases/download/v2.0.1/ai-memory-linux-x86_64.tar.gz | sudo tar -xz -C /usr/local/bin/ ai-memory 2>/dev/null || true
  sudo chmod +x /usr/local/bin/ai-memory 2>/dev/null || true
fi

# Habilita o ai-memory no systemd do usuário
sudo -u "$USER" systemctl --user enable --now ai-memory.service 2>/dev/null || true

# Configuração base para plugar o Ollama
sudo -u "$USER" mkdir -p "$HOME/.config/ai-memory" "$HOME/.local/share/ai-memory"
if [ ! -f "$HOME/.config/ai-memory/config.toml" ]; then
    sudo -u "$USER" ai-memory --data-dir "$HOME/.local/share/ai-memory" --config "$HOME/.config/ai-memory/config.toml" init || true
    sudo -u "$USER" bash -c 'cat << "EOF_ENV" > "$HOME/.config/ai-memory/env"
AI_MEMORY_LLM_PROVIDER=openai-compat
AI_MEMORY_LLM_MODEL=qwen2.5-coder:7b
AI_MEMORY_LLM_BASE_URL=http://127.0.0.1:11434/v1
AI_MEMORY_LLM_COMPAT_STRICT=false
EOF_ENV'
    sudo -u "$USER" sed -i 's/^max_input_tokens = .*/max_input_tokens = 6500/g' "$HOME/.config/ai-memory/config.toml" || true
    sudo -u "$USER" sed -i 's/^max_output_tokens = .*/max_output_tokens = 1000/g' "$HOME/.config/ai-memory/config.toml" || true
    sudo -u "$USER" systemctl --user restart ai-memory.service 2>/dev/null || true
fi

cat <<EOF

$(msg "Feito.")
  • Reinicie (ou 'systemctl start sddm') e escolha a sessão Hyprland.
  • Notebook híbrido: ajuste o PCI da GPU em ~/dotfiles/common/uwsm/env-hyprland
    (ver README do hyprdots) e faça logout/login.
  • Dia a dia, nos dois PCs:  sudo pacman -Syu
EOF
