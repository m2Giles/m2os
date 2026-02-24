#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

# create a shims to bypass kernel install triggering dracut/rpm-ostree
# seems to be minimal impact, but allows progress on build
pushd /usr/lib/kernel/install.d
mv 05-rpmostree.install 05-rpmostree.install.bak
mv 50-dracut.install 50-dracut.install.bak
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x  05-rpmostree.install 50-dracut.install
popd

# Fetch KERNEL/AKMODS
KERNEL_VERSION="$(find /tmp/kernel-rpms/kernel-core-*.rpm -prune -printf "%f\n" | sed 's/kernel-core-//g;s/.rpm//g')"

KERNEL_RPMS=(
    "/tmp/kernel-rpms/kernel-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-core-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-modules-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-modules-core-${KERNEL_VERSION}.rpm"
    "/tmp/kernel-rpms/kernel-modules-extra-${KERNEL_VERSION}.rpm"
)

AKMODS_RPMS=(
    /tmp/rpms/kmods/*.rpm
    /tmp/rpms/common/*.rpm
)

# Delete Kernel Packages for Install
OLD_PACKAGES="$(rpm -qa --queryformat='%{NAME} ' 'kernel-*')"
# shellcheck disable=SC2086
dnf5 remove -y --setopt=disable_excludes='*' kernel $OLD_PACKAGES
# shellcheck disable=SC2086
dnf5 versionlock delete kernel $OLD_PACKAGES

# Install
export DRACUT_NO_XATTR=1
dnf5 install -y \
    --allowerasing \
    --setopt=disable_excludes='*' \
    "${KERNEL_RPMS[@]}" "${AKMODS_RPMS[@]}"

# shellcheck disable=SC2046
dnf5 versionlock add kernel $(rpm -qa --queryformat='%{NAME} ' 'kernel-*')

pushd /usr/lib/kernel/install.d
mv -f 05-rpmostree.install.bak 05-rpmostree.install
mv -f 50-dracut.install.bak 50-dracut.install
popd

depmod -a "${KERNEL_VERSION}"
