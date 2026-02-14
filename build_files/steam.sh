#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

dnf5 -y config-manager setopt fedora-multimedia.enabled=1
dnf5 -y config-manager setopt "*bazzite*".priority=1

STEAM_PACKAGES=(
    VK_hdr_layer
    dbus-x11
    gamescope-libs.i686
    gamescope-libs.x86_64
    gamescope-shaders
    gamescope.x86_64
    gobject-introspection
    libFAudio.i686
    libFAudio.x86_64
    libobs_glcapture.i686
    libobs_glcapture.x86_64
    libobs_vkcapture.i686
    libobs_vkcapture.x86_64
    lutris
    mangohud.i686
    mangohud.x86_64
    steam
    umu-launcher
    vkBasalt.i686
    vkBasalt.x86_64
    xdg-user-dirs
)

dnf5 install -y --setopt=install_weak_deps=False "${STEAM_PACKAGES[@]}"

dnf5 remove -y gamemode

dnf5 install -y \
    --enable-repo="copr:copr.fedorainfracloud.org:bazzite-org:bazzite" \
    gamescope-session-plus \
    gamescope-session-steam

dnf5 -y config-manager setopt fedora-multimedia.enabled=0
# this allows mangohud to read CPU power wattage
tee /usr/lib/systemd/system/sysfs-read-powercap-intel.service <<EOF
[Unit]
Description=Set readable intel cpu power
After=systemd-udevd.service
After=tuned.service
ConditionPathExists=/sys/class/powercap/intel-rapl:0/energy_uj

[Service]
Type=oneshot
ExecStart=chmod a+r /sys/class/powercap/intel-rapl:0/energy_uj
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable sysfs-read-powercap-intel.service
