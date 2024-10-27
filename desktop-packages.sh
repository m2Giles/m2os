#!/usr/bin/bash

set -eoux pipefail

# OBS-VKcapture
curl -Lo /etc/yum.repos.d/_copr_kylegospo-obs-vkcapture.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/obs-vkcapture/repo/fedora-"$(rpm -E %fedora)"/kylegospo-obs-vkcapture-fedora-"$(rpm -E %fedora)".repo?arch=x86_64

# Bazzite Repos
curl -Lo /etc/yum.repos.d/_copr_kylegospo-bazzite.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/bazzite/repo/fedora-"$(rpm -E %fedora)"/kylegospo-bazzite-fedora-"$(rpm -E %fedora)".repo
curl -Lo /etc/yum.repos.d/_copr_kylegospo-bazzite-multilib.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/bazzite-multilib/repo/fedora-"$(rpm -E %fedora)"/kylegospo-bazzite-multilib-fedora-"$(rpm -E %fedora)".repo?arch=x86_64
curl -Lo /etc/yum.repos.d/_copr_kylegospo-latencyflex.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/LatencyFleX/repo/fedora-"$(rpm -E %fedora)"/kylegospo-LatencyFleX-fedora-"$(rpm -E %fedora)".repo

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
tee /etc/yum.repos.d/_copr_matte-schwartz-sunshine.repo <<'EOF'
[copr:copr.fedorainfracloud.org:matte-schwartz:sunshine]
name=Copr repo for sunshine owned by matte-schwartz
baseurl=https://download.copr.fedorainfracloud.org/results/matte-schwartz/sunshine/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/matte-schwartz/sunshine/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

curl -Lo /etc/yum.repos.d/_copr_kylegospo-webapp-manager.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/webapp-manager/repo/fedora-"$(rpm -E %fedora)"/kylegospo-webapp-manager-fedora-"$(rpm -E %fedora)".repo

# Layered Applications
LAYERED_PACKAGES=(
    adw-gtk3-theme
    breeze-cursor-theme
    code
    emacs
    git-credential-libsecret
    git-credential-oauth
    sunshine
    webapp-manager
)

if [[ "${IMAGE}" =~ aurora ]]; then
    LAYERED_PACKAGES+=(krdp)
fi

rpm-ostree install "${LAYERED_PACKAGES[@]}"

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
