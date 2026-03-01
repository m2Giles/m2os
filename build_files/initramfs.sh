#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

KERNEL_VERSION="$(rpm -q --queryformat="%{EVR}.%{ARCH}" kernel-core)"

export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

chmod 0600 /usr/lib/modules/"$KERNEL_VERSION"/initramfs.img
setfattr -n user.component -v "rpm/initramfs" /usr/lib/modules/"$KERNEL_VERSION"/initramfs.img