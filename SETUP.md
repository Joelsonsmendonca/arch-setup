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

Um comando faz tudo (confia na chave, adiciona o repo + multilib, instala
`joelson-base` (+ `joelson-nvidia` se houver NVIDIA), liga serviços, monta dotfiles):

```bash
curl -fsSL https://raw.githubusercontent.com/Joelsonsmendonca/arch-setup/main/postinstall.sh | bash
```

<details><summary>o que ele faz, na mão</summary>

```bash
curl -O https://www.joelsonmendonca.com/arch-setup/joelson-repo.gpg
KEYID=$(curl -s https://www.joelsonmendonca.com/arch-setup/KEYID)
sudo pacman-key --add joelson-repo.gpg
sudo pacman-key --lsign-key "$KEYID"

sudo tee -a /etc/pacman.conf <<'EOF'

[joelson]
SigLevel = Required
Server = https://www.joelsonmendonca.com/arch-setup/$arch
EOF

sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf   # steam
sudo pacman -Syu joelson-base joelson-nvidia
```
</details>

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

Ver [`INSTALL.md`](INSTALL.md). Resumo: grava a ISO num pendrive, boota,
`bash /root/install.sh` (abre o **archinstall** já configurado — só escolhe disco,
hostname e senhas), e no primeiro boot roda o comando da seção B.
