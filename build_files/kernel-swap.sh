#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

# Fetch KERNEL/AKMODS
KERNEL_VERSION="$(find /tmp/kernel-rpms/kernel-core-*.rpm -prune -printf "%f\n" | sed 's/kernel-core-//g;s/.rpm//g')"

KERNEL_RPMS=(
    "/tmp/kernel-rpms/kernel-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-core-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-modules-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-modules-core-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-modules-extra-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-uki-virt-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-devel-${KERNEL_VERSION}.rpm"
)

AKMODS_RPMS=(
    /tmp/rpms/kmods/*framework-laptop-"${KERNEL_VERSION}"-*.rpm
    /tmp/rpms/kmods/*xone-"${KERNEL_VERSION}"-*.rpm
)

# Delete Kernel Packages for Install
OLD_PACKAGES="$(rpm -qa --queryformat='%{NAME} ' 'kernel-*')"
# shellcheck disable=SC2086
dnf5 remove -y --setopt=disable_excludes='*' $OLD_PACKAGES
# shellcheck disable=SC2086
dnf5 versionlock delete $OLD_PACKAGES

# Install
export DRACUT_NO_XATTR=1
dnf5 install -y \
    --enablerepo="copr:copr.fedorainfracloud.org:ublue-os:akmods" \
    --allowerasing \
    --setopt=disable_excludes='*' \
    "${KERNEL_RPMS[@]}" "${AKMODS_RPMS[@]}"

# shellcheck disable=SC2046
dnf5 versionlock add $(rpm -qa --queryformat='%{NAME} ' 'kernel-*')

depmod -a "${KERNEL_VERSION}"
