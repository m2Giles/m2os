#!/usr/bin/bash

set -eoux pipefail

# Add Staging repo
curl -Lo /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_VERSION}".repo \
    https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-"${FEDORA_VERSION}"/ublue-os-staging-fedora-"${FEDORA_VERSION}".repo

# Add Bling repo
curl -Lo /etc/yum.repos.d/ublue-os-bling-fedora-"${FEDORA_VERSION}".repo \
    https://copr.fedorainfracloud.org/coprs/ublue-os/bling/repo/fedora-"${FEDORA_VERSION}"/ublue-os-bling-fedora-"${FEDORA_VERSION}".repo

# Add Nerd Fonts
curl -Lo /etc/yum.repos.d/_copr_che-nerd-fonts-"${FEDORA_VERSION}".repo \
    https://copr.fedorainfracloud.org/coprs/che/nerd-fonts/repo/fedora-"${FEDORA_VERSION}"/che-nerd-fonts-fedora-"${FEDORA_VERSION}".repo

# Add Looking Glass
curl -Lo /etc/yum.repos.d/hikariknight-looking-glass-kvmfr-fedora-"${FEDORA_VERSION}".repo \
    https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/repo/fedora-"${FEDORA_VERSION}"/hikariknight-looking-glass-kvmfr-fedora-"${FEDORA_VERSION}".repo


rpm-ostree override replace --experimental \
    --install=/tmp/akmods/kmods/*kvmfr*.rpm \
    --install=/tmp/akmods/kmods/*xpadneo*.rpm \
    --install=/tmp/akmods/kmods/*xone*.rpm \
    --install=/tmp/akmods/kmods/*openrazer*.rpm \
    --install=/tmp/akmods/kmods/*wl*.rpm \
    --install=/tmp/akmods/kmods/*v4l2loopback*.rpm \
    --install=pv \
    --install=/tmp/akmods-zfs/kmods/zfs/libnvpair*.rpm \
    --install=/tmp/akmods-zfs/kmods/zfs/libzpool*.rpm \
    --install=/tmp/akmods-zfs/kmods/zfs/python3-pyzfs*.rpm \
    --install=/tmp/akmods-zfs/kmods/zfs/kmod-zfs*.rpm \
    --install=/tmp/akmods-zfs/kmods/zfs/zfs*.rpm \
    --install=ptyxis \
    /tmp/kernel-rpms/kernel-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-core-*.rpm \
    /tmp/kernel-rpms/kernel-modules-*.rpm

KERNEL_SUFFIX=""
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"$KERNEL_SUFFIX"'-)//')"

depmod -a -v "$QUALIFIED_KERNEL"
echo "zfs" > /usr/lib/modules-load.d/zfs.conf

rpm-ostree install \
    bash-color-prompt \
    bcache-tools \
    bootc \
    evtest \
    fastfetch \
    fish \
    firewall-config \
    foo2zjs \
    gcc \
    glow \
    gum \
    hplip \
    ifuse \
    libimobiledevice \
    libxcrypt-compat \
    lm_sensors \
    make \
    mesa-libGLU \
    nerd-fonts \
    playerctl \
    pulseaudio-utils \
    python3-pip \
    rclone \
    restic \
    samba-dcerpc \
    samba-ldb-ldap-modules \
    samba-winbind-clients \
    samba-winbind-modules \
    samba \
    solaar \
    tailscale \
    tmux \
    usbmuxd \
    wireguard-tools \
    xprop \
    wl-clipboard

rpm-ostree install ublue-update