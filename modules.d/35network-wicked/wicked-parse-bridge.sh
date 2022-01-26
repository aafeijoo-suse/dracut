#!/bin/sh
# This file is part of dracut.
# SPDX-License-Identifier: GPL-2.0-or-later
#
# rework from 35network-legacy/parse-bridge.sh
#
# Format:
#       bridge=<bridgename>:<bridgeslaves>
#
#       <bridgeslaves> is a comma-separated list of physical (ethernet) interfaces
#       bridge without parameters assumes bridge=br0:eth0
#

type getargs > /dev/null 2>&1 || . /lib/dracut-lib.sh

if getargbool 0 rd.net.wickedonly; then
    return
fi

parsebridge() {
    local v=${1}:
    set --
    while [ -n "$v" ]; do
        set -- "$@" "${v%%:*}"
        v=${v#*:}
    done
    case $# in
        0)
            bridgename=br0
            bridgeslaves=$iface
            ;;
        1) die "bridge= requires two parameters" ;;
        2)
            bridgename=$1
            bridgeslaves=$(str_replace "$2" "," " ")
            ;;
        *) die "bridge= requires two parameters" ;;
    esac
}

# Parse bridge for bridgename and bridgeslaves
for bridge in $(getargs bridge=); do
    unset bridgename
    unset bridgeslaves
    iface=eth0
    # Read bridge= parameters if they exist
    if [ "$bridge" != "bridge" ]; then
        parsebridge "$bridge"
    fi
    # Simple default bridge
    if [ -z "$bridgename" ]; then
        bridgename=br0
        bridgeslaves=$iface
    fi
    {
        echo "bridgename=$bridgename"
        echo "bridgeslaves=\"$bridgeslaves\""
    } > /tmp/bridge.${bridgename}.info
done
