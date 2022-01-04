#!/bin/bash

# shellcheck disable=SC2034
TEST_DESCRIPTION="root filesystem on LVM PV"

KVERSION=${KVERSION-$(uname -r)}

# Uncomment this to debug failures
#DEBUGFAIL="rd.break rd.shell"

export basedir=/usr/lib/dracut

test_setup() {
    kernel=$KVERSION
    # Create what will eventually be our root filesystem onto an overlay
    (
        # shellcheck disable=SC2030
        export initdir=$TESTDIR/overlay/source
        mkdir -p "$initdir"
        # shellcheck disable=SC1090
        . "$basedir"/dracut-init.sh
        (
            cd "$initdir" || exit
            mkdir -p -- dev sys proc etc var/run tmp
            mkdir -p root usr/bin usr/lib usr/lib64 usr/sbin
            mkdir -p -- var/lib/nfs/rpc_pipefs
        )
        inst_multiple sh df free ls shutdown poweroff stty cat ps ln ip \
            mount dmesg dhclient mkdir cp ping dhclient dd sync
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f ${_terminfodir}/l/linux ] && break
        done
        inst_multiple -o ${_terminfodir}/l/linux
        inst "$basedir/modules.d/35network-legacy/dhclient-script.sh" "/sbin/dhclient-script"
        inst "$basedir/modules.d/35network-legacy/ifup.sh" "/sbin/ifup"

        inst_simple "${basedir}/modules.d/99base/dracut-lib.sh" "/lib/dracut-lib.sh"
        inst_simple "${basedir}/modules.d/99base/dracut-dev-lib.sh" "/lib/dracut-dev-lib.sh"
        inst_binary "${basedir}/dracut-util" "/usr/bin/dracut-util"
        ln -s dracut-util "${initdir}/usr/bin/dracut-getarg"
        ln -s dracut-util "${initdir}/usr/bin/dracut-getargs"

        inst_multiple grep
        inst_simple /etc/os-release
        inst ./test-init.sh /sbin/init
        find_binary plymouth > /dev/null && inst_multiple plymouth
        cp -a /etc/ld.so.conf* "$initdir"/etc
        mkdir -p "$initdir"/run
        ldconfig -r "$initdir"
    )

    (
        # shellcheck disable=SC2031
        export initdir=$TESTDIR/overlay
        # shellcheck disable=SC1090
        . "$basedir"/dracut-init.sh
        inst_multiple poweroff shutdown dd
        inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook emergency 000 ./hard-off.sh
    )
    # shellcheck disable=SC2211
    /usr/src/packages/BUILD/dracut-*/dracut.sh -l -i "$TESTDIR"/overlay / \
        -o "plymouth network kernel-network-modules" \
        -a "debug" \
        -d "piix ide-gd_mod ata_piix ext2 sd_mod" \
        --no-hostonly-cmdline -N \
        -f /boot/initramfs.testing "$KVERSION" || return 1

    rm -rf -- $TESTDIR/overlay
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
    rm -r "$TESTDIR"
    return 0
}

# shellcheck disable=SC1090
. /usr/src/packages/BUILD/dracut-*/test/test-functions
