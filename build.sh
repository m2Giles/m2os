#!/usr/bin/bash

set -eoux pipefail

# Common
mkdir -p /var/lib/alternatives
/ctx/server-packages.sh
/ctx/branding.sh
/ctx/distrobox.sh
/ctx/signing.sh

# Individual Changes
case "${IMAGE}" in
"bluefin"* | "aurora"*)
    /ctx/desktop-packages.sh
    /ctx/flatpak.sh
    ;;
"cosmic"*)
    /ctx/config.sh
    /ctx/cosmic.sh
    /ctx/bling.sh
    /ctx/homebrew.sh
    /ctx/desktop-packages.sh
    /ctx/flatpak.sh
    ;;
"bazzite"*)
    /ctx/desktop-packages.sh
    /ctx/flatpak.sh
    ;;
esac

# Clean Up
mv /var/lib/alternatives /staged-alternatives
shopt -s extglob
rm -rf /tmp/* || true
rm -rf /"${var:?}"/!(cache)
ostree container commit
mkdir -p /var/lib/ && mv /staged-alternatives /var/lib/alternatives
mkdir -p /var/tmp && chmod -R 1777 /var/tmp
