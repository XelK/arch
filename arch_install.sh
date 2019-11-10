#!/bin/bash

### https://raw.githubusercontent.com/XelK/arch/master/arch_install.sh


### ask user info ###
echo "You current disks: " && lsblk -lsf
read -r -p "disk to use: " disk
read -r -p "password for disk crypt :" crypt_psw
read -r -p "root password :" root_psw
read -r -p "hostname :" hostname
read -r -p "username :" user
read -r -p "username password:" user_psw
disk="/dev/${disk}"
echo "${crypt_psw}" > crypted_psw



### creat partitions, create crypted volumes, format ###
parted "${disk}" mklabel gpt 
parted -a opt "${disk}" mkpart primary 1MiB 1G  set 1 esp on 
parted -a opt "${disk}" mkpart primary 1G 100%
cryptsetup -q --label cryptedPartition luksFormat "${disk}2" crypted_psw
cryptsetup open "${disk}2" cryptlvm -d crypted_psw
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
mount "{$disk}1" /mnt/boot

### install system packages ###
pacstrap /mnt base linux linux-firmware lvm2 vim iproute2 netctl ifplugd dhcpcd dialog wpa_supplicant xorg-server xorg-xinit i3 ttf-dejavu dmenu sudo rxvt-unicode tmux 

### configure fstab ###
genfstab -L /mnt >> /mnt/etc/fstab

### configure system into chroot ###
arch-chroot /mnt echo "${root_psw}" | passwd --stdin root
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt  echo "
en_US.UTF-8 UTF-8  
it_IT.UTF-8 UTF-8  
" >> /etc/locale.gen
arch-chroot /mnt  locale-gen
arch-chroot /mnt  echo "${hostname}" > /etc/hostname
arch-chroot /mnt echo "
127.0.0.1	localhost
::1		    localhost
127.0.1.1	${hostname}.localdomain ${hostname}
" > /etc/hosts
arch-chroot /mnt echo " 
KEYMAP=it
KEYMAP_TOGGLE=us
FONT=eurlatgr
" > /etc/vconsole.conf
arch-chroot /mnt sed  -i -e 's/^HOOKS=*/HOOKS=\(base udev autodetect keymap consolefont modconf block encrypt lvm2 filesystems keyboard fsck\)/g' /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P
arch-chroot /mnt bootcl --path=/boot install
arch-chroot /mnt echo "
default  arch
timeout  0
console-mode max
editor   no
" > /boot/loader/loader.conf 
arch-chroot /mnt echo "
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
cryptdevice=LABEL=cryptePart:cryptlvm root=LABEL=root rw
" > /boot/loader/entries/arch.conf


### user configuration ###
arch-chroot /mnt groupadd sudo
arch-chroot /mnt useradd -m -G sudo,video,audio -s /bin/bash "${user}"
arch-chroot /mnt echo "${user_psw}" | passwd --stdin "${user}"
arch-chroot /mnt echo "
#! /bin/bash
exec i3
" > /home/"${user}"/.xinitrc 
