#!/bin/bash

### https://raw.githubusercontent.com/XelK/arch/master/arch_install.sh
### https://git.io/JeVmL

### ask user info ###
echo "You current disks: " && lsblk -lsf
read -r -p "disk to use: " disk
#read -r -p "password for disk crypt :" crypt_psw
read -r -p "root password :" root_psw
read -r -p "hostname :" hostname
read -r -p "username :" user
read -r -p "username password:" user_psw
disk="/dev/${disk}"
#echo "${crypt_psw}" > crypted_psw

### creat partitions, create crypted volumes, format ###
parted "${disk}" mklabel gpt 
parted -a opt "${disk}" mkpart primary 1MiB 1G  set 1 esp on 
parted -a opt "${disk}" mkpart primary 1G 100%
cryptsetup -q --label cryptedPartition luksFormat "${disk}2" #crypted_psw
cryptsetup open "${disk}2" cryptlvm 
pvcreate /dev/mapper/cryptlvm
vgcreate lvmGroup /dev/mapper/cryptlvm
lvcreate -l 20%FREE lvmGroup -n lvRoot
lvcreate -l 100%FREE lvmGroup -n lvHome
mkfs.ext4 /dev/lvmGroup/lvRoot -L root
mkfs.ext4 /dev/lvmGroup/lvHome -L home
mkfs.fat -F32 "${disk}1" -n boot
mount /dev/lvmGroup/lvRoot /mnt
mkdir /mnt/{home,boot}
mount /dev/lvmGroup/lvHome /mnt/home
mount "${disk}1" /mnt/boot

### install system packages ###
pacstrap /mnt base linux linux-firmware lvm2 vim iproute2 netctl ifplugd dhcpcd dialog wpa_supplicant xorg-server xorg-xinit i3 ttf-dejavu dmenu sudo rxvt-unicode tmux git

### configure fstab ###
genfstab -L /mnt >> /mnt/etc/fstab

### configure system into chroot ###
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
arch-chroot /mnt hwclock --systohc
echo "
en_US.UTF-8 UTF-8  
it_IT.UTF-8 UTF-8  
" >> /mnt/etc/locale.gen
arch-chroot /mnt  locale-gen
echo "${hostname}" > /mnt/etc/hostname
echo "
127.0.0.1	localhost
::1		    localhost
127.0.1.1	${hostname}.localdomain ${hostname}
" > /mnt/etc/hosts
echo " 
KEYMAP=it
KEYMAP_TOGGLE=us
FONT=eurlatgr
" > /mnt/etc/vconsole.conf
echo
'
Section "InputClass"
    Identifier          "Keyboard Defaults"
    MatchIsKeyboard     "yes"
    Option "XkbLayout"  "it,us"
    Option "XkbVariant" ",intl"
    Option "XkbOptions" "grp:ctrl_alt_toggle"
EndSection
' > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf

sed  -i -e 's/^HOOKS.*/HOOKS=\(base udev autodetect keymap consolefont modconf block encrypt lvm2 filesystems keyboard fsck\)/g' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P
arch-chroot /mnt bootctl --path=/boot install
echo "
default  arch
timeout  0
console-mode max
editor   no
" > /mnt/boot/loader/loader.conf 
echo "
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options cryptdevice=LABEL=cryptedPartition:cryptlvm root=LABEL=root rw
" > /mnt/boot/loader/entries/arch.conf

### user configuration ###
arch-chroot /mnt groupadd sudo
arch-chroot /mnt useradd -m -G sudo,video,audio -s /bin/bash "${user}"
sed  -i -e 's/^# %sudo.*/%sudo ALL=(ALL) ALL/g' /mnt/etc/sudoers

echo "${user}:${user_psw}" | chpasswd --root /mnt
echo "root:${root_psw}" | chpasswd --root /mnt
echo "
#! /bin/bash
exec i3
" > /mnt/home/"${user}"/.xinitrc

### configure network via cable ###
echo "You current network interfaces: " && ip link show
read -r -p "ethernet interface to use: " eth_int
echo "
Description='A basic dhcp ethernet connection'
Interface=${eth_int}
Connection=ethernet
IP=dhcp
DHCPClient=dhcpcd
DHCPReleaseOnStop=no
## for DHCPv6
IP6=dhcp
DHCP6Client=dhclient
# for IPv6 autoconfiguration
IP6=stateless
" > /mnt/etc/netctl/ethernet-dhcp
arch-chroot /mnt systemctl enable netctl-ifplugd@"${eth_int}".service




#### end
umount /mnt/home
umount /mnt/boot
umount /mnt
echo "Installation completed!"
