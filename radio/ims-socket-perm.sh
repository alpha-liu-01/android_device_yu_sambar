#!/system/bin/sh
# rild runs as root, so rild_imsN is created 0700 root:radio. The IMS client
# runs inside com.android.phone (uid radio) and cannot connect until the
# group bit is set.
i=0
while [ "$i" -lt 40 ]; do
    if [ -S /dev/socket/qmux_radio/rild_ims0 ] && [ -S /dev/socket/qmux_radio/rild_ims1 ]; then
        chmod 770 /dev/socket/qmux_radio/rild_ims0 /dev/socket/qmux_radio/rild_ims1
        chown root radio /dev/socket/qmux_radio/rild_ims0 /dev/socket/qmux_radio/rild_ims1
        exit 0
    fi
    i=$((i + 1))
    sleep 1
done
exit 0
