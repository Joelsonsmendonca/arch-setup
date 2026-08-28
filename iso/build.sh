#!/usr/bin/env bash
# Monta um profile do archiso a partir do 'releng' oficial + as customizações
# deste repo, e gera a ISO em ./out/
set -euxo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="${WORK:-/tmp/archiso-work}"
OUT="${OUT:-$ROOT/out}"
PROFILE="$(mktemp -d)/profile"

REPO_URL='https://joelsonsmendonca.github.io/arch-setup/$arch'

cp -r /usr/share/archiso/configs/releng "$PROFILE"

# 1. repositório pessoal — vale para o pacstrap do build E fica no /etc/pacman.conf
#    do sistema live (o mkarchiso copia esse pacman.conf para dentro da imagem).
cat >> "$PROFILE/pacman.conf" <<EOF

[joelson]
SigLevel = Required
Server = $REPO_URL
EOF

# 2. pacotes extras dentro da ISO
if [ -s "$HERE/packages.extra.x86_64" ]; then
  grep -vE '^\s*#|^\s*$' "$HERE/packages.extra.x86_64" >> "$PROFILE/packages.x86_64"
fi

# 3. overlay do airootfs (scripts de reinstalação etc.)
if [ -d "$HERE/airootfs" ]; then
  cp -rT "$HERE/airootfs" "$PROFILE/airootfs"
fi

# 4. chave pública + KEYID dentro da ISO, para o reinstall.sh confiar no repo
install -Dm644 "$ROOT/repo/joelson-repo.gpg" "$PROFILE/airootfs/root/joelson-repo.gpg"
install -Dm644 "$ROOT/repo/KEYID"            "$PROFILE/airootfs/root/KEYID"
chmod +x "$PROFILE/airootfs/root/reinstall.sh" 2>/dev/null || true

mkdir -p "$OUT"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"
