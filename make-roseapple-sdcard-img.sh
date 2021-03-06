#!/bin/sh
###########################################################################################################
# ASUS Tinker Board SD Card Image Tool
# Copyright (C) 2017 Saeid Ghazagh <sghazagh@elar-systems.com>
#
# http://www.elar-systems.com
# http://www.elar-systems.com.au
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
##########################################################################################################
#    See "###### Build the image file ######" sction to adjust SD Card sizes as per your requirement     #
##########################################################################################################

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ -z "$1" ]
  then
    echo "No argument supplied"
    echo "      Arg1: <image_file_name> "
    exit 0
fi
image=$1".img"
echo "Image name --> "${image}
bmap=$1".bmap"

###### Build the image file ######
bootsize=30
MIN_PARTITION_FREE_SIZE=256
BOOT_PART_START=8192
ROOT_PART_START=$(($bootsize*1024*1024/512+$BOOT_PART_START))

#ROOTFSPATH=<Path_to_your_ROOTFS_folder>
#ROOTFSPATH=~/rootfs/Lubuntu16.04.2
ROOTFSPATH=~/rootfs/Ubuntu16.04.2-LXQt
#-------------------------------
echo "Creating Tinker Board SD Card Image ..."
echo "========================================" 

NUMBER_OF_FILES=`sudo find ${ROOTFSPATH} | wc -l`
EXT_SIZE=`sudo du -DsB1 ${ROOTFSPATH} | awk -v min=$MIN_PARTITION_FREE_SIZE -v f=${NUMBER_OF_FILES} \
	'{rootfs_size=$1+f*512;rootfs_size=int(rootfs_size/1024/985); print (rootfs_size+min) }'`

echo "rootfs -->" ${ROOTFSPATH}
echo "Number of files -->" ${NUMBER_OF_FILES}

BOOT_SIZE=$bootsize"M"
echo "Size of Partition 1 -->" $BOOT_SIZE
echo "Size of Partition 2 -->" ${EXT_SIZE}"M"

SD_SIZE=$(($bootsize + $EXT_SIZE))
echo "Total Size of SD Card Image -->" $SD_SIZE"M"

sleep 5

dd if=/dev/zero of=$image bs=1M count=${SD_SIZE}

device=`losetup -f --show $image`
echo "Image $image created and mounted as $device ..."

echo "Writing U-Boot to ${device} ..."
dd if=./hwpack/bootloader/bootloader.bin of=${device} bs=512 seek=4097
dd if=./hwpack/bootloader/u-boot-dtb.img of=${device} bs=512 seek=6144

fdisk $device << EOF
n
p
1
$BOOT_PART_START
+$BOOT_SIZE
t
c
n
p
2
$ROOT_PART_START

a
1
w
EOF

losetup -d $device
device=`kpartx -vsa $image | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
device="/dev/mapper/${device}"
echo ${device}

bootp=${device}p1
rootp=${device}p2

mkfs.vfat -n BOOT $bootp
mkdir -p /mnt/p1
mount $bootp /mnt/p1
#---- Kernel -----------------------------------------------------------------------------
  cp -rpPv ./hwpack/kernel/* /mnt/p1
  sync
umount /mnt/p1
rm -r /mnt/p1

mkfs.ext4 -L rootfs $rootp

mkdir -p /mnt/p2
mount $rootp /mnt/p2
#-- rootfs -------------------------------------------------------------------------------
   #cp -rpPv ${ROOTFSPATH}/* /mnt/p2/
   rsync -ah --info=progress2 ${ROOTFSPATH}/* /mnt/p2/
   rm -rf /mnt/p2/lib/modules
   cp -rpPv ./hwpack/rootfs/* /mnt/p2/
   sync

umount /mnt/p2
rm -r /mnt/p2

echo "Copy completed ..."

kpartx -d $image

#bmaptool create -o "$bmap" "$image"

echo "SD Image file $image has been created successfully."

