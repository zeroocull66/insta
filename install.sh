#!/bin/bash

# Verificar si se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root"
  exit
fi

# Variables de configuración
DISK="/dev/sda" # Cambia "sdX" por tu disco, como /dev/sda o /dev/nvme0n1
HOSTNAME="archlinux"
USERNAME="zeroocull666"
PASSWORD="123"

# Configuración regional
LOCALE="es_AR.UTF-8"
KEYMAP="es"

# Particionar el disco
echo "Particionando el disco..."
sgdisk -o $DISK
sgdisk -n 1:0:+1G -t 1:8200 $DISK     # Crear partición de SWAP de 1G
sgdisk -n 2:0:+2G -t 2:8300 $DISK     # Crear partición de BOOT de 2G
sgdisk -n 3:0:0 -t 3:8304 $DISK       # Crear partición de ROOT con el resto del espacio

# Formatear las particiones
echo "Formateando particiones..."
mkswap "${DISK}1"
mkfs.ext4 "${DISK}2" -L BOOT
mkfs.ext4 "${DISK}3" -L ROOT

# Activar SWAP
swapon "${DISK}1"

# Montar particiones
echo "Montando particiones..."
mount "${DISK}3" /mnt
mkdir -p /mnt/boot
mount "${DISK}2" /mnt/boot

# Instalar el sistema base
echo "Instalando sistema base..."
pacstrap /mnt base base-devel linux linux-firmware

# Generar fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot al sistema
arch-chroot /mnt /bin/bash <<EOF

# Configuración del sistema
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Configuración de la zona horaria y localización
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Crear usuario y configurar contraseñas
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Instalar GRUB
echo "Instalando GRUB..."
pacman --noconfirm -S grub
grub-install --target=i386-pc $DISK
grub-mkconfig -o /boot/grub/grub.cfg

# Instalar entorno gráfico
echo "Instalando entorno gráfico..."
pacman --noconfirm --needed -S  xorg-server nano network-manager-applet xorg-xinit bspwm sxhkd rofi

# Configurar bspwm y rofi
echo "Configurando BSPWM y Rofi..."
mkdir -p /home/$USERNAME/.config/bspwm
mkdir -p /home/$USERNAME/.config/sxhkd
cp /usr/share/doc/bspwm/examples/bspwmrc /home/$USERNAME/.config/bspwm/
cp /usr/share/doc/bspwm/examples/sxhkdrc /home/$USERNAME/.config/sxhkd/
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

# Finalización
EOF

# Desmontar y reiniciar
echo "Instalación completada. Desmontando particiones..."
umount -R /mnt
swapoff "${DISK}1"
echo "Reinicia el sistema para iniciar Arch Linux instalado."
