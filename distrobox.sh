#!/usr/bin/bash

set -eoux pipefail

# Distrobox Stuff
mkdir -p /etc/distrobox/

curl -Lo /tmp/incus.ini \
    https://raw.githubusercontent.com/ublue-os/toolboxes/main/apps/incus/distrobox.ini

tee /tmp/docker.ini <<'EOF'
[docker]
image=ghcr.io/ublue-os/docker-distrobox:latest
# Change the group name to your desired group. Otherwise falls back to docker @ gid 252
#additional_flags="-e DOCKERGROUP=$group"
init=true
nvidia=true
root=true
entry=false
volume="/var/lib/docker:/var/lib/docker /lib/modules:/lib/modules:ro"
init_hooks="usermod -aG docker ${USER}"

EOF

if [[ -f $(find /usr/lib/modules/*/extra/zfs/zfs.ko 2>/dev/null) ]]; then
    echo 'additional_packages="zfsutils-linux"' | tee -a /tmp/incus.ini
    echo 'additional_packages="zfsutils-linux"' | tee -a /tmp/docker.ini
fi

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

cat /tmp/docker.ini >>/etc/distrobox/distrobox.ini
cat /tmp/incus.ini >>/etc/distrobox/distrobox.ini

tee /etc/distrobox/distrobox.conf <<'EOF'
container_always_pull=false
container_generate_entry=false
container_manager="podman"
distrobox_sudo_program="sudo --askpass"
EOF

tee /usr/lib/systemd/system/distrobox-assemble@.service <<EOF
[Unit]
Description=Distrobox Assemble %i
Requires=network-online.target local-fs.target
After=network-online.target local-fs.target

[Service]
User=1000
Type=oneshot
ExecStart=/usr/bin/distrobox-assemble create --file /etc/distrobox/distrobox.ini -n %i
EOF

tee /usr/lib/systemd/system/distrobox-autostart@.service <<EOF
[Unit]
Description=Autostart distrobox %i
Requires=local-fs.target
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStartPre=-/usr/bin/systemctl start distrobox-assemble@%i.service
ExecStart=/usr/bin/distrobox-enter %i
ExecStop=/usr/bin/podman stop -t 30 %i

[Install]
WantedBy=multi-user.target default.target
EOF

mkdir -p /etc/systemd/system/distrobox-autostart@.service.d
tee /etc/systemd/system/distrobox-autostart@.service.d/override.conf <<EOF
[Service]
Environment=HOME=/home/m2
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
EOF

mkdir -p /usr/lib/tmpfiles.d
tee /usr/lib/tmpfiles.d/incus.conf <<EOF
d /var/lib/incus 0700 root root - -
EOF

# Groups
groupadd -g 250 incus-admin
groupadd -g 251 incus
groupmod -g 252 docker
