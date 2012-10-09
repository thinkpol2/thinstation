#! /bin/sh
#
# Mount Hotplug Device
#

#echo "1 $DEVPATH" >> /var/log/scsi
#echo "2 $ACTION" >> /var/log/scsi
#echo "3 $ID_BUS" >> /var/log/scsi
#echo "4 $ID_FS_TYPE" >> /var/log/scsi
#echo "4 $ID_CDROM_MEDIA" >> /var/log/scsi

devpath=`basename $DEVPATH`
name=`echo $devpath | sed -e "s/[0-9]*//g"`
node=`echo $devpath | sed -e "s/[a-z]*//g"`
TYPE=`echo $name | cut -c 1-2`

no_mount()
{
	for i in gparted parted fdisk cfdisk ; do
		if [ -n "`pidof $i`" ] ; then
			return 0
		fi
	done
	if [ -e /tmp/nomount ] ; then
		return 0
	else
		return 1
	fi
}

mounted()
{
        if [ "`cat /proc/mounts |grep -c -e $1`" -ne "0" ]; then
                return 0
        else
                return 1
        fi
}

if [ "$ACTION" == "remove" ] || [ "$TYPE" == "sr" ] && [ "$ID_CDROM_MEDIA" != "1" ]; then
	if [ "$ID_FS_TYPE" == "swap" ]; then
                swapoff /dev/$devpath
		exit 0
	else
		while mounted /dev/$devpath ; do
                	mtpath=`cat /proc/mounts |grep -e /dev/$devpath |tail -n 1 |cut -d ' ' -f 2 |grep -e /mnt`
                	umount -n -f $mtpath
                	while [ -n "$mtpath" ] && [ -z "`ls -A $mtpath`" ] ; do
                        	rmdir $mtpath
				mtpath="`dirname $mtpath`"
                	done
        	done
		exit 0
	fi
elif no_mount ;then
        exit 0
elif [ "$ACTION" == "add" ] && [ "$ID_FS_TYPE" == "swap" ]; then
        swapon /dev/$devpath
        exit 0
fi

. /etc/thinstation.env
. $TS_GLOBAL

if ! check_module $ID_FS_TYPE ; then
	modprobe $ID_FS_TYPE
fi

do_mounts()
{
	mkdir -p $mtpath
	if [ -n "$mount_opts" ] ; then
        	MT_CMD="mount -t $ID_FS_TYPE -o $mount_opts /dev/$devpath $mtpath"
	else
        	MT_CMD="mount -t $ID_FS_TYPE /dev/$devpath $mtpath"
	fi
	echo "5 $MT_CMD" >> /var/log/scsi
	$MT_CMD 2>> /var/log/scsi
	index=0
        while [ -n "`eval echo '$BIND_MOUNT'$index`" ] ; do
        	MOUNT=`eval echo '$BIND_MOUNT'$index`
		FS_LABEL=`echo "$MOUNT" | cut -d ":" -f1`
		MT_PATH=`echo "$MOUNT" | cut -d ":" -f2`
		if [ "$ID_FS_LABEL" == "$FS_LABEL" ]; then
			mkdir -p $MT_PATH
			mount --bind $mtpath $MT_PATH
			echo "6 $mtpath $MT_PATH" >> /var/log/scsi
		fi
		let index=index+1
	done
}

if [ "$TYPE" == "sr" ] && [ "$ID_CDROM_MEDIA" == "1" ]; then
       	if [ -e /proc/sys/dev/cdrom ] ; then
		echo 0 > /proc/sys/dev/cdrom/autoclose
	fi
	if is_disabled $LOCK_CDROM ; then
		echo 0 > /proc/sys/dev/cdrom/lock
	fi
        mtpath=/mnt/cdrom$node
       	mount_opts="$CDROM_MOUNT_OPTIONS"
	do_mounts
elif [ "$TYPE" == "sd" ] && [ "$ACTION" == "add" ] ; then
	if [ "$ID_BUS" == "usb" ] ; then
		if is_enabled $USB_STORAGE_SYNC && [ ! -n "`echo $USB_MOUNT_OPTIONS |grep -e sync`" ]; then
			USB_MOUNT_OPTIONS=$USB_MOUNT_OPTIONS,sync
		fi
	        label=$devpath
	        if [ -n "$USB_MOUNT_USELABEL" ] ;then
        		if is_enabled $USB_MOUNT_USELABEL ; then
				if [ -n "$ID_FS_LABEL" ] ; then
					label=$ID_FS_LABEL
				fi
			elif ! is_disabled $USB_MOUNT_USELABEL ; then
				if [ -n "$ID_FS_LABEL" ] ; then
					label=$ID_FS_LABEL
				else
					label=$USB_MOUNT_USELABEL
				fi
			fi
		fi
		mtpath=$USB_MOUNT_DIR/$label
	        let x=0
	        testmountpoint=$mtpath
		while mounted ${testmountpoint} ] ; do
			let x=x+1
			testmountpoint=$mtpath$x
		done
		if [ "$testmountpoint" != "$mtpath" ] ; then
			mtpath=$testmountpoint
		fi
		mount_opts="$USB_MOUNT_OPTIONS"
	else
		if is_enabled $DISK_STORAGE_SYNC && [ ! -n "`echo $DISK_MOUNT_OPTIONS |grep -e sync`" ]; then
                        DISK_MOUNT_OPTIONS=$DISK_MOUNT_OPTIONS,sync
                fi
		mtpath=/mnt/disc/$name/part$node
		mount_opts="$DISK_MOUNT_OPTIONS"
	fi
	do_mounts
fi

exit 0
