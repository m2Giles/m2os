#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

# Ublue Staging
dnf5 -y copr enable ublue-os/staging

# Ublue Packages
dnf5 -y copr enable ublue-os/packages

# OBS-VKcapture
dnf5 -y copr enable kylegospo/obs-vkcapture

# Bazzite Repos
dnf5 -y copr enable kylegospo/bazzite
dnf5 -y copr enable kylegospo/bazzite-multilib
dnf5 -y copr enable kylegospo/LatencyFleX

# Sunshine
dnf5 -y copr enable lizardbyte/beta

# Webapp Manager
dnf5 -y copr enable kylegospo/webapp-manager

# Layered Applications
LAYERED_PACKAGES=(
    adw-gtk3-theme
    breeze-cursor-theme
    cascadia-fonts-all
    devpod
    git-credential-libsecret
    git-credential-oauth
    spice-gtk-tools
    sunshine
    uupd
    webapp-manager
)

if [[ "${IMAGE}" =~ aurora ]]; then
    LAYERED_PACKAGES+=(krdp)
fi

if [[ "${IMAGE}" =~ bluefin ]]; then
    LAYERED_PACKAGES+=(
        gnome-shell-extension-compiz-windows-effect
        gnome-shell-extension-just-perfection
        gnome-shell-extension-hotedge
    )
fi

dnf5 install --setopt=install_weak_deps=False -y "${LAYERED_PACKAGES[@]}"

# Zed because why not?
curl -Lo /tmp/zed.tar.gz \
    https://zed.dev/api/releases/stable/latest/zed-linux-x86_64.tar.gz
mkdir -p /usr/lib/zed.app/
tar -xvf /tmp/zed.tar.gz -C /usr/lib/zed.app/ --strip-components=1
chown 0:0 -R /usr/lib/zed.app
ln -s /usr/lib/zed.app/bin/zed /usr/bin/zed-cli
cp /usr/lib/zed.app/share/applications/zed.desktop /usr/share/applications/dev.zed.Zed.desktop
mkdir -p /usr/share/icons/hicolor/1024x1024/apps
cp {/usr/lib/zed.app,/usr}/share/icons/hicolor/512x512/apps/zed.png
cp {/usr/lib/zed.app,/usr}/share/icons/hicolor/1024x1024/apps/zed.png
sed -i "s@Exec=zed@Exec=/usr/lib/zed.app/libexec/zed-editor@g" /usr/share/applications/dev.zed.Zed.desktop

# Emacs LSP Booster
while [[ -z "${EMACS_LSP_BOOSTER:-}" || "${EMACS_LSP_BOOSTER:-}" =~ null ]]; do
    EMACS_LSP_BOOSTER="$(
        curl -L https://api.github.com/repos/blahgeek/emacs-lsp-booster/releases/latest |
            jq -r '.assets[].browser_download_url' |
            grep musl.zip$
    )"
done
curl --retry 3 -Lo /tmp/emacs-lsp-booster.zip "$EMACS_LSP_BOOSTER"
unzip -d /usr/bin/ /tmp/emacs-lsp-booster.zip

# Call other Scripts
/ctx/desktop-defaults.sh
/ctx/flatpak.sh

# Services / Use uupd updater
dnf5 remove -y ublue-os-update-services
systemctl disable rpm-ostreed-automatic.timer
systemctl disable flatpak-system-update.timer
systemctl --global disable flatpak-user-update.timer
systemctl disable brew-update.timer
systemctl disable brew-upgrade.timer
systemctl enable uupd.timer

# Sysexts
mkdir -p /etc/sysupdate.d/
tee /usr/lib/tmpfiles.d/m2os-sysext.conf <<EOF
d /var/lib/extensions/ 0755 root root - -
d /var/lib/extensions.d/ 0755 root root - -
EOF
SYSEXTS=(
    emacs
    google-chrome
    keepassxc
    microsoft-edge
    neovim
    vscode
)
if [[ "${IMAGE}" =~ bluefin|bazzite|cosmic ]]; then
    FLAVOR=silverblue
elif [[ "${IMAGE}" =~ aurora ]]; then
    FLAVOR=kinoite
fi
for SYSEXT in "${SYSEXTS[@]}"; do
    tee /etc/sysupdate.d/"$SYSEXT".conf <<EOF
[Transfer]
Verify=false

[Source]
Type=url-file
Path=https://github.com/travier/fedora-sysexts/releases/download/fedora-$FLAVOR-41/
MatchPattern=$SYSEXT-@v-%a.raw

[Target]
InstancesMax=2
Type=regular-file
Path=/var/lib/extensions.d/
MatchPattern=$SYSEXT-@v-%a.raw
CurrentSymlink=/var/lib/extensions/$SYSEXT.raw
EOF
done
