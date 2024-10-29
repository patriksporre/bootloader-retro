# File paths
BOOTLOADER="boot.bin"
APPLICATION="application-rm.bin"
FLOPPY_IMAGE="floppy.img"

# Clean up previous builds
echo "Removing old build files..."
rm -f "$FLOPPY_IMAGE" "$BOOTLOADER" "$APPLICATION"

# Assemble bootloader and application
echo "Assembling bootloader and application..."
nasm -f bin boot.asm -o "$BOOTLOADER" || { echo "Bootloader assembly failed"; exit 1; }
nasm -f bin application-rm.asm -o "$APPLICATION" || { echo "Application assembly failed"; exit 1; }

# Create a blank 1.44 MB floppy disk image (2880 sectors)
dd if=/dev/zero of="$FLOPPY_IMAGE" bs=512 count=2880

# Write the bootloader to the first sector (sector 0) of the floppy image
dd if="$BOOTLOADER" of="$FLOPPY_IMAGE" conv=notrunc

# Write the packed application to the second sector (sector 1) of the floppy image
dd if="$APPLICATION" of="$FLOPPY_IMAGE" bs=512 seek=1 conv=notrunc

# Run the floppy disk image in QEMU
echo "Running the floppy image in QEMU..."
qemu-system-x86_64 -drive file="$FLOPPY_IMAGE",format=raw,if=floppy,index=0 -boot a