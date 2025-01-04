#!/bin/bash
set -e

# Workspace setup
WORKDIR="$HOME/x86-linux-build"
KERNEL_VERSION="6.5"

# Prerequisites
sudo apt update
sudo apt install -y build-essential libncurses-dev bison flex libssl-dev qemu-system-x86 busybox-static wget cpio

# Create workspace
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Step 1: Download Linux kernel
echo "Downloading Linux kernel version $KERNEL_VERSION..."
wget "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz"
tar -xf "linux-$KERNEL_VERSION.tar.xz"
cd "linux-$KERNEL_VERSION"

# Step 2: Configure and build the kernel
echo "Configuring and building the kernel..."
make defconfig
make menuconfig  # Optionally adjust settings
make -j$(nproc)

# Step 3: Create minimal root filesystem
echo "Creating root filesystem..."
cd "$WORKDIR"
mkdir -p rootfs/{bin,sbin,etc,proc,sys,usr,var,tmp}
chmod 777 rootfs/tmp
cp /bin/busybox rootfs/bin/
cd rootfs/bin
for cmd in $(./busybox --list); do
    ln -s busybox $cmd
done
cd "$WORKDIR"

# Step 4: Add an init script
echo "Creating init script..."
cat <<EOF > rootfs/init
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
echo "Welcome to minimal Linux on QEMU!"
/bin/sh
EOF
chmod +x rootfs/init

# Step 5: Create compressed CPIO archive for initramfs
echo "Creating compressed CPIO archive for initramfs..."
cd rootfs
find . | cpio -o --format=newc | gzip > ../rootfs.cpio.gz
cd "$WORKDIR"

# Step 6: Display output files
echo "Build complete. Output files are located in $WORKDIR:"
echo "- Kernel: $WORKDIR/linux-$KERNEL_VERSION/arch/x86/boot/bzImage"
echo "- Initramfs: $WORKDIR/rootfs.cpio.gz"
