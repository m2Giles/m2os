#!/usr/bin/bash

set -eoux pipefail

# Docker Repo
tee /etc/yum.repos.d/docker-ce.repo <<'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF

# Incus COPR Repo
curl -Lo /etc/yum.repos.d/ganto-lxc4-fedora.repo \
    https://copr.fedorainfracloud.org/coprs/ganto/lxc4/repo/fedora-"$(rpm -E %fedora)"/ganto-lxc4-fedora-"$(rpm -E %fedora)".repo

SERVER_PACKAGES=(
    binutils
    bootc
    just
    rclone
    sbsigntools
    socat
    swtpm
    udica
    zstd
)

# Incus Packages
SERVER_PACKAGES+=(
    distrobuilder
    incus
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
    rpm-ostree override remove \
        containerd docker-cli moby-engine runc
fi

rpm-ostree install "${SERVER_PACKAGES[@]}"

# Bootupctl fix for ISO
if [[ $(rpm -E %fedora) -eq "40" && ! "${IMAGE}" =~ aurora|bluefin|ucore ]]; then
    /usr/bin/bootupctl backend generate-update-metadata
fi

# Docker sysctl.d
mkdir -p /usr/lib/sysctl.d
echo "net.ipv4.ip_forward = 1" >/usr/lib/sysctl.d/docker-ce.conf

# Incus UI
curl -Lo /tmp/incus-ui-canonical.deb \
    https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/"$(curl https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/ | grep -E incus-ui-canonical | cut -d '"' -f 2 | sort -r | head -1)"

ar -x --output=/tmp /tmp/incus-ui-canonical.deb
tar --zstd -xvf /tmp/data.tar.zst
sed -i 's@\[Service\]@\[Service\]\nEnvironment=INCUS_UI=/opt/incus/ui/@g' /usr/lib/systemd/system/incus.service

# Groups
groupmod -g 250 incus-admin
groupmod -g 251 incus
groupmod -g 252 docker