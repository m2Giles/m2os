#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

dnf5 -y install dnf5-plugins

# Incus/Podman COPR Repo
dnf5 -y copr enable ganto/lxc4
dnf5 -y copr enable ganto/umoci

SERVER_PACKAGES=(
    binutils
    bootc
    cpp
    erofs-utils
    just
    jq
    rclone
    sbsigntools
    skopeo
    socat
    tmux
    udica
    yq
)

# Incus Packages
SERVER_PACKAGES+=(
    edk2-ovmf
    genisoimage
    incus
    incus-agent
    incus-client
    podman-machine
    qemu-char-spice
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-vga
    qemu-device-usb-redirect
    qemu-img
    qemu-kvm-core
    swtpm
    umoci
)

# Docker Packages
SERVER_PACKAGES+=(
    containerd.io
    docker-buildx-plugin
    docker-ce
    docker-ce-cli
    docker-compose-plugin
)

if [[ ${IMAGE} =~ ucore ]]; then
    dnf5 remove -y \
        containerd docker-cli moby-engine runc
fi

dnf5 install -y "${SERVER_PACKAGES[@]}"

# The superior default editor
dnf5 swap -y \
    nano-default-editor vim-default-editor

# Incus UI
curl -Lo /tmp/incus-ui-canonical.deb \
    https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/"$(curl https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/ | grep -E incus-ui-canonical | cut -d '"' -f 2 | sort -r | head -1)"

ar -x --output=/tmp /tmp/incus-ui-canonical.deb
tar --zstd -xvf /tmp/data.tar.zst
mv /opt/incus /usr/lib/
sed -i 's@\[Service\]@\[Service\]\nEnvironment=INCUS_UI=/usr/lib/incus/ui/@g' /usr/lib/systemd/system/incus.service

# Statically assign groups eventually there will be a better solution for this.
groupmod -g 250 incus-admin
groupmod -g 251 incus
groupmod -g 252 docker
