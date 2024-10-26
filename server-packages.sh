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

# Get Incus Client
curl -Lo /usr/bin/incus \
    "https://github.com/lxc/incus/releases/latest/download/bin.linux.incus.$(uname -m)"

chmod +x /usr/bin/incus

mkdir -p /var/roothome/
incus completion bash | tee /usr/share/bash-completion/completions/incus

SERVER_PACKAGES=(
    bootc
    just
    rclone
    sbsigntools
    socat
    swtpm
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
        containerd moby-engine runc
fi

rpm-ostree install "${SERVER_PACKAGES[@]}"

# Bootupctl fix for ISO
if [[ $(rpm -E %fedora) -eq "40" && ! "${IMAGE}" =~ aurora|bluefin|ucore ]]; then
    /usr/bin/bootupctl backend generate-update-metadata
fi

# Docker sysctl.d
mkdir -p /usr/lib/sysctl.d
echo "net.ipv4.ip_forward = 1" >/usr/lib/sysctl.d/docker-ce.conf
