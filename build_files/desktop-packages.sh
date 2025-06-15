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
curl -Lo /usr/bin/devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64"
chmod +x /usr/bin/devpod
/usr/bin/devpod completion bash >/etc/bash_completion.d/devpod.sh
/usr/bin/devpod completion fish >/usr/share/fish/completions/devpod.fish

# Macadam
mkdir -p /usr/share/factory/opt/macadam/bin/
curl -Lo /usr/share/factory/opt/macadam/bin/macadam https://github.com/crc-org/macadam/releases/latest/download/macadam-linux-amd64
chmod +x /usr/share/factory/opt/macadam/bin/macadam
ln -s /usr/share/factory/opt/macadam/bin/macadam /usr/bin/macadam
/usr/bin/macadam completion bash >/etc/bash_completion.d/macadam.sh
/usr/bin/macadam completion fish >/usr/share/fish/completions/macadam.fish

# Ghostty as appimage :(
while [[ -z "${GHOSTTY:-}" || "${GHOSTTY:-}" == "null" ]]; do
    GHOSTTY="$(curl -L https://api.github.com/repos/pkgforge-dev/ghostty-appimage/releases/latest | jq -r '.assets[] | select(.name| test("Ghostty-[0-9].*-x86_64.AppImage$")).browser_download_url')" || (true && sleep 5)
done
curl --retry 3 -Lo /tmp/ghostty.appimage "$GHOSTTY"
cd /tmp/
chmod +x /tmp/ghostty.appimage
/tmp/ghostty.appimage --appimage-extract
mkdir -p /usr/share/icons/hicolor/256x256/apps/
cp /tmp/AppDir/"$(readlink /tmp/squashfs-root/*.png)" /usr/share/icons/hicolor/256x256/apps/
cp /tmp/AppDir/"$(readlink /tmp/squashfs-root/*.desktop)" /usr/share/applications/
install -m 0755 /tmp/ghostty.appimage /usr/bin/ghostty

# Sysexts
mkdir -p /usr/lib/sysupdate.d
SYSEXTS=(emacs)
for s in "${SYSEXTS[@]}"; do
    tee /usr/lib/sysupdate.d/"$s".transfer <<EOF
[Transfer]
Verify=false

[Source]
Type=url-file
Path=https://github.com/m2Giles/fedora-sysexts/releases/download/m2os-${IMAGE}/
MatchPattern=$s-@v-%a.raw

[Target]
InstancesMax=2
Type=regular-file
Path=/var/lib/extensions.d/
MatchPattern=$s-@v-%a.raw
CurrentSymlink=/var/lib/extensions/$s.raw
EOF
done
