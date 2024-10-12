#!/usr/bin/bash

set -eoux pipefail

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

tee /usr/lib/systemd/system/sunshine-workaround.service <<'EOF'
[Unit]
Description=Workaround sunshine not having the correct caps
ConditionFileIsExecutable=/usr/bin/sunshine
After=local-fs.target

[Service]
Type=oneshot
# Copy if it doesn't exist
ExecStartPre=/usr/bin/bash -c "[ -x /usr/local/bin/.sunshine ] || /usr/bin/cp /usr/bin/sunshine /usr/local/bin/.sunshine"
# This is faster than using .mount unit. Also allows for the previous line/cleanup
ExecStartPre=/usr/bin/bash -c "/usr/bin/mount --bind /usr/local/bin/.sunshine /usr/bin/sunshine"
# Fix caps
ExecStart=/usr/bin/bash -c "/usr/sbin/setcap 'cap_sys_admin+p' $(/usr/bin/readlink -f $(/usr/bin/which sunshine))"
# Clean-up after ourselves
ExecStop=/usr/bin/umount /usr/bin/sunshine
ExecStop=/usr/bin/rm /usr/local/bin/.sunshine
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable sunshine-workaround.service

curl -Lo /etc/yum.repos.d/_copr_kylegospo-webapp-manager.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/webapp-manager/repo/fedora-"${FEDORA_VERSION}"/kylegospo-webapp-manager-fedora-"${FEDORA_VERSION}".repo

# Layered Applications
LAYERED_PACKAGES=(breeze-cursor-theme code emacs git-credential-libsecret git-credential-oauth sunshine webapp-manager)
if [[ "${IMAGE}" =~ aurora ]]; then
    LAYERED_PACKAGES+=(krdp)
fi

rpm-ostree install "${LAYERED_PACKAGES[@]}"

# Zed because why not?
curl -Lo /tmp/zed.tar.gz \
    https://zed.dev/api/releases/stable/latest/zed-linux-x86_64.tar.gz
mkdir -p /usr/lib/zed.app/
tar -xvf /tmp/zed.tar.gz -C /usr/lib/zed.app/ --strip-components=1
ln -s /usr/lib/zed.app/bin/zed /usr/bin/zed
cp /usr/lib/zed.app/share/applications/zed.desktop /usr/share/applications/dev.zed.Zed.desktop
sed -i "s|Icon=zed|Icon=/usr/lib/zed.app/share/icons/hicolor/512x512/apps/zed.png|g" /usr/share/applications/dev.zed.Zed.desktop
sed -i "s|Exec=zed|Exec=/usr/lib/zed.app/libexec/zed-editor|g" /usr/share/applications/dev.zed.Zed.desktop

# Call other Scripts
/ctx/desktop-defaults.sh
/ctx/flatpak.sh
