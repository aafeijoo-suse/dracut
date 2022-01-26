#!/bin/sh

type getargbool > /dev/null 2>&1 || . /lib/dracut-lib.sh

if ! getargbool 0 rd.net.wickedonly; then
    return
fi

# ensure wickedd is running
systemctl start wickedd
# detection wrapper around ifup --ifconfig "final xml" all
wicked bootstrap --ifconfig /tmp/dracut.xml all
