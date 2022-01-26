#!/bin/sh

type getargbool > /dev/null 2>&1 || . /lib/dracut-lib.sh

if ! getargbool 0 rd.net.wickedonly; then
    return
fi

getcmdline > /tmp/cmdline.$$.conf
wicked show-config --ifconfig dracut:cmdline:/tmp/cmdline.$$.conf > /tmp/dracut.xml
rm -f /tmp/cmdline.$$.conf
