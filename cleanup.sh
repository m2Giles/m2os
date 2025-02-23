#!/usr/bin/bash
#shellcheck disable=SC2115

set ${SET_X:+-x} -eou pipefail

repos=(
    charm
    docker-ce
    fedora-cisco-openh264
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

if [[ ! "${IMAGE}" =~ ucore ]]; then
    coprs=()
    mapfile -t coprs <<<"$(find /etc/yum.repos.d/_copr*.repo)"
    for copr in "${coprs[@]}"; do
        sed -i 's@enabled=1@enabled=0@g' "$copr"
    done
fi

dnf5 clean all

rm -rf /tmp/*
rm -rf /var/*
mkdir -p /tmp
mkdir -p /var/tmp
chmod -R 1777 /var/tmp

ostree container commit
