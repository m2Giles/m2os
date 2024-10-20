#!/usr/bin/bash

set -eoux pipefail

mkdir -p /var/lib/alternatives

#Common
/ctx/build-fix.sh
/ctx/server-packages.sh
/ctx/distrobox.sh

if [[ "$(rpm -E %fedora)" == "41" ]]; then
    export KERNEL_FLAVOR="main"
    export BETA="-beta"
fi

# Changes
case "${IMAGE}" in
"bluefin"* | "aurora"*)
    /ctx/desktop-packages.sh
    /ctx/steam.sh
    ;;
"cosmic"*)
    /ctx/cosmic.sh
    /ctx/desktop-packages.sh
    /ctx/steam.sh
    ;;
"bazzite"*)
    /ctx/desktop-packages.sh
    ;;
"ucore"*)
    ;;
esac

# Common
/ctx/vfio.sh
/ctx/branding.sh
/ctx/signing.sh

# Clean Up
/ctx/cleanup.sh
