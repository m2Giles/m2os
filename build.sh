#!/usr/bin/bash

set -eoux pipefail

mkdir -p /var/lib/alternatives

# Changes
case "${IMAGE}" in
"bluefin"* | "aurora"*)
    /ctx/server-packages.sh
    /ctx/branding.sh
    /ctx/distrobox.sh
    /ctx/signing.sh
    /ctx/desktop-packages.sh
    /ctx/vfio.sh
    ;;
"cosmic"*)
    /ctx/cosmic.sh
    ;;
"bazzite"*)
    /ctx/server-packages.sh
    /ctx/branding.sh
    /ctx/distrobox.sh
    /ctx/signing.sh
    /ctx/desktop-packages.sh
    /ctx/vfio.sh
    ;;
"ucore"*)
    /ctx/server-packages.sh
    /ctx/branding.sh
    /ctx/distrobox.sh
    /ctx/signing.sh
    ;;
esac

# Clean Up

shopt -s extglob
mv /var/lib/alternatives /staged-alternatives
rm -rf /tmp/* || true
rm -rf /var/!(cache)
rm -rf /var/cache/!(rpm-ostree)
ostree container commit
mkdir -p /tmp
mkdir -p /var/lib/ && mv /staged-alternatives /var/lib/alternatives
mkdir -p /var/tmp && chmod -R 1777 /var/tmp
