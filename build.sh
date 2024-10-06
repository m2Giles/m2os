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
    ;;
"cosmic"*)
    /ctx/cosmic.sh
    ;;
"bazzite"*)
    /ctx/desktop-packages.sh
    ;;
"ucore"*)
    ;;
esac

/ctx/vfio.sh

# Clean Up
mv /var/lib/alternatives /staged-alternatives
rm -rf /tmp/* || true
rm -rf /var/* || true
ostree container commit
mkdir -p /tmp
mkdir -p /var/lib/ && mv /staged-alternatives /var/lib/alternatives
mkdir -p /var/tmp && chmod -R 1777 /var/tmp
