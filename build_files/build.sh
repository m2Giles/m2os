#!/usr/bin/bash

set -eou pipefail

function echo_group() {
    local WHAT
    WHAT="$(
        basename "$1" .sh |
            tr "-" " " |
            tr "_" " "
    )"
    echo "::group:: === ${WHAT^^} ==="
    "$1"
    echo "::endgroup::"
}

# Common
echo_group /ctx/remove-cliwrap.sh
echo_group /ctx/server-packages.sh
echo_group /ctx/distrobox.sh
echo_group /ctx/branding.sh
echo_group /ctx/signing.sh
echo_group /ctx/composefs.sh

# Desktops
case "$IMAGE" in
"cosmic"*)
    echo_group /ctx/cosmic.sh
    echo_group /ctx/desktop-packages.sh
    echo_group /ctx/vfio.sh
    ;;
"aurora"* | "bluefin"*)
    echo_group /ctx/desktop-packages.sh
    echo_group /ctx/steam.sh
    echo_group /ctx/vfio.sh
    ;;
"bazzite"*)
    echo_group /ctx/desktop-packages.sh
    echo_group /ctx/vfio.sh
    ;;
"ucore"*) ;;
esac

# Cleanup
echo_group /ctx/cleanup.sh
