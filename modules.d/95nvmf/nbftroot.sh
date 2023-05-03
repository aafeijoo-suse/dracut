#! /bin/sh
# This script is called from /sbin/netroot

echo "$0 $@" >&2
/sbin/nvmf-autoconnect.sh online
exit 0
