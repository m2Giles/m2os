#!/usr/bin/bash

set -eoux pipefail

mkdir -p /var/lib/alternatives

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

# Clean Up
mv /var/lib/alternatives /staged-alternatives
rm -rf /tmp/* || true
rm -rf /var/* || true
ostree container commit
mkdir -p /tmp
mkdir -p /var/lib/ && mv /staged-alternatives /var/lib/alternatives
mkdir -p /var/tmp && chmod -R 1777 /var/tmp
