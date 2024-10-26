#!/usr/bin/bash

set -eoux pipefail

mkdir -p /var/lib/alternatives

#Common
/ctx/server-packages.sh
/ctx/distrobox.sh

if [[ "$(rpm -E %fedora)" == "41" ]]; then
    export KERNEL_FLAVOR="main"
    export BETA="-beta"
fi

# Cosmic
if [[ "${IMAGE}" =~ cosmic ]]; then
    /ctx/cosmic.sh
fi

# Changes
case "${IMAGE}" in
"aurora"* | "bluefin"* | "cosmic"* )
    /ctx/build-fix.sh
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
