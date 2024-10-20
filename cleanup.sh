#!/usr/bin/bash
#shellcheck disable=SC2115

set -eoux pipefail

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
    charm.repo
    docker-ce.repo
    fedora-updates.repo
    fedora-updates-archive.repo
    tailscale.repo
    ublue-os-bling-fedora-*.repo
    ublue-os-staging-fedora-*.repo
    vscode.repo
)

for repo in "${repos[@]}"; do
    if [[ -f "/etc/yum.repos.d/$repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/$repo"
    fi
done

shopt -s extglob

mv /var/lib/alternatives /staged-alternatives
rm -rf /tmp/*
rm -rf /var/!(cache)
rm -rf /var/cache/!(rpm-ostree)
ostree container commit
mkdir -p /tmp
mkdir -p /var/lib/ && mv /staged-alternatives /var/lib/alternatives
mkdir -p /var/tmp && chmod -R 1777 /var/tmp
