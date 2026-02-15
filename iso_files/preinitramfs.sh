#!/usr/bin/env bash
#
set -eoux pipefail

kernel_pkgs=(
    kernel
    kernel-core
    kernel-devel
    kernel-devel-matched
    kernel-modules
    kernel-modules-core
    kernel-modules-extra
)

dnf5 -y versionlock delete "${kernel_pkgs[@]}"

dnf5 -y --setopt=protect_running_kernel=False remove "${kernel_pkgs[@]}"

(cd /usr/lib/modules && rm -rf -- ./*)

dnf5 -y --repo fedora,updates --setopt=tsflags=noscripts install kernel kernel-core

kernel=$(find /usr/lib/modules -maxdepth 1 -type d -printf '%P\n' | grep .)
depmod "$kernel"

imageref="$(podman images --format '{{ index .Names 0 }}\n' 'bazzite*' | head -1)"
imageref="${imageref##*://}"
imageref="${imageref%%:*}"

dnf5 install -y nvidia-gpu-firmware || :
dnf5 -y clean all
