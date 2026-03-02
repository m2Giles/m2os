#!/usr/bin/bash
#shellcheck disable=SC2115

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

repos=(
    charm
    docker-ce
    fedora-cisco-openh264
    fedora-nvidia
    fedora-updates
    fedora-updates-archive
    fedora-updates-testing
    ganto-lxc4-fedora-"$(rpm -E %fedora)"
    ganto-umoci-fedora-"$(rpm -E %fedora)"
    google-chrome
    negativo17-fedora-multimedia
    negativo17-fedora-nvidia
    nvidia-container-toolkit
    rpm-fusion-nonfree-nvidia-driver
    rpm-fusion-nonfree-steam
    tailscale
    ublue-os-staging-fedora-"$(rpm -E %fedora)"
    vscode
)

for repo in "${repos[@]}"; do
    if [[ -f "/etc/yum.repos.d/${repo}.repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/${repo}.repo"
    fi
done

if ls /etc/yum.repos.d/_copr*.repo &>/dev/null; then
    coprs=()
    mapfile -t coprs <<<"$(find /etc/yum.repos.d/_copr*.repo)"
    for copr in "${coprs[@]}"; do
        sed -i 's@enabled=1@enabled=0@g' "$copr"
    done
fi

# Cleanup extra directories in /usr/lib/modules
KERNEL_VERSION="$(rpm -q kernel-core --queryformat '%{EVR}.%{ARCH}')"

for kernel_dir in /usr/lib/modules/*; do
    echo "$kernel_dir"
    if [[ "$kernel_dir" != "/usr/lib/modules/$KERNEL_VERSION" ]]; then
        echo "Removing $kernel_dir"
        rm -rf "$kernel_dir"
    fi
done

# Fix /opt
rmdir /opt
ln -sf var/opt /opt

#shellcheck disable=SC2114
rm -rf /tmp /var/tmp /var /boot
rm -rf /usr/etc
rm -rf /usr/lib/.build-id
rm -rf /usr/src/kernels/*

rm -rf \
    /etc/.pwd.lock \
    /etc/passwd- \
    /etc/group- \
    /etc/shadow- \
    /etc/gshadow- \
    /etc/subuid- \
    /etc/subgid- \
    /.dockerenv

mkdir -p /tmp
mkdir -p /var/tmp
mkdir -p /boot
chmod -R 1777 /var/tmp
