#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

: "${KERNEL_VERSION:=coreos-stable}"

if [[ ! "${IMAGE}" =~ cosmic|(aurora.*|bluefin.*)-beta ]]; then
    echo "No Kernel Swap Necessary..."
    exit 0
fi

# Fetch KERNEL/AKMODS
# shellcheck disable=SC2154
skopeo copy docker://ghcr.io/ublue-os/akmods@"${akmods_digest}" dir:/tmp/akmods
AKMODS_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods/manifest.json | cut -d : -f 2)
tar -xvzf /tmp/akmods/"$AKMODS_TARGZ" -C /tmp/

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
    /tmp/rpms/kmods/*xpadneo-"${KERNEL_VERSION}"-*.rpm
    /tmp/rpms/kmods/*kvmfr-"${KERNEL_VERSION}"-*.rpm
)

# Fetch ZFS
if [[ "${KERNEL_FLAVOR}" =~ coreos ]]; then
    # shellcheck disable=SC2154
    skopeo copy docker://ghcr.io/ublue-os/akmods-zfs@"${akmods_zfs_digest}" dir:/tmp/akmods-zfs
    ZFS_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods-zfs/manifest.json | cut -d : -f 2)
    tar -xvzf /tmp/akmods-zfs/"$ZFS_TARGZ" -C /tmp/
    echo "zfs" >/usr/lib/modules-load.d/zfs.conf

    ZFS_RPMS=(
        /tmp/rpms/kmods/zfs/kmod-zfs-"${KERNEL_VERSION}"-*.rpm
        /tmp/rpms/kmods/zfs/libnvpair3-*.rpm
        /tmp/rpms/kmods/zfs/libuutil3-*.rpm
        /tmp/rpms/kmods/zfs/libzfs6-*.rpm
        /tmp/rpms/kmods/zfs/libzpool6-*.rpm
        /tmp/rpms/kmods/zfs/python3-pyzfs-*.rpm
        /tmp/rpms/kmods/zfs/zfs-*.rpm
        pv
    )
else
    ZFS_RPMS=()
fi

# Delete Kernel Packages for Install
OLD_PACKAGES="$(rpm -qa --queryformat='%{NAME} ' 'kernel-*')"
# shellcheck disable=SC2086
dnf5 remove -y --setopt=disable_excludes='*' $OLD_PACKAGES
# shellcheck disable=SC2086
dnf5 versionlock delete $OLD_PACKAGES

# KVMFR KMOD
dnf5 -y copr enable hikariknight/looking-glass-kvmfr

# Install
export DRACUT_NO_XATTR=1
dnf5 install -y \
    --enablerepo="copr:copr.fedorainfracloud.org:ublue-os:akmods" \
    --allowerasing \
    --setopt=disable_excludes='*' \
    "${KERNEL_RPMS[@]}" "${AKMODS_RPMS[@]}" "${ZFS_RPMS[@]}"
# shellcheck disable=SC2046
dnf5 versionlock add $(rpm -qa --queryformat='%{NAME} ' 'kernel-*')

# Fetch Nvidia
if [[ "${IMAGE}" =~ nvidia ]]; then
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
    # shellcheck disable=SC2154
    skopeo copy docker://ghcr.io/ublue-os/akmods-nvidia-open@"${akmods_nvidia_digest}" dir:/tmp/akmods-rpms
    dnf5 config-manager setopt fedora-multimedia.enabled=1 fedora-nvidia.enabled=1
    NVIDIA_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods-rpms/manifest.json | cut -d : -f 2)
    tar -xvzf /tmp/akmods-rpms/"$NVIDIA_TARGZ" -C /tmp/
    mv /tmp/rpms/* /tmp/akmods-rpms/
    # Install Nvidia RPMs
    curl -Lo /tmp/nvidia-install.sh https://raw.githubusercontent.com/ublue-os/main/refs/heads/main/build_files/nvidia-install.sh
    chmod +x /tmp/nvidia-install.sh
    IMAGE_NAME="$base" RPMFUSION_MIRROR="" /tmp/nvidia-install.sh
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json
    ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so
    dnf5 config-manager setopt fedora-multimedia.enabled=1 fedora-nvidia.enabled=0
fi

depmod -a -v "${KERNEL_VERSION}"
