#!/bin/sh
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
mount -t proc proc /proc
exec >/dev/console 2>&1
echo
echo "*************************"
echo "dracut-root-block-success"
sync
export TERM=linux
export PS1='initramfs-test:\w\$ '
[ -f /etc/fstab ] || ln -s /proc/mounts /etc/fstab
stty sane
echo "made it to the rootfs! Powering down."
mount -n -o remount,ro /
echo b > /proc/sysrq-trigger
