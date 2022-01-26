#!/bin/sh
# This file is part of dracut.
# SPDX-License-Identifier: GPL-2.0-or-later
#
# rework from 35network-legacy/parse-ifname.sh
#
# Format:
#       ifname=<interface>:<mac>
#
# Note letters in the macaddress must be lowercase!
#
# Examples:
# ifname=eth0:4a:3f:4c:04:f8:d7
#
# Note when using ifname= to get persistent interface names, you must specify
# an ifname= argument for each interface used in an ip= or fcoe= argument

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

if getargbool 0 rd.net.wickedonly; then
    return
fi

# check if there are any ifname parameters
if ! getarg ifname= > /dev/null; then
    return
fi

command -v parse_ifname_opts > /dev/null || . /lib/net-lib.sh

# Check ifname= lines
for p in $(getargs ifname=); do
    parse_ifname_opts "$p"
done
