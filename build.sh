#!/usr/bin/bash

set -eoux pipefail

mkdir -p /var/lib/alternatives

#Common
/ctx/server-packages.sh
/ctx/branding.sh
/ctx/distrobox.sh
/ctx/signing.sh

# Changes
case "${IMAGE}" in
"bluefin"* | "aurora"*)
    /ctx/desktop-packages.sh
    /ctx/steam.sh
    /ctx/vfio.sh
    ;;
"cosmic"*)
    /ctx/cosmic.sh
    /ctx/desktop-packages.sh
    /ctx/steam.sh
    /ctx/vfio.sh
    ;;
"bazzite"*)
    /ctx/desktop-packages.sh
    /ctx/vfio.sh
    ;;
"ucore"*)
    /ctx/vfio.sh
    ;;
esac

# Clean Up
repos=(
    _copr_kylegospo-bazzite.repo
    _copr_kylegospo-bazzite-multilib.repo
    _copr_ublue-os-akmods.repo
    _copr_ublue-os-staging.repo
    _copr_kylegospo-latencyflex.repo
    _copr_kylegospo-obs-vkcapture.repo
    _copr_kylegospo-webapp-manager.repo
    _copr_che-nerd-fonts.repo
    _copr_hikariknight-looking-glass-kvmfr.repo
    tailscale.repo
    charm.repo
    docker-ce.repo
    tailscale.repo
    ublue-os-bling-fedora-*.repo
    ublue-os-staging-fedora-*.repo
    vscode.repo
)
for repo in ${repos[@]}; do
    if [[ -f "/etc/yum.repos./$repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/$repo"
    fi
done

shopt -s extglob

mv /var/lib/alternatives /staged-alternatives
rm -rf /tmp/*
if [[ ${CLEAN_CACHE} == "1" ]]; then
    rm -rf /var/*
else
    rm -rf /var/!(cache)
    rm -rf /var/cache/!(rpm-ostree)
fi
ostree container commit
mkdir -p /tmp
mkdir -p /var/lib/ && mv /staged-alternatives /var/lib/alternatives
mkdir -p /var/tmp && chmod -R 1777 /var/tmp
