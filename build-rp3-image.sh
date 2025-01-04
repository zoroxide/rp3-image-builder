#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define variables for paths and tools
WORKDIR="$HOME/rpi-linux-build"
KERNEL_REPO="https://github.com/raspberrypi/linux.git"
FIRMWARE_REPO="https://github.com/raspberrypi/firmware.git"
CROSS_COMPILER="arm-linux-gnueabihf-"

# Ensure the script is run with sudo privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Step 1: Prepare the workspace
echo "Setting up workspace at $WORKDIR..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Step 2: Clone the Linux kernel source
echo "Cloning the Raspberry Pi Linux kernel repository..."
git clone --depth=1 "$KERNEL_REPO" linux
cd linux

# Step 3: Configure and build the kernel
echo "Configuring the kernel for Raspberry Pi 3..."
make ARCH=arm CROSS_COMPILE="$CROSS_COMPILER" bcm2709_defconfig

echo "Building the kernel..."
make ARCH=arm CROSS_COMPILE="$CROSS_COMPILER" -j$(nproc)

# Step 4: Build kernel modules
echo "Installing kernel modules..."
make ARCH=arm CROSS_COMPILE="$CROSS_COMPILER" modules_install INSTALL_MOD_PATH="$WORKDIR/modules"

# Step 5: Create a root filesystem
echo "Creating root filesystem..."
cd "$WORKDIR"
mkdir -p rootfs/{bin,dev,etc,home,lib,proc,root,sbin,sys,tmp,usr,var}

# Download and build BusyBox for the root filesystem
echo "Downloading and building BusyBox..."
wget https://busybox.net/downloads/busybox-1.36.0.tar.bz2 -O busybox.tar.bz2
tar -xjf busybox.tar.bz2
cd busybox-*
make defconfig
make CROSS_COMPILE="$CROSS_COMPILER" install CONFIG_PREFIX="$WORKDIR/rootfs"

# Step 6: Clone the Raspberry Pi firmware
echo "Cloning Raspberry Pi firmware..."
cd "$WORKDIR"
git clone --depth=1 "$FIRMWARE_REPO" firmware

# Step 7: Set up the bootloader files
echo "Setting up bootloader files..."
mkdir -p boot
cp firmware/boot/* boot/
cp linux/arch/arm/boot/zImage boot/
cp linux/arch/arm/boot/dts/*.dtb boot/

# Step 8: Format and partition the SD card
SD_CARD="/dev/sdX"  # Replace with your SD card device
echo "Formatting and partitioning the SD card..."
read -p "Enter your SD card device (e.g., /dev/sdX): " SD_CARD

if [ ! -b "$SD_CARD" ]; then
    echo "Invalid SD card device. Exiting."
    exit 1
fi

echo "Creating partitions on $SD_CARD..."
parted -s "$SD_CARD" mklabel msdos
parted -s "$SD_CARD" mkpart primary fat32 1MiB 256MiB
parted -s "$SD_CARD" mkpart primary ext4 256MiB 100%

# Format the partitions
echo "Formatting partitions..."
mkfs.vfat "${SD_CARD}1"
mkfs.ext4 "${SD_CARD}2"

# Mount the partitions
echo "Mounting partitions..."
mkdir -p /mnt/{boot,rootfs}
mount "${SD_CARD}1" /mnt/boot
mount "${SD_CARD}2" /mnt/rootfs

# Step 9: Copy files to the SD card
echo "Copying bootloader files..."
cp -r boot/* /mnt/boot/

echo "Copying root filesystem..."
cp -r rootfs/* /mnt/rootfs/

# Step 10: Configure bootloader
echo "Configuring bootloader..."
cat <<EOF > /mnt/boot/config.txt
kernel=zImage
gpu_mem=16
EOF

cat <<EOF > /mnt/boot/cmdline.txt
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 fsck.repair=yes rootwait
EOF

# Step 11: Unmount the SD card
echo "Unmounting SD card partitions..."
umount /mnt/boot
umount /mnt/rootfs

echo "Done! Insert the SD card into your Raspberry Pi and boot it up."

