#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

mkdir -p /var/lib/alternatives

#Common
/ctx/remove-cliwrap.sh
/ctx/server-packages.sh
/ctx/distrobox.sh

# Changes
case "${IMAGE}" in
"aurora"* | "bluefin"*)
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
    ;;
esac

# Common
/ctx/branding.sh
/ctx/signing.sh

# Clean Up
/ctx/cleanup.sh
