# Instalar do zero numa máquina sem sistema

Fluxo em 2 fases: **archinstall** (instalador guiado oficial do Arch — particiona
o disco no menu) e depois **um comando** que instala os apps e os dotfiles.

## Fase 0 — pegar a ISO (noutro PC)

Release **`latest`**: <https://github.com/Joelsonsmendonca/arch-setup/releases/latest>

```bash
cd ~/Downloads
ISO=$(curl -s https://api.github.com/repos/Joelsonsmendonca/arch-setup/releases/latest \
      | grep -oP '"name": "\K[^"]+\.iso')
curl -LO "https://github.com/Joelsonsmendonca/arch-setup/releases/latest/download/$ISO"
curl -LO "https://github.com/Joelsonsmendonca/arch-setup/releases/latest/download/$ISO.sha256"
sha256sum -c "$ISO.sha256"          # tem que dizer: OK
```

Gravar no pendrive (apaga o pendrive — confira o device com `lsblk`):

```bash
sudo dd bs=4M if="$ISO" of=/dev/sdX status=progress oflag=sync
```
Windows/macOS: [Rufus](https://rufus.ie) (modo *DD Image*) ou [balenaEtcher](https://etcher.balena.io).

## Fase 1 — instalar (na máquina nova, bootando o pendrive)

BIOS/UEFI: **Secure Boot OFF**, habilitar boot USB. Bootar → "Arch Linux install medium".

```bash
# internet
ping -c2 archlinux.org               # cabo já funciona
iwctl station wlan0 connect "SUA_REDE"   # wifi

# instalador
bash /root/install.sh
```

Isso abre o **archinstall** já com locale pt_BR, teclado br-abnt2, timezone,
systemd-boot, NetworkManager e swap (zram) preenchidos. No menu, configure só o
que é por-máquina:

| Item | O que fazer |
| --- | --- |
| **Disk configuration** | "Use a best-effort default partition layout" → escolher o disco → filesystem **btrfs** (aceitar os subvolumes) |
| **Hostname** | nome desta máquina — **diferente** do outro PC (ex.: `legion`, `desktop`) |
| **Root password** | definir |
| **User account** | criar seu usuário e marcar **"superuser (sudo)"** |

Depois: **Install** → confirmar → ao terminar, **reboot** (tire o pendrive).

## Fase 2 — apps + dotfiles (no primeiro boot)

Loga no console com o usuário que você criou e roda **uma linha**:

```bash
curl -fsSL https://raw.githubusercontent.com/Joelsonsmendonca/arch-setup/main/postinstall.sh | bash
```

Ele: adiciona multilib no `pacman.conf`, instala a interface Hyprland, fontes,
ícones e ferramentas essenciais, habilita SDDM/Bluetooth/firewalld/docker e monta os symlinks dos
[dotfiles](https://github.com/Joelsonsmendonca/hyprdots) em `~/.config`.

```bash
reboot        # cai no SDDM → sessão Hyprland
```

> Notebook híbrido AMD+NVIDIA: ajuste o endereço PCI da GPU em
> `~/dotfiles/common/uwsm/env-hyprland` (ver README do hyprdots) e faça logout/login.

## Pronto

Essa máquina agora está no mesmo trilho da outra:

```bash
sudo pacman -Syu        # mantém PC e notebook idênticos
```

---

### Se o archinstall falhar / preferir na mão

Particionamento manual (UEFI, btrfs) e `pacstrap` estão no histórico do git em
`iso/airootfs/root/reinstall.sh` (removido), ou siga o
[Installation guide](https://wiki.archlinux.org/title/Installation_guide) do Wiki
e no final rode a **Fase 2** acima.
