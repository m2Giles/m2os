#!/usr/bin/env sh

tee /etc/yum.repos.d/_copr_ublue-os-staging.repo <<'EOF'
[copr:copr.fedorainfracloud.org:ublue-os:staging]
name=Copr repo for staging owned by ublue-os
baseurl=https://download.copr.fedorainfracloud.org/results/ublue-os/staging/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/ublue-os/staging/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

tee /etc/yum.repos.d/_copr_che-nerd-fonts.repo <<'EOF'
[copr:copr.fedorainfracloud.org:che:nerd-fonts]
name=Copr repo for nerd-fonts owned by che
baseurl=https://download.copr.fedorainfracloud.org/results/che/nerd-fonts/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/che/nerd-fonts/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

rpm-ostree install /tmp/config-rpms/ublue-os-just.noarch.rpm || true
rpm-ostree install /tmp/config-rpms/ublue-os-luks.noarch.rpm || true
rpm-ostree install /tmp/config-rpms/ublue-os-signing.noarch.rpm || true
rpm-ostree install /tmp/config-rpms/ublue-os-udev-rule.noarch.rpm || true
rpm-ostree install /tmp/config-rpms/ublue-os-update-services.noarch.rpm || true
rpm-ostree install nerd-fonts
