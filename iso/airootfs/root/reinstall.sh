#!/usr/bin/env bash
# Reinstala o desktop do Joelson usando o repo pessoal.
#
# Este script NÃO particiona disco (isso é destrutivo — faça manualmente).
# Fluxo:
#   1. particione e formate o disco alvo (cfdisk / gdisk / mkfs...)
#   2. monte a raiz em /mnt e a partição EFI em /mnt/boot
#   3. rode:  bash /root/reinstall.sh
set -euo pipefail

KEYID="$(cat /root/KEYID 2>/dev/null || echo ACE46508480D9540)"

if ! mountpoint -q /mnt; then
  echo "ERRO: monte a raiz em /mnt (e a EFI em /mnt/boot) antes de rodar." >&2
  exit 1
fi

echo ">> Confiando na chave do repo pessoal no ambiente live..."
pacman-key --add /root/joelson-repo.gpg
pacman-key --lsign-key "$KEYID"
pacman -Sy

read -rp "GPU NVIDIA nesta máquina? Instalar joelson-nvidia? [s/N] " nv
EXTRA=""
[[ "${nv,,}" == "s" ]] && EXTRA="joelson-nvidia"

read -rp "CPU: (a)md ou (i)ntel? " cpu
case "${cpu,,}" in
  a*) UCODE="amd-ucode" ;;
  i*) UCODE="intel-ucode" ;;
  *)  UCODE="" ;;
esac

echo ">> pacstrap..."
pacstrap -K /mnt \
  base linux linux-firmware $UCODE \
  joelson-base $EXTRA

genfstab -U /mnt >> /mnt/etc/fstab

echo ">> Configurando repo + keyring dentro do sistema instalado..."
install -Dm644 /root/joelson-repo.gpg /mnt/root/joelson-repo.gpg
cp /etc/pacman.conf /mnt/etc/pacman.conf   # já tem o bloco [joelson]
arch-chroot /mnt bash -c "
  pacman-key --init &&
  pacman-key --populate archlinux &&
  pacman-key --add /root/joelson-repo.gpg &&
  pacman-key --lsign-key $KEYID
"

echo ">> Habilitando serviços..."
arch-chroot /mnt systemctl enable NetworkManager sddm bluetooth firewalld

cat <<'EOF'

============================================================
Base instalada. Falta fazer (arch-chroot /mnt):

  ln -sf /usr/share/zoneinfo/America/Recife /etc/localtime && hwclock --systohc
  sed -i 's/#pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen && locale-gen
  echo LANG=pt_BR.UTF-8 > /etc/locale.conf
  echo minha-maquina > /etc/hostname
  passwd
  useradd -mG wheel joelson && passwd joelson
  EDITOR=vim visudo            # libera %wheel
  bootctl install              # (ou grub-install)  -> configure o entry

Dotfiles:
  git clone https://github.com/Joelsonsmendonca/hyprdots.git ~/dotfiles
  # siga o README (symlinks ~/.config/<app> -> ~/dotfiles/common/<app>)

Depois é só:  sudo pacman -Syu   (sincroniza com o outro PC)
============================================================
EOF
