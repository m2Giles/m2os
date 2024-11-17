#!/usr/bin/bash

set -eoux pipefail

# Docker Repo
tee /etc/yum.repos.d/docker-ce.repo <<'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF

# Incus COPR Repo
curl -Lo /etc/yum.repos.d/ganto-lxc4-fedora.repo \
    https://copr.fedorainfracloud.org/coprs/ganto/lxc4/repo/fedora-"$(rpm -E %fedora)"/ganto-lxc4-fedora-"$(rpm -E %fedora)".repo

SERVER_PACKAGES=(
    binutils
    bootc
    just
    rclone
    sbsigntools
    socat
    swtpm
    tmux
    udica
    zstd
)

# Incus Packages
SERVER_PACKAGES+=(
    distrobuilder
    incus
)

# Docker Packages
SERVER_PACKAGES+=(
    containerd.io
    docker-buildx-plugin
    docker-ce
    docker-ce-cli
    docker-compose-plugin
)

if [[ ${IMAGE} =~ ucore ]]; then
    rpm-ostree override remove \
        containerd docker-cli moby-engine runc
fi

rpm-ostree install "${SERVER_PACKAGES[@]}"

# Bootupctl fix for ISO
if [[ $(rpm -E %fedora) -eq "40" && ! "${IMAGE}" =~ aurora|bluefin|ucore ]]; then
    /usr/bin/bootupctl backend generate-update-metadata
fi

# Docker sysctl.d
mkdir -p /usr/lib/sysctl.d
echo "net.ipv4.ip_forward = 1" >/usr/lib/sysctl.d/docker-ce.conf

# Incus UI
curl -Lo /tmp/incus-ui-canonical.deb \
    https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/"$(curl https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/ | grep -E incus-ui-canonical | cut -d '"' -f 2 | sort -r | head -1)"

ar -x --output=/tmp /tmp/incus-ui-canonical.deb
tar --zstd -xvf /tmp/data.tar.zst
sed -i 's@\[Service\]@\[Service\]\nEnvironment=INCUS_UI=/opt/incus/ui/@g' /usr/lib/systemd/system/incus.service

# Groups
groupmod -g 250 incus-admin
groupmod -g 251 incus
groupmod -g 252 docker

# TMUX Configuration
tee /etc/tmux.conf <<'EOF'
# tmux configuration

# Change Default prefix
unbind  C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Colors
set-option -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*-256color:Tc"

# Mouse Support
set -g mouse on

# Vimode
setw -g mode-keys vi

# Allow OSC52
set -s set-clipboard on
set -g allow-passthrough on

# Window Naming
set-option -g renumber-windows on
setw -g automatic-rename on
set -g base-index 1
setw -g pane-base-index 1

# Switch Panes
bind-key l select-pane -t :.+
bind-key h select-pane -t :.-

# Split and create Panes Commands
bind-key '\' split-window -h
bind-key '-' split-window -v
unbind '"'
unbind %

# Switch Windows and create if not already exists
bind-key 1 if-shell 'tmux select-window -t :1' '' 'new-window -t :1'
bind-key 2 if-shell 'tmux select-window -t :2' '' 'new-window -t :2'
bind-key 3 if-shell 'tmux select-window -t :3' '' 'new-window -t :3'
bind-key 4 if-shell 'tmux select-window -t :4' '' 'new-window -t :4'
bind-key 5 if-shell 'tmux select-window -t :5' '' 'new-window -t :5'
bind-key 6 if-shell 'tmux select-window -t :6' '' 'new-window -t :6'
bind-key 7 if-shell 'tmux select-window -t :7' '' 'new-window -t :7'
bind-key 8 if-shell 'tmux select-window -t :8' '' 'new-window -t :8'
bind-key 9 if-shell 'tmux select-window -t :9' '' 'new-window -t :9'

# Resize Panes
bind-key -n M-H resize-pane -L 2
bind-key -n M-L resize-pane -R 2
bind-key -n M-K resize-pane -U 2
bind-key -n M-J resize-pane -D 2

# window separators
set-option -wg window-status-separator ""

# monitor window changes
set-option -wg monitor-activity on
set-option -wg monitor-bell on

# set statusbar update interval
set-option -g status-interval 1

### theme settings ###

# window separators
set-option -wg window-status-separator ""

# monitor window changes
set-option -wg monitor-activity on
set-option -wg monitor-bell on

# set statusbar update interval
set-option -g status-interval 1
EOF