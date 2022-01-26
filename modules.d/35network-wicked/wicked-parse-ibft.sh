#!/bin/sh
# This file is part of dracut.
# SPDX-License-Identifier: GPL-2.0-or-later
#
# rework from 35network-legacy/parse-ibft.sh

type getargbool > /dev/null 2>&1 || . /lib/dracut-lib.sh
type ibft_to_cmdline > /dev/null 2>&1 || . /lib/net-lib.sh

if getargbool 0 rd.net.wickedonly; then
    return
fi

if getargbool 0 rd.iscsi.ibft -d "ip=ibft"; then
    modprobe -b -q iscsi_boot_sysfs 2> /dev/null
    modprobe -b -q iscsi_ibft
    ibft_to_cmdline
fi
