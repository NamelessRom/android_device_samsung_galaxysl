#!/tmp/busybox sh
#
# Filsystem Conversion Script for Samsung Galaxy SL
# (c) 2011 by Teamhacksung
#

check_mount() {
    if ! /tmp/busybox grep -q $1 /proc/mounts ; then
        /tmp/busybox mkdir -p $1
        /tmp/busybox umount -l $2
        if ! /tmp/busybox mount -t $3 $2 $1 ; then
            /tmp/busybox echo "Cannot mount $1."
            exit 1
        fi
    fi
}

set_log() {
    rm -rf $1
    exec >> $1 2>&1
}

# ui_print by Chainfire
OUTFD=$(/tmp/busybox ps | /tmp/busybox grep -v "grep" | /tmp/busybox grep -o -E "update_binary(.*)" | /tmp/busybox cut -d " " -f 3);
ui_print() {
  if [ $OUTFD != "" ]; then
    echo "ui_print ${1} " 1>&$OUTFD;
    echo "ui_print " 1>&$OUTFD;
  else
    echo "${1}";
  fi;
}

set -x
export PATH=/:/sbin:/system/xbin:/system/bin:/tmp:$PATH

IS_GSM='/tmp/busybox true'
SD_PART='/dev/block/mmcblk0p1'
MTD_SIZE='454557696'
EFS_PART=`/tmp/busybox grep efs /proc/mtd | /tmp/busybox awk '{print $1}' | /tmp/busybox sed 's/://g' | /tmp/busybox sed 's/mtd/mtdblock/g'`
RADIO_PART=`/tmp/busybox grep radio /proc/mtd | /tmp/busybox awk '{print $1}' | /tmp/busybox sed 's/://g' | /tmp/busybox sed 's/mtd/mtdblock/g'`

# check for old/non-cwm recovery.
if ! /tmp/busybox test -n "$UPDATE_PACKAGE" ; then
    # scrape package location from /tmp/recovery.log
    UPDATE_PACKAGE=`/tmp/busybox cat /tmp/recovery.log | /tmp/busybox grep 'Update location:' | /tmp/busybox tail -n 1 | /tmp/busybox cut -d ' ' -f 3-`
fi

# check if we're running on a bml, mtd (old) or mtd (current) device
if /tmp/busybox test -e /dev/block/bml7 ; then
    # we're running on a bml device

    # make sure sdcard is mounted
    check_mount /mnt/sdcard $SD_PART vfat

    # everything is logged into /mnt/sdcard/cyanogenmod_bml.log
    set_log /mnt/sdcard/cyanogenmod_bml.log

    if $IS_GSM ; then
        # make sure efs is mounted
        check_mount /efs /dev/block/stl3 rfs

        # create a backup of efs
        if /tmp/busybox test -e /mnt/sdcard/backup/efs ; then
            /tmp/busybox mv /mnt/sdcard/backup/efs /mnt/sdcard/backup/efs-$$
        fi
        /tmp/busybox rm -rf /mnt/sdcard/backup/efs

        /tmp/busybox mkdir -p /mnt/sdcard/backup/efs
        /tmp/busybox cp -R /efs/ /mnt/sdcard/backup
    fi

    # write the package path to sdcard cyanogenmod.cfg
    if /tmp/busybox test -n "$UPDATE_PACKAGE" ; then
        PACKAGE_LOCATION=${UPDATE_PACKAGE#/mnt}
        /tmp/busybox echo "$PACKAGE_LOCATION" > /mnt/sdcard/cyanogenmod.cfg
    fi

    # Scorch any ROM Manager settings to require the user to reflash recovery
    /tmp/busybox rm -f /mnt/sdcard/clockworkmod/.settings

    # write new kernel to boot partition
    /tmp/flash_image boot /tmp/boot.img
    if [ "$?" != "0" ] ; then
        exit 3
    fi
    /tmp/busybox sync

    /sbin/reboot now
    exit 0

elif /tmp/busybox test -e /dev/block/mtdblock0 ; then
    # we're running on a mtd (current) device

    # make sure sdcard is mounted
    check_mount /sdcard $SD_PART vfat

    # everything is logged into /sdcard/cyanogenmod.log
    set_log /sdcard/cyanogenmod_mtd.log

    if $IS_GSM ; then
        # create mountpoint for radio partition
        /tmp/busybox mkdir -p /radio

        # make sure radio partition is mounted
        if ! /tmp/busybox grep -q /radio /proc/mounts ; then
            /tmp/busybox umount -l /dev/block/$RADIO_PART
            if ! /tmp/busybox mount -t yaffs2 /dev/block/$RADIO_PART /radio ; then
                /tmp/busybox echo "Cannot mount radio partition."
                exit 5
            fi
        fi

        # if modem.bin doesn't exist on radio partition, format the partition and copy it
        if ! /tmp/busybox test -e /radio/modem.bin ; then
            /tmp/busybox umount -l /dev/block/$RADIO_PART
            /tmp/erase_image radio
            if ! /tmp/busybox mount -t yaffs2 /dev/block/$RADIO_PART /radio ; then
                /tmp/busybox echo "Cannot copy modem.bin to radio partition."
                exit 5
            else
                /tmp/busybox cp /tmp/modem.bin /radio/modem.bin
            fi
        fi

        # unmount radio partition
        /tmp/busybox umount -l /radio
    fi

    if ! /tmp/busybox test -e /sdcard/cyanogenmod.cfg ; then
        # update install - flash boot image then skip back to updater-script
        # (boot image is already flashed for first time install or old mtd upgrade)

        # flash boot image
        /tmp/bml_over_mtd.sh boot 82 reservoir 2004 /tmp/boot.img

        # unmount system (recovery seems to expect system to be unmounted)
        /tmp/busybox umount -l /system

        exit 0
    fi

    # if a cyanogenmod.cfg exists, then this is a first time install
    # let's format the volumes and restore modem and efs

    # remove the cyanogenmod.cfg to prevent this from looping
    /tmp/busybox rm -f /sdcard/cyanogenmod.cfg

    # unmount and format system (recovery seems to expect system to be unmounted)
    # unmount and format data
    /tmp/busybox umount -l /data
    /tmp/busybox umount -l /cache
    /tmp/busybox umount -l /system

    /tmp/make_ext4fs -b 4096 -g 32768 -i 8192 -I 256 -a /cache /dev/block/mmcblk0p2

    /tmp/make_ext4fs -b 4096 -g 32768 -i 8192 -I 256 -a /data /dev/block/mmcblk0p3
    /tmp/erase_image system

    # restart into recovery so the user can install further packages before booting
    /tmp/busybox touch /cache/.startrecovery

    if $IS_GSM ; then
        # restore efs backup
        if /tmp/busybox test -e /sdcard/backup/efs/nv_data.bin ; then
            /tmp/busybox umount -l /efs
            /tmp/erase_image efs
            /tmp/busybox mkdir -p /efs

            if ! /tmp/busybox grep -q /efs /proc/mounts ; then
                if ! /tmp/busybox mount -t yaffs2 /dev/block/$EFS_PART /efs ; then
                    /tmp/busybox echo "Cannot mount efs."
                    exit 6
                fi
            fi

            /tmp/busybox cp -R /sdcard/backup/efs /
            /tmp/busybox umount -l /efs
        else
            /tmp/busybox echo "Cannot restore efs."
            exit 7
        fi
    fi

    exit 0
fi
