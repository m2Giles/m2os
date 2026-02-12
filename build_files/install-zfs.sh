#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

echo "zfs" >/usr/lib/modules-load.d/zfs.conf

KERNEL_VERSION="$(rpm -q --queryformat="%{EVR}.%{ARCH}" kernel-core)"

ZFS_RPMS=(
    /tmp/rpms/kmods/zfs/kmod-zfs-"${KERNEL_VERSION}"-*.rpm
    /tmp/rpms/kmods/zfs/libnvpair*.rpm
    /tmp/rpms/kmods/zfs/libuutil*.rpm
    /tmp/rpms/kmods/zfs/libzfs*.rpm
    /tmp/rpms/kmods/zfs/libzpool*.rpm
    /tmp/rpms/kmods/zfs/python3-pyzfs-*.rpm
    /tmp/rpms/kmods/zfs/zfs-*.rpm
    pv
)

dnf5 install -y \
    --enablerepo="copr:copr.fedorainfracloud.org:ublue-os:akmods" \
    --allowerasing \
    --setopt=disable_excludes='*' \
    "${ZFS_RPMS[@]}"

depmod -a "${KERNEL_VERSION}"
