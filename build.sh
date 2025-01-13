#!/usr/bin/bash

set -eou pipefail

mkdir -p /var/lib/alternatives

#Common
echo "::group:: ===Remove CLI Wrap==="
/ctx/remove-cliwrap.sh
echo "::endgroup::"

echo "::group:: ===Server Packages==="
/ctx/server-packages.sh
echo "::endgroup::"

echo "::group:: ===Distrobox Configuration==="
/ctx/distrobox.sh
echo "::endgroup::"

# Changes
case "${IMAGE}" in
"aurora"* | "bluefin"*)
    echo "::group:: ===Desktop Packages==="
    /ctx/desktop-packages.sh
    echo "::endgroup::"

    echo "::group:: ===Steam Packages==="
    /ctx/steam.sh
    echo "::endgroup::"

    echo "::group:: ===VFIO Configuration==="
    /ctx/vfio.sh
    echo "::endgroup::"
    ;;
"cosmic"*)
    echo "::group:: ===Cosmic Packages==="
    /ctx/cosmic.sh
    echo "::endgroup::"

    echo "::group:: ===Desktop Packages==="
    /ctx/desktop-packages.sh
    echo "::endgroup::"

    echo "::group:: ===Steam Packages==="
    /ctx/steam.sh
    echo "::endgroup::"

    echo "::group:: ===VFIO Configuration==="
    /ctx/vfio.sh
    echo "::endgroup::"
    ;;
"bazzite"*)
    echo "::group:: ===Desktop Packages==="
    /ctx/desktop-packages.sh
    echo "::endgroup::"
    echo "::group:: ===VFIO Configuration==="
    /ctx/vfio.sh
    echo "::endgroup::"
    ;;
"ucore"*) ;;
esac

# Common
echo "::group:: ===Branding Changes==="
/ctx/branding.sh
echo "::endgroup::"

echo "::group:: ===Container Signing==="
/ctx/signing.sh
echo "::endgroup::"

# Clean Up
echo "::group:: ===Cleanup==="
/ctx/cleanup.sh
echo "::endgroup::"
