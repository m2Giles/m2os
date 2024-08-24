#!/usr/bin/bash

set -eoux pipefail

if [[ ! "$(command -v gcc)" ]]; then
    rpm-ostree override replace \
        --install=gcc \
        --install=make \
        libgcc
fi

touch /.dockerenv
mkdir -p /var/home
mkdir -p /var/roothome
curl -Lo /tmp/brew-install https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
chmod +x /tmp/brew-install
/tmp/brew-install
tar --zstd -cvf /usr/share/homebrew.tar.zst /home/linuxbrew/.linuxbrew

mkdir -p /usr/lib/systemd/system/

tee /usr/lib/systemd/system/brew-setup.service <<EOF
[Unit]
Description=Setup Brew
Wants=network-online.target
After=network-online.target
ConditionPathExists=!/etc/.linuxbrew
ConditionPathExists=!/var/home/linuxbrew/.linuxbrew

[Service]
Type=oneshot
ExecStart=/usr/bin/mkdir -p /tmp/homebrew
ExecStart=/usr/bin/tar --zstd -xvf /usr/share/homebrew.tar.zst -C /tmp/homebrew
ExecStart=/usr/bin/cp -R -n /tmp/homebrew/home/linuxbrew/.linuxbrew /var/home/linuxbrew
ExecStart=/usr/bin/chown -R 1000:1000 /var/home/linuxbrew
ExecStart=/usr/bin/rm -rf /tmp/homebrew
ExecStart=/usr/bin/touch /etc/.linuxbrew

[Install]
WantedBy=default.target multi-user.target
EOF

tee /usr/lib/systemd/system/brew-update.service <<EOF
[Unit]
Description=Auto update brew for mutable brew installs
After=local-fs.target
After=network-online.target
ConditionPathIsSymbolicLink=/home/linuxbrew/.linuxbrew/bin/brew

[Service]
# Override the user if different UID/User
User=1000
Type=oneshot
Environment=HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar
Environment=HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
Environment=HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew
ExecStart=/home/linuxbrew/.linuxbrew/bin/brew update
ExecStart=/home/linuxbrew/.linuxbrew/bin/brew upgrade
EOF

tee /usr/lib/systemd/system/brew-update.timer <<EOF
[Unit]
Description=Timer for brew update for mutable brew
Wants=network-online.target

[Timer]
OnBootSec=10min
OnUnitInactiveSec=8h
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable brew-update.timer
systemctl enable brew-setup.service
