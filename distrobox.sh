#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

# Distrobox Stuff
mkdir -p /etc/distrobox/

tee -a /etc/distrobox/distrobox.ini <<EOF

[fedora-distrobox]
image=ghcr.io/ublue-os/fedora-toolbox:latest
nvidia=true
entry=false
volume="/home/linuxbrew/:/home/linuxbrew:rslave"

EOF

tee -a /etc/distrobox/distrobox.ini <<EOF
[ubuntu-distrobox]
image=ghcr.io/ublue-os/ubuntu-toolbox:latest
nvidia=true
entry=false
volume="/home/linuxbrew/:/home/linuxbrew:rslave"

EOF

tee /etc/distrobox/distrobox.conf <<'EOF'
container_always_pull=false
container_generate_entry=false
container_manager="podman"
distrobox_sudo_program="sudo --askpass"
EOF
