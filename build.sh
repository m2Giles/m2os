#!/usr/bin/bash

set -eoux pipefail

# Common
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
    /ctx/desktop-packages.sh
    /ctx/cosmic.sh
    /ctx/bling.sh
    /ctx/homebrew.sh
    /ctx/flatpak.sh
    ;;
"bazzite"*)
    /ctx/desktop-packages.sh
    /ctx/flatpak.sh
    ;;
esac

# Clean Up
rm -rf /tmp/ || true
mkdir -p /var/tmp && chmod 1777 /var/tmp
