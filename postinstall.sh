#!/usr/bin/env bash
# Coloca uma máquina Arch no "trilho joelson": confia no repo [joelson], instala
# joelson-base (+ nvidia), liga os serviços e monta os dotfiles.
#
# Rodar como USUÁRIO normal (pede sudo). Idempotente — pode rodar de novo, e
# serve tanto pós-instalação (ISO) quanto pra alinhar um PC que já roda Arch.
#
#   curl -fsSL https://www.joelsonmendonca.com/arch-setup/postinstall.sh | bash
set -euo pipefail

REPO='https://www.joelsonmendonca.com/arch-setup'
DOTFILES_GIT='https://github.com/Joelsonsmendonca/hyprdots.git'

msg(){ printf '\e[32m==>\e[0m %s\n' "$*"; }

[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo "rode como usuário normal (não root)"; exit 1; }
command -v sudo >/dev/null || { echo "instale 'sudo' e adicione seu usuário ao grupo wheel primeiro"; exit 1; }
command -v git  >/dev/null || sudo pacman -S --noconfirm --needed git

msg "Confiando na chave de assinatura do repo"
KEYID=$(curl -fsSL "$REPO/KEYID")
key=$(mktemp)
curl -fsSL "$REPO/joelson-repo.gpg" -o "$key"
sudo pacman-key --add "$key"
sudo pacman-key --lsign-key "$KEYID"
rm -f "$key"

msg "Ajustando /etc/pacman.conf (multilib + [joelson])"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  if grep -q '^#\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  else
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
  fi
fi
if ! grep -q '^\[joelson\]' /etc/pacman.conf; then
  sudo tee -a /etc/pacman.conf >/dev/null <<EOF

[joelson]
SigLevel = Required
Server = $REPO/\$arch
EOF
fi

msg "Instalando pacotes"
# pipewire-jack explícito: resolve "2 providers for jack" sem prompt (senão pega jack2 e conflita)
pkgs=(pipewire-jack joelson-base)
if lspci 2>/dev/null | grep -Eqi 'vga.*nvidia|3d.*nvidia'; then
  pkgs+=(joelson-nvidia); msg "  GPU NVIDIA detectada -> joelson-nvidia"
fi
sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"

msg "Habilitando serviços"
sudo systemctl enable NetworkManager sddm bluetooth firewalld
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
# Habilita o ai-memory no systemd do usuário
sudo -u "$USER" systemctl --user enable --now ai-memory.service 2>/dev/null || true

# Configuração base para plugar o Ollama
sudo -u "$USER" mkdir -p "$HOME/.config/ai-memory" "$HOME/.local/share/ai-memory"
if [ ! -f "$HOME/.config/ai-memory/config.toml" ]; then
    sudo -u "$USER" ai-memory --data-dir "$HOME/.local/share/ai-memory" --config "$HOME/.config/ai-memory/config.toml" init
    sudo -u "$USER" sed -i 's/^provider = .*/provider = "openai-compat"/g' "$HOME/.config/ai-memory/config.toml"
    sudo -u "$USER" sed -i 's/^# base_url = .*/base_url = "http:\/\/127.0.0.1:11434\/v1"/g' "$HOME/.config/ai-memory/config.toml"
    sudo -u "$USER" sed -i 's/^model = .*/model = "qwen2.5-coder:32b"/g' "$HOME/.config/ai-memory/config.toml"
    sudo -u "$USER" sed -i 's/^# timeout_secs = .*/timeout_secs = 600/g' "$HOME/.config/ai-memory/config.toml"
    sudo -u "$USER" sed -i 's/^max_input_tokens = .*/max_input_tokens = 6500/g' "$HOME/.config/ai-memory/config.toml"
    sudo -u "$USER" sed -i 's/^max_output_tokens = .*/max_output_tokens = 1000/g' "$HOME/.config/ai-memory/config.toml"
    sudo -u "$USER" systemctl --user restart ai-memory.service 2>/dev/null || true
fi

cat <<EOF

$(msg "Feito.")
  • Reinicie (ou 'systemctl start sddm') e escolha a sessão Hyprland.
  • Notebook híbrido: ajuste o PCI da GPU em ~/dotfiles/common/uwsm/env-hyprland
    (ver README do hyprdots) e faça logout/login.
  • Dia a dia, nos dois PCs:  sudo pacman -Syu
EOF
