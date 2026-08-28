#!/usr/bin/env bash
# Monta um profile do archiso a partir do 'releng' oficial + as customizações
# deste repo, e gera a ISO em ./out/
set -euxo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="${WORK:-/tmp/archiso-work}"
OUT="${OUT:-$ROOT/out}"
PROFILE="$(mktemp -d)/profile"

REPO_URL='https://www.joelsonmendonca.com/arch-setup/$arch'

cp -r /usr/share/archiso/configs/releng "$PROFILE"

# 1a. habilita [multilib] (joelson-base depende de steam) — no pacman.conf do
#     build E no que vai pra imagem (usado depois pelo reinstall.sh).
if ! grep -q '^\[multilib\]' "$PROFILE/pacman.conf"; then
  if grep -q '^#\[multilib\]' "$PROFILE/pacman.conf"; then
    sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' "$PROFILE/pacman.conf"
  else
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$PROFILE/pacman.conf"
  fi
fi

# 1b. repositório pessoal — vale para o pacstrap do build E fica no /etc/pacman.conf
#     do sistema live (o mkarchiso copia esse pacman.conf para dentro da imagem).
cat >> "$PROFILE/pacman.conf" <<EOF

[joelson]
SigLevel = Required
Server = $REPO_URL
EOF

# 2. pacotes extras dentro da ISO
if [ -s "$HERE/packages.extra.x86_64" ]; then
  grep -vE '^\s*#|^\s*$' "$HERE/packages.extra.x86_64" >> "$PROFILE/packages.x86_64"
fi

# 3. overlay do airootfs (wrapper do archinstall + config)
if [ -d "$HERE/airootfs" ]; then
  cp -rT "$HERE/airootfs" "$PROFILE/airootfs"
fi

# 4. artefatos do repo dentro da ISO (chave/KEYID pra offline, postinstall como fallback)
install -Dm644 "$ROOT/repo/joelson-repo.gpg" "$PROFILE/airootfs/root/joelson-repo.gpg"
install -Dm644 "$ROOT/repo/KEYID"            "$PROFILE/airootfs/root/KEYID"
install -Dm755 "$ROOT/postinstall.sh"        "$PROFILE/airootfs/root/postinstall.sh"
chmod +x "$PROFILE/airootfs/root/install.sh" 2>/dev/null || true

mkdir -p "$OUT"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"
