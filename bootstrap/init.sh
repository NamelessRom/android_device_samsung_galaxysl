#!/stage1/busybox sh
export PATH=/stage1

busybox cd /
busybox rm init
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys

RAMDISK=ramdisk.img

if busybox grep -q bootmode=2 /proc/cmdline ; then
	# recovery boot
    RAMDISK=ramdisk-recovery.img
fi

busybox gunzip -c ${RAMDISK} | busybox cpio -i

busybox umount /sys
busybox umount /proc

busybox rm -fr /stage1 /dev/*
busybox rm ramdisk.cpio.gz
busybox rm ramdisk-recovery.cpio.gz

exec /init
