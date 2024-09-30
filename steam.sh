#!/usr/bin/bash

set -eoux pipefail

rpm-ostree install \
    at-spi2-core.i686 \
    atk.i686 \
    alsa-lib.i686 \
    clinfo \
    fontconfig.i686 \
    gobject-introspection \
    gtk2.i686 \
    libatomic.i686 \
    libcurl.i686 \
    libdbusmenu-gtk3.i686 \
    libICE.i686 \
    libnsl.i686 \
    libpng12.i686 \
    libva.i686 \
    libvdpau.i686 \
    libxcrypt-compat.i686 \
    libXext.i686 \
    libXinerama.i686 \
    libXScrnSaver.i686 \
    libXtst.i686 \
    NetworkManager-libnm.i686 \
    nss.i686 \
    pipewire-alsa.i686 \
    pulseaudio-libs.i686 \
    systemd-libs.i686 \
    vulkan-loader.i686 \
    https://kojipkgs.fedoraproject.org//packages/SDL2/2.30.3/1.fc40/i686/SDL2-2.30.3-1.fc40.i686.rpm &&
    sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/fedora-updates.repo
rpm-ostree install \
    mesa-vulkan-drivers.i686 \
    mesa-va-drivers-freeworld.i686 \
    mesa-vdpau-drivers-freeworld.i686

sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-nonfree-steam.repo
sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree.repo
sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree-updates.repo
sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree-updates-testing.repo

rpm-ostree install steam
sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree-steam.repo
sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/fedora-updates.repo
