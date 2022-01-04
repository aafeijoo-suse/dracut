#!/bin/sh
: > /dev/watchdog

. /lib/dracut-lib.sh

export PATH=/usr/sbin:/usr/bin:/sbin:/bin
mount -t proc proc /proc
command -v plymouth > /dev/null 2>&1 && plymouth --quit
exec > /dev/console 2>&1

echo
echo "*************************"
echo "dracut-root-block-success"
export TERM=linux
export PS1='initramfs-test:\w\$ '
[ -f /etc/mtab ] || ln -sfn /proc/mounts /etc/mtab
[ -f /etc/fstab ] || ln -sfn /proc/mounts /etc/fstab
stty sane
echo "made it to the rootfs!"
if getargbool 0 rd.shell; then
    strstr "$(setsid --help)" "control" && CTTY="-c"
    setsid $CTTY sh -i
fi
echo "Rebooting to next test"
echo "*************************"
sleep 10
mount -n -o remount,ro /
echo b > /proc/sysrq-trigger
