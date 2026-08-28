# Instalar do zero numa máquina sem sistema

## 1. Pegar a ISO (em outro PC)

Baixe os dois arquivos da release **`latest`**:
<https://github.com/Joelsonsmendonca/arch-setup/releases/latest>

```bash
cd ~/Downloads
curl -LO https://github.com/Joelsonsmendonca/arch-setup/releases/latest/download/archlinux-2026.08.28-x86_64.iso
curl -LO https://github.com/Joelsonsmendonca/arch-setup/releases/latest/download/archlinux-2026.08.28-x86_64.iso.sha256
sha256sum -c archlinux-2026.08.28-x86_64.iso.sha256      # tem que dizer "OK"
```
> O nome do arquivo muda a cada build (tem a data). Confira na página da release.

## 2. Gravar no pendrive

Descubra o device do pendrive (`lsblk`) — **cuidado, apaga tudo nele**:

```bash
# Linux
sudo dd bs=4M if=archlinux-*.iso of=/dev/sdX status=progress oflag=sync
```
No Windows/macOS: use [Rufus](https://rufus.ie) (modo "DD Image") ou
[balenaEtcher](https://etcher.balena.io).

## 3. Bootar a máquina nova

1. BIOS/UEFI → **desabilite Secure Boot**, habilite boot USB.
2. Boot pelo pendrive → escolha "Arch Linux install medium".
3. Cai num shell `root@archiso`.

## 4. Internet

```bash
# cabo: já deve funcionar. Testa:
ping -c2 archlinux.org

# wifi:
iwctl
    station wlan0 scan
    station wlan0 get-networks
    station wlan0 connect "NOME_DA_REDE"
    exit
```

## 5. Particionar o disco  ⚠️ destrutivo

Identifique o disco: `lsblk` (SSD SATA = `/dev/sda`, NVMe = `/dev/nvme0n1`).
Abaixo assumindo NVMe e **UEFI** — ajuste o nome:

```bash
DISK=/dev/nvme0n1        # <<< confira!
P=/dev/nvme0n1           # prefixo das partições (SATA seria /dev/sda e P=/dev/sda)
PART() { case "$DISK" in *nvme*|*mmcblk*) echo "${P}p$1";; *) echo "${P}$1";; esac; }

sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1G   -t1:ef00 -c1:EFI  "$DISK"
sgdisk -n2:0:0     -t2:8300 -c2:root "$DISK"

mkfs.fat -F32 "$(PART 1)"
mkfs.btrfs -f  "$(PART 2)"
```

Subvolumes btrfs (pra funcionar com snapper):

```bash
mount "$(PART 2)" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
umount /mnt

O="noatime,compress=zstd,ssd"
mount -o "$O,subvol=@"          "$(PART 2)" /mnt
mkdir -p /mnt/{home,boot,.snapshots}
mount -o "$O,subvol=@home"      "$(PART 2)" /mnt/home
mount -o "$O,subvol=@snapshots" "$(PART 2)" /mnt/.snapshots
mount "$(PART 1)" /mnt/boot
```

## 6. Rodar o instalador

```bash
bash /root/reinstall.sh
```

Ele: confia na chave do repo `[joelson]`, faz `pacstrap` de `base linux
linux-firmware` + `<ucode>` + `joelson-base` (+ `joelson-nvidia` se você disser
que tem NVIDIA), gera o `fstab`, configura o keyring dentro do sistema e habilita
NetworkManager/sddm/bluetooth/firewalld.

## 7. Finalizar (o que o script não faz)

```bash
arch-chroot /mnt

# fuso / relógio
ln -sf /usr/share/zoneinfo/America/Recife /etc/localtime
hwclock --systohc

# locale
sed -i 's/#pt_BR.UTF-8/pt_BR.UTF-8/; s/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=pt_BR.UTF-8' > /etc/locale.conf
echo 'KEYMAP=br-abnt2'  > /etc/vconsole.conf

# hostname (use nomes diferentes no PC e no notebook)
echo 'legion' > /etc/hostname

# senha do root + seu usuário
passwd
useradd -mG wheel joelson
passwd joelson
EDITOR=nano visudo        # descomente:  %wheel ALL=(ALL:ALL) ALL

# initramfs (btrfs já está coberto pelo hook 'filesystems')
mkinitcpio -P

# bootloader (systemd-boot)
bootctl install
ROOTUUID=$(findmnt -no UUID -T /)
UCODE=amd-ucode           # ou intel-ucode
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
EOF
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /$UCODE.img
initrd  /initramfs-linux.img
options root=UUID=$ROOTUUID rootflags=subvol=@ rw
EOF

exit
```

## 8. Reboot e primeiro login

```bash
umount -R /mnt
reboot            # tire o pendrive
```

Loga no seu usuário (tty ou sddm), conecta na rede (`nmtui`), e:

```bash
# dotfiles
git clone https://github.com/Joelsonsmendonca/hyprdots.git ~/dotfiles
# siga o README do hyprdots pra criar os symlinks ~/.config/<app>

# o repo [joelson] já está no /etc/pacman.conf (veio na ISO). Daqui pra frente:
sudo pacman -Syu
```

Pronto — essa máquina agora está no mesmo trilho que a outra: `pacman -Syu`
mantém as duas iguais.
