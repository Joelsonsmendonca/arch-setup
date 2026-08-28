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
APPS=(hypr kitty rofi waybar wofi fuzzel uwsm pipewire swaync)

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
pkgs=(joelson-base)
if lspci 2>/dev/null | grep -Eqi 'vga.*nvidia|3d.*nvidia'; then
  pkgs+=(joelson-nvidia); msg "  GPU NVIDIA detectada -> joelson-nvidia"
fi
sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"

msg "Habilitando serviços"
sudo systemctl enable --now NetworkManager
sudo systemctl enable sddm bluetooth firewalld

msg "Dotfiles (hyprdots)"
[[ -d "$HOME/dotfiles" ]] || git clone "$DOTFILES_GIT" "$HOME/dotfiles"
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.config/systemd/user"
for app in "${APPS[@]}"; do
  if [[ -e "$HOME/.config/$app" && ! -L "$HOME/.config/$app" ]]; then
    mv "$HOME/.config/$app" "$HOME/.config/$app.bak.$(date +%s)"
  fi
  ln -sfn "$HOME/dotfiles/common/$app" "$HOME/.config/$app"
done
ln -sfn "$HOME/dotfiles/common/systemd/user/app-nm\x2dapplet@autostart.service.d" \
        "$HOME/.config/systemd/user/app-nm\x2dapplet@autostart.service.d" 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true
[[ -e "$HOME/.config/hypr/scripts/nvidia-offload.sh" ]] && \
  ln -sfn "$HOME/.config/hypr/scripts/nvidia-offload.sh" "$HOME/.local/bin/nvidia-offload"

cat <<EOF

$(msg "Feito.")
  • Reinicie (ou 'systemctl start sddm') e escolha a sessão Hyprland.
  • Notebook híbrido: ajuste o PCI da GPU em ~/dotfiles/common/uwsm/env-hyprland
    (ver README do hyprdots) e faça logout/login.
  • Dia a dia, nos dois PCs:  sudo pacman -Syu
EOF
