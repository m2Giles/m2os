#!/usr/bin/bash

set -eoux pipefail

# Ublue Staging
dnf5 -y copr enable ublue-os/staging

# OBS-VKcapture
dnf5 -y copr enable kylegospo/obs-vkcapture

# Bazzite Repos
dnf5 -y copr enable kylegospo/bazzite
dnf5 -y copr enable kylegospo/bazzite-multilib
dnf5 -y copr enable kylegospo/LatencyFleX

# VSCode because it's still better for a lot of things
tee /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Sunshine
dnf5 -y copr enable matte-schwartz/sunshine

# Webapp Manager
dnf5 -y copr enable kylegospo/webapp-manager

# Layered Applications
LAYERED_PACKAGES=(
    adw-gtk3-theme
    breeze-cursor-theme
    code
    devpod
    emacs
    git-credential-libsecret
    git-credential-oauth
    spice-gtk-tools
    sunshine
    webapp-manager
)

if [[ "${IMAGE}" =~ aurora ]]; then
    LAYERED_PACKAGES+=(krdp)
fi

dnf5 install -y "${LAYERED_PACKAGES[@]}"

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

# Call other Scripts
/ctx/desktop-defaults.sh
/ctx/flatpak.sh
