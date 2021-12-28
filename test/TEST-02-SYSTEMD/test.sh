#!/bin/bash
TEST_DESCRIPTION="root filesystem on a ext3 filesystem"

KVERSION="${KVERSION-$(uname -r)}"

# Uncomment this to debug failures
#DEBUGFAIL="rd.shell=1 rd.break=pre-mount"
export basedir=/usr/lib/dracut

test_setup() {
export initdir=$TESTDIR/overlay
. $basedir/dracut-init.sh

    kernel=$KVERSION
    # Create what will eventually be our root filesystem onto an overlay
    (
        export initdir=$TESTDIR/overlay/source
        mkdir -p $initdir
        . $basedir/dracut-init.sh
        (
            cd "$initdir"
            mkdir -p -- dev sys proc etc var/run tmp
            mkdir -p root usr/bin usr/lib usr/lib64 usr/sbin
            for i in bin sbin lib lib64; do
                ln -sfnr usr/$i $i
            done
            mkdir -p -- var/lib/nfs/rpc_pipefs
        )
        inst_multiple sh df free ls shutdown poweroff stty cat ps ln ip \
            mount dmesg dhclient mkdir cp ping dhclient \
            umount strace less setsid systemd-analyze
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f ${_terminfodir}/l/linux ] && break
        done
        inst_multiple -o ${_terminfodir}/l/linux
        inst "$basedir/modules.d/35network-legacy/dhclient-script.sh" "/sbin/dhclient-script"
        inst "$basedir/modules.d/35network-legacy/ifup.sh" "/sbin/ifup"
        inst_multiple grep
        inst_simple /etc/os-release
        inst ./test-init.sh /sbin/init
        find_binary plymouth >/dev/null && inst_multiple plymouth
        cp -a /etc/ld.so.conf* $initdir/etc
        sudo ldconfig -r "$initdir"
    )

    # second, install the files needed to make the root filesystem
    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        inst_multiple sfdisk mkfs.ext3 poweroff cp umount
        inst_hook initqueue 01 ./create-root.sh
        inst_hook initqueue/finished 01 ./finished-false.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )

    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        inst_multiple poweroff shutdown
        inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook pre-pivot 000 ./systemd-analyze.sh
        inst_hook emergency 000 ./hard-off.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )
    /usr/src/packages/BUILD/dracut-*/dracut.sh -l -i $TESTDIR/overlay / \
        -a "debug systemd" \
        -o "network kernel-network-modules" \
        -d "piix ide-gd_mod ata_piix ext3 sd_mod" \
        --no-hostonly-cmdline -N \
        -f /boot/initramfs.testing $KVERSION || return 1

#	-o "plymouth network md dmraid multipath fips caps crypt btrfs resume dmsquash-live dm"
# delete old config
sed -i '6,$d' /etc/grub.d/40_custom

# copy boot menu entry
sed -n '/### BEGIN \/etc\/grub.d\/10_linux ###/,/submenu/p' /boot/grub2/grub.cfg >> /etc/grub.d/40_custom
sed -i '/### BEGIN \/etc\/grub.d\/10_linux ###/d' /etc/grub.d/40_custom
sed -i '/submenu/d' /etc/grub.d/40_custom
# modify it for testing
sed -i "s#menuentry .*#menuentry \'dracut testing\' {#" /etc/grub.d/40_custom
sed -i 's#initrd *.*#initrd /boot/initramfs.testing#' /etc/grub.d/40_custom
sed -i "/linux/s/\${extra_cmdline.*/panic=1 systemd.log_target=console rd.retry=3 rd.debug console=tty0 rd.shell=0 $DEBUGFAIL/" /etc/grub.d/40_custom
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEMOUT=5/' /etc/default/grub
# create new grub config
grub2-mkconfig -o /boot/grub2/grub.cfg || return 1
grub2-reboot "dracut testing"
sleep 10
echo -e "\n\n*************************"
echo "dracut-root-block-created"
echo -e "*************************\n"

}

test_cleanup() {
    rm -r $TESTDIR
    return 0
}

. /usr/src/packages/BUILD/dracut-*/test/test-functions
