#!/usr/bin/env sh

curl -Lo /etc/yum.repos.d/_copr_ublue-os_staging.repo \
    https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-"${FEDORA_VERSION}"/ublue-os-staging-fedora-"${FEDORA_VERSION}".repo

curl -Lo /etc/yum.repos.d/_copr_che-nerd-fonts.repo \
    https://copr.fedorainfracloud.org/coprs/che/nerd-fonts/repo/fedora-"${FEDORA_VERSION}"/che-nerd-fonts-fedora-"${FEDORA_VERSION}".repo

rpm-ostree install /tmp/config-rpms/ublue-os-luks.noarch.rpm || true
rpm-ostree install /tmp/config-rpms/ublue-os-just.noarch.rpm || true
rpm-ostree install /tmp/config-rpms/ublue-os-signing.noarch.rpm || true
rpm-ostree install /tmp/config-rpms/ublue-os-udev-rule.noarch.rpm || true
rpm-ostree install /tmp/config-rpms/ublue-os-update-services.noarch.rpm || true
rpm-ostree install nerd-fonts
