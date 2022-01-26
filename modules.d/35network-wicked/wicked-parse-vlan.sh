#!/bin/sh
# This file is part of dracut.
# SPDX-License-Identifier: GPL-2.0-or-later
#
# rework from 35network-legacy/parse-vlan.sh
#
# Format:
#	vlan=<vlanname>:<phydevice>
#

type getargs > /dev/null 2>&1 || . /lib/dracut-lib.sh

if getargbool 0 rd.net.wickedonly; then
    return
fi

parsevlan() {
    local v=${1}:
    set --
    while [ -n "$v" ]; do
        set -- "$@" "${v%%:*}"
        v=${v#*:}
    done

    unset vlanname phydevice
    case $# in
        2)
            vlanname=$1
            phydevice=$2
            ;;
        *) die "vlan= requires two parameters" ;;
    esac
}

for vlan in $(getargs vlan=); do
    unset vlanname
    unset phydevice
    if [ ! "$vlan" = "vlan" ]; then
        parsevlan "$vlan"
    fi

    echo "phydevice=\"$phydevice\"" > /tmp/vlan."${phydevice}".phy
    {
        echo "vlanname=\"$vlanname\""
        echo "phydevice=\"$phydevice\""
    } > /tmp/vlan."${vlanname}"."${phydevice}"
done
