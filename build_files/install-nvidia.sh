#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

KERNEL_VERSION="$(rpm -q --queryformat="%{EVR}.%{ARCH}" kernel-core)"

case "${IMAGE}" in
*bluefin*)
    base="silverblue"
    ;;
*aurora*)
    base="kinoite"
    ;;
*cosmic*)
    base=""
    dnf5 config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
    ;;
esac

# Install Nvidia RPMs
curl -Lo /tmp/nvidia-install.sh https://raw.githubusercontent.com/ublue-os/main/refs/heads/main/build_files/nvidia-install.sh
chmod +x /tmp/nvidia-install.sh
IMAGE_NAME="$base" RPMFUSION_MIRROR="" /tmp/nvidia-install.sh
rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json
ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so
dnf5 config-manager setopt fedora-multimedia.enabled=1 fedora-nvidia.enabled=0

depmod -a "${KERNEL_VERSION}"
