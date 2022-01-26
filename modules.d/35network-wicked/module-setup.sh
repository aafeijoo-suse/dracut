#!/bin/bash
# This file is part of dracut.
# SPDX-License-Identifier: GPL-2.0-or-later

#
# WARNING: THIS IS A WIP MODULE
#
# For speed up testing, control how this module is going to work using the
# rd.net.wickedonly command line parameter:
#   - If not present, use legacy ifup and net-genrules
#   - If present, use just wicked
#

# Prerequisite check(s) for module.
check() {

    # If the binary(s) requirements are not fulfilled the module can't be installed.
    require_binaries ip \
        wicked \
        wickedd \
        wickedd-nanny \
        || return 1
    require_any_binary /usr/{lib,libexec}/wicked/bin/wickedd-auto4 || return 1
    require_any_binary /usr/{lib,libexec}/wicked/bin/wickedd-dhcp4 || return 1
    require_any_binary /usr/{lib,libexec}/wicked/bin/wickedd-dhcp6 || return 1

    # Do not add this module by default.
    return 255
}

# Module dependency requirements.
depends() {

    # This module has external dependency on other module(s).
    echo dbus kernel-network-modules systemd

    # Return 0 to include the dependent module(s) in the initramfs.
    return 0

}

# Install the required file(s) and directories for the module.
install() {

    # Scripts.
    # TODO: do we need this ifup? (already reworked from 35network-legacy/ifup.sh)
    inst_script "$moddir/wicked-ifup.sh" "/sbin/ifup"

    # Hooks.
    # TODO: scripts needed to parse arguments for ifup (from 35network-legacy)
    inst_hook cmdline 92 "$moddir/wicked-parse-ibft.sh"
    inst_hook cmdline 95 "$moddir/wicked-parse-vlan.sh"
    inst_hook cmdline 96 "$moddir/wicked-parse-bond.sh"
    inst_hook cmdline 96 "$moddir/wicked-parse-team.sh"
    inst_hook cmdline 97 "$moddir/wicked-parse-bridge.sh"
    inst_hook cmdline 98 "$moddir/wicked-parse-ip-opts.sh"
    inst_hook cmdline 99 "$moddir/wicked-parse-ifname.sh"
    # TODO: IIUC we can get rid of wicked show-config and avoid the cmdline hook
    inst_hook cmdline 99 "$moddir/wicked-config.sh"
    # TODO: do we need to create udev rules like 35network-legacy/net-genrules.sh?
    inst_hook pre-udev 60 "$moddir/wicked-net-genrules.sh"
    inst_hook pre-udev 99 "$moddir/wicked-run.sh"

    # Create wicked related directories.
    inst_dir /usr/share/wicked/schema
    if [ -d /usr/lib/wicked/bin ]; then
        inst_dir /usr/lib/wicked/bin
        inst_multiple "/usr/lib/wicked/bin/*"
    elif [ -d /usr/libexec/wicked/bin ]; then
        inst_dir /usr/libexec/wicked/bin
        inst_multiple "/usr/libexec/wicked/bin/*"
    fi
    inst_dir /var/lib/wicked

    # TODO: do we need the wicked.service?
    inst_multiple -o \
        "/usr/share/wicked/schema/*" \
        /var/lib/wicked/duid.xml \
        /var/lib/wicked/iaid.xml \
        "$dbussystemservices"/org.opensuse.Network.AUTO4.service \
        "$dbussystemservices"/org.opensuse.Network.DHCP4.service \
        "$dbussystemservices"/org.opensuse.Network.DHCP6.service \
        "$dbussystemservices"/org.opensuse.Network.Nanny.service \
        "$systemdsystemunitdir"/wicked.service \
        "$systemdsystemunitdir"/wickedd.service \
        "$systemdsystemunitdir"/wickedd-auto4.service \
        "$systemdsystemunitdir"/wickedd-dhcp4.service \
        "$systemdsystemunitdir"/wickedd-dhcp6.service \
        "$systemdsystemunitdir"/wickedd-nanny.service \
        "$systemdsystemunitdir/wickedd-pppd@.service" \
        wicked wickedd wickedd-nanny pppd \
        teamd teamdctl teamnl

    inst_multiple -o \
        ip ping ping6 sed expr

    if [ -f /etc/dbus-1/system.d/org.opensuse.Network.conf ]; then
        inst_multiple "/etc/dbus-1/system.d/org.opensuse.Network*"
    elif [ -f /usr/share/dbus-1/system.d/org.opensuse.Network.conf ]; then
        inst_multiple "/usr/share/dbus-1/system.d/org.opensuse.Network*"
    fi

    # Enable systemd type units.
    # TODO: do we need the wicked.service?
    local i
    for i in \
        wicked.service \
        wickedd.service \
        wickedd-auto4.service \
        wickedd-dhcp4.service \
        wickedd-dhcp6.service \
        wickedd-nanny.service \
        wickedd-pppd@.service; do
        $SYSTEMCTL -q --root "$initdir" enable "$i"
    done

    # Install the hosts local user configurations if enabled.
    if [[ $hostonly ]]; then
        inst_dir /etc/wicked/extensions

        local wickeddbusconfdir
        wickeddbusconfdir="$dbusconfdir"
        if [ ! -f "$wickeddbusconfdir/org.opensuse.Network.conf" ]; then
            if [ -f /etc/dbus-1/system.d/org.opensuse.Network.conf ]; then
                wickeddbusconfdir="/etc/dbus-1/system.d"
            elif [ -f /usr/share/dbus-1/system.d/org.opensuse.Network.conf ]; then
                wickeddbusconfdir="/usr/share/dbus-1/system.d"
            fi
        fi

        # TODO: do we need the wicked.service?
        inst_multiple -H -o \
            "/etc/wicked/*.xml" \
            "/etc/wicked/extensions/*" \
            "$wickeddbusconfdir"/org.opensuse.Network.conf \
            "$wickeddbusconfdir"/org.opensuse.Network.AUTO4.conf \
            "$wickeddbusconfdir"/org.opensuse.Network.DHCP4.conf \
            "$wickeddbusconfdir"/org.opensuse.Network.DHCP6.conf \
            "$wickeddbusconfdir"/org.opensuse.Network.Nanny.conf \
            "$systemdsystemconfdir"/wicked.service \
            "$systemdsystemconfdir/wicked.service/*.conf" \
            "$systemdsystemconfdir/wicked@.service" \
            "$systemdsystemconfdir/wicked@.service/*.conf" \
            "$systemdsystemconfdir"/wickedd.service \
            "$systemdsystemconfdir/wickedd.service/*.conf" \
            "$systemdsystemconfdir"/wickedd-auto4.service \
            "$systemdsystemconfdir/wickedd-auto4.service/*.conf" \
            "$systemdsystemconfdir"/wickedd-dhcp4.service \
            "$systemdsystemconfdir/wickedd-dhcp4.service/*.conf" \
            "$systemdsystemconfdir"/wickedd-dhcp6.service \
            "$systemdsystemconfdir/wickedd-dhcp6.service/*.conf" \
            "$systemdsystemconfdir"/wickedd-nanny.service \
            "$systemdsystemconfdir/wickedd-nanny.service/*.conf" \
            "$systemdsystemconfdir/wickedd-pppd@.service" \
            "$systemdsystemconfdir/wickedd-pppd@.service.d/*.conf" \
            /etc/libnl/classid

        if [ -f /etc/dbus-1/system.d/org.opensuse.Network.conf ]; then
            inst_multiple "/etc/dbus-1/system.d/org.opensuse.Network*"
        elif [ -f /usr/share/dbus-1/system.d/org.opensuse.Network.conf ]; then
            inst_multiple "/usr/share/dbus-1/system.d/org.opensuse.Network*"
        fi

        # SUSE specific configuration.
        # TODO: does it make sense to copy the ifcfg files from running system?
        inst_multiple -o \
            /etc/sysconfig/network/config \
            /etc/sysconfig/network/dhcp \
            /etc/sysconfig/network/ifcfg-* \
            /etc/sysconfig/network/ifroute-* \
            /etc/sysconfig/network/routes
    fi

    # Modify systemd units.
    # After= must be reset to dbus.service only, so drop-ins don't work here.
    for i in \
        wickedd.service \
        wickedd-auto4.service \
        wickedd-dhcp4.service \
        wickedd-dhcp6.service \
        wickedd-nanny.service; do
        sed -i 's/^After=.*/After=dbus.service/g' "$initdir/$systemdsystemunitdir/$i"
        sed -i 's/^Before=\(.*\)/Before=\1 dracut-pre-udev.service/g' "$initdir/$systemdsystemunitdir/$i"
        sed -i 's/^Wants=\(.*\)/Wants=\1 dbus.service/g' "$initdir/$systemdsystemunitdir/$i"
        # shellcheck disable=SC1004
        sed -i -e \
            '/^\[Unit\]/aDefaultDependencies=no\
            Conflicts=shutdown.target\
            Before=shutdown.target' \
            "$initdir/$systemdsystemunitdir/$i"
    done

    dracut_need_initqueue
}
