#!/usr/bin/env bash
# Abre o archinstall (instalador guiado do Arch) já com os padrões do Joelson.
set -e

cat <<'EOF'

============================================================
  Instalador do desktop do Joelson
============================================================

Vai abrir o archinstall. No menu, configure só o que é por-máquina:

  • Disk configuration
        -> "Use a best-effort default partition layout"
        -> escolha o disco alvo
        -> filesystem: btrfs   (aceite os subvolumes)
  • Hostname        -> nome DESTA maquina (diferente do outro PC!)
  • Root password   -> defina
  • User account    -> crie seu usuario e marque "superuser (sudo)"

Ja vem pronto: locale pt_BR, teclado br-abnt2, timezone, systemd-boot,
NetworkManager, swap (zram), kernel linux.

Depois selecione  ->  Install  <-  e no fim reinicie.

  >>> NO PRIMEIRO BOOT, logue no console e rode UMA linha:

      curl -fsSL https://raw.githubusercontent.com/Joelsonsmendonca/arch-setup/main/postinstall.sh | bash

  (instala todos os apps, liga o SDDM/Hyprland e monta os dotfiles)

============================================================

EOF

read -rp "Enter para abrir o archinstall (Ctrl+C cancela)... " _
exec archinstall --config /root/joelson.json
