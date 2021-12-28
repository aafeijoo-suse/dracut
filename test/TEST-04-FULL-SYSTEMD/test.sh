#!/bin/bash

TEST_DESCRIPTION="Full systemd serialization/deserialization test with /usr mount"

export KVERSION=${KVERSION-$(uname -r)}

# Uncomment this to debug failures
#DEBUGFAIL="rd.shell rd.break"
#DEBUGFAIL="rd.shell"
#DEBUGOUT="quiet systemd.log_level=debug systemd.log_target=console loglevel=77  rd.info rd.debug"
DEBUGOUT="loglevel=0 "

test_setup() {
    export kernel=$KVERSION
    # Create what will eventually be our root filesystem onto an overlay
    (
	export initdir=$TESTDIR/overlay/source
	mkdir -p $initdir
	. $basedir/dracut-init.sh

        for d in usr/bin usr/sbin bin etc lib "$libdir" sbin tmp usr var var/log dev proc sys sysroot root run; do
            if [ -L "/$d" ]; then
                inst_symlink "/$d"
            else
                inst_dir "/$d"
            fi
        done

        ln -sfn /run "$initdir/var/run"
        ln -sfn /run/lock "$initdir/var/lock"

	inst_multiple sh df free ls shutdown poweroff stty cat ps ln ip \
	    mount dmesg dhclient mkdir cp ping dhclient \
	    umount strace less setsid tree systemctl reset

	for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f ${_terminfodir}/l/linux ] && break
	done
	inst_multiple -o ${_terminfodir}/l/linux
	inst "$basedir/modules.d/35network-legacy/dhclient-script.sh" "/sbin/dhclient-script"
	inst "$basedir/modules.d/35network-legacy/ifup.sh" "/sbin/ifup"
	inst_multiple grep
        inst_simple ./fstab /etc/fstab
        rpm -ql systemd | xargs -r $DRACUT_INSTALL ${initdir:+-D "$initdir"} -o -a -l
        inst /lib/systemd/system/systemd-remount-fs.service
        inst /lib/systemd/systemd-remount-fs
        inst /lib/systemd/system/systemd-journal-flush.service
        inst /etc/sysconfig/init
	inst /lib/systemd/system/slices.target
	inst /lib/systemd/system/system.slice
	inst_multiple -o /lib/systemd/system/dracut*

        # make a journal directory
        mkdir -p $initdir/var/log/journal

        # install some basic config files
        inst_multiple -o  \
	    /etc/machine-id \
	    /etc/adjtime \
            /etc/sysconfig/init \
            /etc/passwd \
            /etc/shadow \
            /etc/group \
            /etc/shells \
            /etc/nsswitch.conf \
            /etc/pam.conf \
            /etc/securetty \
            /etc/os-release \
            /etc/localtime

        # we want an empty environment
        > $initdir/etc/environment

        # setup the testsuite target
        cat >$initdir/etc/systemd/system/testsuite.target <<EOF
[Unit]
Description=Testsuite target
Requires=basic.target
After=basic.target
Conflicts=rescue.target
AllowIsolate=yes
EOF

        inst ./test-init.sh /sbin/test-init

        # setup the testsuite service
        cat >$initdir/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service
After=basic.target

[Service]
ExecStart=/sbin/test-init
Type=oneshot
StandardInput=tty
StandardOutput=tty
EOF
        mkdir -p $initdir/etc/systemd/system/testsuite.target.wants
        ln -fs ../testsuite.service $initdir/etc/systemd/system/testsuite.target.wants/testsuite.service

        # make the testsuite the default target
        ln -fs testsuite.target $initdir/etc/systemd/system/default.target

#         mkdir -p $initdir/etc/rc.d
#         cat >$initdir/etc/rc.d/rc.local <<EOF
# #!/bin/bash
# exit 0
# EOF

        # install basic tools needed
        inst_multiple sh bash setsid loadkeys setfont \
            login sushell sulogin gzip sleep echo mount umount
        inst_multiple modprobe

        # install libnss_files for login
        inst_libdir_file "libnss_files*"

        # install dbus and pam
        find \
            /etc/dbus-1 \
            /etc/pam.d \
            /etc/security \
            /lib64/security \
            /lib/security -xtype f \
            | while read file || [ -n "$file" ]; do
            inst_multiple -o $file
        done

        # install dbus socket and service file
        inst /usr/lib/systemd/system/dbus.socket
        inst /usr/lib/systemd/system/dbus.service

        (
            echo "FONT=latarcyrheb-sun16"
            echo "KEYMAP=us"
        ) >$initrd/etc/vconsole.conf

        # install basic keyboard maps and fonts
        for i in \
            /usr/lib/kbd/consolefonts/eurlatgr* \
            /usr/lib/kbd/consolefonts/latarcyrheb-sun16* \
            /usr/lib/kbd/keymaps/{legacy/,/}include/* \
            /usr/lib/kbd/keymaps/{legacy/,/}i386/include/* \
            /usr/lib/kbd/keymaps/{legacy/,/}i386/qwerty/us.*; do
                [[ -f $i ]] || continue
                inst $i
        done

        # some basic terminfo files
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f ${_terminfodir}/l/linux ] && break
        done
        inst_multiple -o ${_terminfodir}/l/linux

        # softlink mtab
        ln -fs /proc/self/mounts $initdir/etc/mtab

        # install any Execs from the service files
        grep -Eho '^Exec[^ ]*=[^ ]+' $initdir/lib/systemd/system/*.service \
            | while read i || [ -n "$i" ]; do
            i=${i##Exec*=}; i=${i##-}
            inst_multiple -o $i
        done

        # some helper tools for debugging
        [[ $DEBUGTOOLS ]] && inst_multiple $DEBUGTOOLS

        # install ld.so.conf* and run ldconfig
        cp -a /etc/ld.so.conf* $initdir/etc
        ldconfig -r "$initdir"
        ddebug "Strip binaeries"
        find "$initdir" -perm /0111 -type f | xargs -r strip --strip-unneeded | ddebug

        # copy depmod files
        inst /lib/modules/$kernel/modules.order
        inst /lib/modules/$kernel/modules.builtin
        # generate module dependencies
        if [[ -d $initdir/lib/modules/$kernel ]] && \
            ! depmod -a -b "$initdir" $kernel; then
                dfatal "\"depmod -a $kernel\" failed."
                exit 1
        fi

    )

    # second, install the files needed to make the root filesystem
    (
	export initdir=$TESTDIR/overlay
	. $basedir/dracut-init.sh
	inst_multiple sfdisk mkfs.btrfs btrfs poweroff cp umount sync
	inst_hook initqueue 01 ./create-root.sh
        inst_hook initqueue/finished 01 ./finished-false.sh
	inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )


    (
	export initdir=$TESTDIR/overlay
	. $basedir/dracut-init.sh
	inst_multiple poweroff shutdown
	inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook emergency 000 ./hard-off.sh
	inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )

    [ -e /etc/machine-id ] && EXTRA_MACHINE="/etc/machine-id"
    [ -e /etc/machine-info ] && EXTRA_MACHINE+=" /etc/machine-info"

    sudo /usr/src/packages/BUILD/dracut-*/dracut.sh -l -i $TESTDIR/overlay / \
	-a "debug systemd i18n" \
	${EXTRA_MACHINE:+-I "$EXTRA_MACHINE"} \
        -o "dash network plymouth lvm mdraid resume crypt caps dm terminfo usrmount kernel-network-modules" \
	-d "piix ide-gd_mod ata_piix btrfs sd_mod i6300esb ib700wdt" \
        --no-hostonly-cmdline -N \
	-f /boot/initramfs.testing $KVERSION || return 1

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
    rm -r $TESTDIR
    return 0
}

. /usr/src/packages/BUILD/dracut-*/test/test-functions
