#!/usr/bin/bash

set -eoux pipefail

# ZFS until this gets merged upstream
if [[ "${IMAGE}" =~ (bluefin|aurora) ]]; then
    curl -L -o /etc/yum.repos.d/fedora-coreos-pool.repo \
        https://raw.githubusercontent.com/coreos/fedora-coreos-config/testing-devel/fedora-coreos-pool.repo
    KERNEL_FOR_DEPMOD="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
    rpm-ostree install /tmp/akmods-rpms/kmods/zfs/*.rpm pv
    depmod -A "${KERNEL_FOR_DEPMOD}"
fi

# Bazzite Changes
if [[ "${IMAGE}" == "bazzite-gnome-nvidia" ]]; then
    rpm-ostree install \
        sunshine \
        bootc
    systemctl enable sunshine-workaround.service
    curl -Lo /usr/libexec/ublue-bling.sh \
        https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/usr/libexec/ublue-bling.sh
    chmod +x /usr/libexec/ublue-bling.sh
    mkdir -p /usr/share/ublue-os/{bluefin-cli,homebrew}
    curl -Lo /usr/share/ublue-os/homebrew/bluefin-cli.Brewfile \
        https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/usr/share/ublue-os/homebrew/bluefin-cli.Brewfile
    curl -Lo /usr/share/ublue-os/bluefin-cli/bling.sh \
        https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/usr/share/ublue-os/bluefin-cli/bling.sh
    curl -Lo /usr/share/ublue-os/bluefin-cli/bling.fish \
        https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/usr/share/ublue-os/bluefin-cli/bling.fish
    cat >> /usr/share/ublue-os/just/80-bazzite.just <<EOF

# Bluefin-CLI Bling
bluefin-cli:
    @/usr/libexec/ublue-bling.sh
EOF
fi

# Emacs
rpm-ostree install emacs

# swtpm
rpm-ostree install swtpm

# VSCode because it's still better for a lot of things
curl -Lo /etc/yum.repos.d/vscode.repo \
    https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/dx/etc/yum.repos.d/vscode.repo

rpm-ostree install code

# Docker sysctl.d
mkdir -p /usr/lib/sysctl.d
echo "net.ipv4.ip_forward = 1" > /usr/lib/sysctl.d/docker-ce.conf
sysctl -p

# Distrobox Assemble Files
curl -Lo /tmp/incus.ini \
    https://raw.githubusercontent.com/ublue-os/toolboxes/main/apps/incus/distrobox.ini

curl -Lo /tmp/docker.ini \
    https://raw.githubusercontent.com/ublue-os/toolboxes/main/apps/docker/distrobox.ini

mkdir -p /usr/etc/distrobox/

{ printf "\n"; cat /tmp/incus.ini; printf "\n"; cat /tmp/docker.ini; } >> /usr/etc/distrobox/distrobox.ini

groupadd -g 250 incus-admin
groupadd -g 251 incus
groupadd -g 252 docker

if [[ "${IMAGE}" == "bluefin" ]]; then
    sed -i '/^PRETTY_NAME/s/Bluefin/m2os-bluefin/' /usr/lib/os-release
elif [[ "${IMAGE}" == "aurora" ]]; then
    sed -i '/^PRETTY_NAME/s/Aurora/m2os-aurora/' /usr/lib/os-release
elif [[ "${IMAGE}" == "bazzite-gnome-nvidia" ]]; then
    sed -i '/^PRETTY_NAME/s/Bazzite GNOME/m2os-bazzite/' /usr/lib/os-release
fi
