#!/usr/bin/bash

set -eoux pipefail

mkdir -p /var/lib/alternatives

curl -Lo /etc/yum.repos.d/_copr_ryanabx-cosmic.repo \
    https://copr.fedorainfracloud.org/coprs/ryanabx/cosmic-epoch/repo/fedora-"$(rpm -E %fedora)"/ryanabx-cosmic-epoch-fedora-"$(rpm -E %fedora)".repo

PACKAGES=(cosmic-desktop gnome-keyring NetworkManager-tui power-profiles-daemon)
rpm-ostree install "${PACKAGES[@]}"

systemctl disable cosmic-greeter || true
systemctl enable power-profiles-daemon