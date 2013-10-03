#!/system/bin/sh

# store-mac-addr -- reads configured wifi MAC address and writes it into nvs
# file for use by the wl12xx driver

ROM_NVS=/system/etc/firmware/ti-connectivity/wl1271-nvs_127x.bin
ORIG_NVS=/data/misc/wifi/wl1271-nvs.bin.orig
NEW_NVS=/data/misc/wifi/wl1271-nvs.bin

PATH=/vendor/bin:/system/bin:/system/xbin
umask 0022

# Don't bother updating the nvs file if the one shipped in the ROM hasn't
# changed since the last boot
cmp "$ROM_NVS" "$ORIG_NVS" > /dev/null 2>&1 && exit 0

# Get the MAC address and remove the : symbols
# Use the default nvs file in case the MAC address is not found
macaddr=$(cat /efs/imei/.nvmac.info | sed 's/://g')
if [ -z $macaddr ]; then
    cp "$ROM_NVS" "$NEW_NVS";
    exit 1;
fi

# The MAC address is stored in the nvs file in two pieces: the four
# least-significant bytes in little-endian order starting at byte offset 3
# (indexed to 0), and the two most-significant bytes in little-endian order
# starting at byte offset 10.
#
# We're using printf to write these bytes to the file, so parse the MAC
# address to produce the escape sequences we'll use as arguments to printf.
lowbytes=$(echo "$macaddr" | sed -e 's#^\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)$#\\x\6\\x\5\\x\4\\x\3#')
highbytes=$(echo "$macaddr" | sed -e 's#^\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)$#\\x\2\\x\1#')

# Create the new nvs file by copying over the ROM's copy byte by byte,
# replacing only the pieces containing the MAC address
dd if="$ROM_NVS" of="$NEW_NVS" bs=1 count=3
printf "$lowbytes" >> "$NEW_NVS"
dd if="$ROM_NVS" of="$NEW_NVS" bs=1 skip=7 seek=7 count=3
printf "$highbytes" >> "$NEW_NVS"
dd if="$ROM_NVS" of="$NEW_NVS" bs=1 skip=12 seek=12

# Store the unmodified nvs file for reference
cp "$ROM_NVS" "$ORIG_NVS"

exit 0
