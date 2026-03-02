#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

# Ublue Staging
dnf5 -y copr enable ublue-os/staging

# Ublue Packages
dnf5 -y copr enable ublue-os/packages

# OBS-VKcapture
dnf5 -y copr enable bazzite-org/obs-vkcapture

# Bazzite Repos
dnf5 -y copr enable bazzite-org/bazzite
dnf5 -y copr enable bazzite-org/bazzite-multilib
dnf5 -y copr enable bazzite-org/LatencyFleX

# Sunshine
dnf5 -y copr enable lizardbyte/beta

# Layered Applications
LAYERED_PACKAGES=(
    adw-gtk3-theme
    cascadia-fonts-all
    git-credential-libsecret
    git-credential-oauth
    emacs-pgtk
    qemu-ui-gtk
    spice-gtk-tools
    sunshine
    uupd
)

if [[ "${IMAGE}" =~ aurora ]]; then
    LAYERED_PACKAGES+=(krdp)
fi

if [[ "${IMAGE}" =~ bluefin ]]; then
    LAYERED_PACKAGES+=(
        gnome-shell-extension-compiz-windows-effect
        gnome-shell-extension-hotedge
        gnome-shell-extension-just-perfection
    )
fi

if [[ "${IMAGE}" =~ bluefin|bazzite ]]; then
    LAYERED_PACKAGES+=(gnome-shell-extension-drive-menu)
fi

dnf5 install --setopt=install_weak_deps=False -y "${LAYERED_PACKAGES[@]}"

dnf5 remove -y google-noto-fonts-all

# Services / Use uupd updater
dnf5 remove -y ublue-os-update-services
systemctl disable rpm-ostreed-automatic.timer
systemctl disable flatpak-system-update.timer
systemctl --global disable flatpak-user-update.timer
systemctl disable brew-update.timer
systemctl disable brew-upgrade.timer
systemctl enable uupd.timer

# Devpod cli
ghcurl "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64" -o /usr/bin/devpod
chmod +x /usr/bin/devpod
/usr/bin/devpod completion bash >/etc/bash_completion.d/devpod.sh
/usr/bin/devpod completion fish >/usr/share/fish/completions/devpod.fish

# Macadam
mkdir -p /usr/share/factory/opt/macadam/bin/
ghcurl https://github.com/crc-org/macadam/releases/latest/download/macadam-linux-amd64 -o /usr/share/factory/opt/macadam/bin/macadam
chmod +x /usr/share/factory/opt/macadam/bin/macadam
ln -s /usr/share/factory/opt/macadam/bin/macadam /usr/bin/macadam
/usr/bin/macadam completion bash >/etc/bash_completion.d/macadam.sh
/usr/bin/macadam completion fish >/usr/share/fish/completions/macadam.fish

# Enable p11-kit-server for Flatpak support in browsers and other applications
systemctl enable --global p11-kit-server.socket
systemctl enable --global p11-kit-server.service
systemctl enable m2os-flatpak-overrides.service

# this allows mangohud to read CPU power wattage
systemctl enable sysfs-read-powercap-intel.service
