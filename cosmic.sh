#!/usr/bin/bash

set -eoux pipefail

curl -Lo /etc/yum.repos.d/_copr_ryanabx-cosmic.repo \
    https://copr.fedorainfracloud.org/coprs/ryanabx/cosmic-epoch/repo/fedora-"$(rpm -E %fedora)"/ryanabx-cosmic-epoch-fedora-"$(rpm -E %fedora)".repo

rpm-ostree install \
    cosmic-desktop \
    gnome-keyring \
    NetworkManager-tui \
    power-profiles-daemon

systemctl disable gdm || true
systemctl disable sddm || true
systemctl enable cosmic-greeter
systemctl enable power-profiles-daemon
