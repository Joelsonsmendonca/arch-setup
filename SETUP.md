# Setup

## A) Uma vez, no GitHub (já feito pelo script de criação, aqui pra referência)

1. Repo público `arch-setup` criado.
2. Secret **`GPG_PRIVATE_KEY`** = chave privada de assinatura (armored).
3. Pages: *Settings → Pages → Source = GitHub Actions*.
4. Rodar o workflow **repo** uma vez (push já dispara).

Confirme que ficou no ar:
```bash
curl -sI https://www.joelsonmendonca.com/arch-setup/x86_64/joelson.db | head -1
```

## B) Em cada máquina já instalada (PC e notebook)

```bash
# 1. confiar na chave do repo
curl -O https://www.joelsonmendonca.com/arch-setup/joelson-repo.gpg
KEYID=$(curl -s https://www.joelsonmendonca.com/arch-setup/KEYID)
sudo pacman-key --add joelson-repo.gpg
sudo pacman-key --lsign-key "$KEYID"

# 2. adicionar o repo ao /etc/pacman.conf (no fim do arquivo)
sudo tee -a /etc/pacman.conf <<'EOF'

[joelson]
SigLevel = Required
Server = https://www.joelsonmendonca.com/arch-setup/$arch
EOF

# 3. habilitar [multilib] (necessário pro steam) — descomente as 2 linhas:
sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

# 4. instalar o conjunto todo
sudo pacman -Syu joelson-base joelson-nvidia   # notebook/PC com NVIDIA
# sudo pacman -Syu joelson-base                # máquina sem NVIDIA
```

A partir daí, **`pacman` já vai remover** o que sair do meta-pacote? Não —
pacotes ficam como dependência. Para limpar órfãos quando você tirar algo da
lista: `sudo pacman -Qdtq | sudo pacman -Rns -`.

## C) Atualização automática (opcional, "Windows Update")

```bash
sudo tee /etc/systemd/system/joelson-update.service <<'EOF'
[Unit]
Description=Atualiza o sistema (repos oficiais + repo joelson)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman -Syu --noconfirm
EOF

sudo tee /etc/systemd/system/joelson-update.timer <<'EOF'
[Unit]
Description=Atualização diária

[Timer]
OnCalendar=*-*-* 12:00:00
Persistent=true
RandomizedDelaySec=2h

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable --now joelson-update.timer
```

> Cuidado: updates 100% sem supervisão no Arch às vezes exigem intervenção
> (aviso no [arch-news](https://archlinux.org/news/), troca de pacote). Considere
> instalar `informant` (trava o update se houver notícia não lida) e ter
> `snapper` + snapshots Btrfs pra reverter.

## D) Reinstalar do zero (ISO)

1. Baixe a ISO em *Releases → latest*, grave num pendrive
   (`dd bs=4M if=arch-*.iso of=/dev/sdX status=progress oflag=sync`).
2. Boot, conecte a internet (`iwctl`), particione/monte o disco em `/mnt`.
3. `bash /root/reinstall.sh` — instala `base` + `joelson-base` do repo.
4. Finalize (usuário, locale, bootloader — o script lista os comandos) e clone
   os [dotfiles](https://github.com/Joelsonsmendonca/hyprdots).
