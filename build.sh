#!/usr/bin/bash

set -eoux pipefail

# Global Environment Variables
{ echo "EDITOR=/usr/bin/vim"; echo "VISUAL=/usr/bin/emacs"; } >> /etc/environment

# VSCode because it's still better for a lot of things
curl -Lo /etc/yum.repos.d/vscode.repo \
    https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/dx/etc/yum.repos.d/vscode.repo

# Sunshine
curl -Lo /etc/yum.repos.d/_copr_matte-schwartz-sunshine.repo \
    https://copr.fedorainfracloud.org/coprs/matte-schwartz/sunshine/repo/fedora-"${FEDORA_VERSION}"/matte-schwartz-sunshine-fedora-"${FEDORA_VERSION}".repo

curl -Lo /usr/lib/systemd/system/sunshine-workaround.service \
    https://raw.githubusercontent.com/ublue-os/bazzite/main/system_files/desktop/shared/usr/lib/systemd/system/sunshine-workaround.service

# Layered Applications
rpm-ostree install \
    bootc \
    code \
    emacs \
    rclone \
    socat \
    sunshine \
    swtpm

# Docker sysctl.d
mkdir -p /usr/lib/sysctl.d
echo "net.ipv4.ip_forward = 1" > /usr/lib/sysctl.d/docker-ce.conf
sysctl -p

# Distrobox Stuff
curl -Lo /tmp/incus.ini \
    https://raw.githubusercontent.com/ublue-os/toolboxes/main/apps/incus/distrobox.ini

curl -Lo /tmp/docker.ini \
    https://raw.githubusercontent.com/ublue-os/toolboxes/main/apps/docker/distrobox.ini

echo 'additional_packages="zfsutils-linux"' >> /tmp/incus.ini
echo 'volume="/lib/modules:/lib/modules:ro"' >> /tmp/docker.ini
echo 'additional_packages="zfsutils-linux"' >> /tmp/docker.ini

cat >> /tmp/fedora.ini <<EOF
[fedora]
image=ghcr.io/ublue-os/fedora-toolbox:latest
nvidia=true
entry=false
volume="/home/linuxbrew/:/home/linuxbrew:rslave"
EOF

cat >> /tmp/ubuntu.ini <<EOF
[fedora]
image=ghcr.io/ublue-os/ubuntu-toolbox:latest
nvidia=true
entry=false
volume="/home/linuxbrew/:/home/linuxbrew:rslave"
EOF

cat > /usr/etc/distrobox/distrobox.conf <<'EOF'
container_always_pull=false
container_generate_entry=false
container_manager="podman"
distrobox_sudo_program="/usr/bin/systemd-run --uid=0 --gid=0 -d -E TERM="$TERM" -t -q -P -G"
EOF

mkdir -p /usr/etc/distrobox/

{
    cat /tmp/incus.ini ; printf "\n";
    cat /tmp/docker.ini; printf "\n";
    cat /tmp/fedora.ini; printf "\n";
    cat /tmp/ubuntu.ini;
} >> /usr/etc/distrobox/distrobox.ini

cat > /usr/lib/systemd/system/distrbox-assemble@.service <<EOF
[Unit]
Description=Distrobox Assemble %i
Requires=network-online.target local-fs.target
After=network-online.target local-fs.target

[Service]
User=1000
Type=oneshot
ExecStart=/usr/bin/distrobox-assemble create --file /usr/etc/distrobox/distrobox.ini -n %i
EOF

cat > /usr/lib/systemd/system/distrbox-autostart@.service <<EOF
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
EOF

mkdir -p /usr/etc/systemd/system/distrobox-autostart@.service.d
cat > /usr/etc/systemd/system/distrobox-autostart@.service.d/override.conf <<EOF
[Service]
Environment=HOME=/home/m2
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
EOF

# Groups
groupadd -g 250 incus-admin
groupadd -g 251 incus
groupadd -g 252 docker

# Individual Changes
case  "${IMAGE}" in
    "bluefin")
        sed -i '/^PRETTY_NAME/s/Bluefin/m2os-bluefin/' /usr/lib/os-release
        sed -i '/image-tag/s/stable/bluefin/' /usr/share/ublue-os/image-info.json
        ;;
    "aurora")
        sed -i '/^PRETTY_NAME/s/Aurora/m2os-aurora/' /usr/lib/os-release
        sed -i '/image-tag/s/stable/aurora/' /usr/share/ublue-os/image-info.json
        ;;
    "bazzite-gnome-nvidia")
        sed -i '/^PRETTY_NAME/s/Bazzite GNOME/m2os-bazzite/' /usr/lib/os-release
        sed -i '/image-tag/s/stable/gaming-desktop' /usr/share/ublue-os/image-info.json
        systemctl enable sunshine-workaround.service
        curl -Lo /usr/libexec/ublue-bling.sh \
            https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/usr/libexec/ublue-bling.sh
        chmod +x /usr/libexec/ublue-bling.sh
        mkdir -p /usr/share/ublue-os/{bluefin-cli,homebrew}
        curl -Lo /usr/share/ublue-os/homebrew/bluefin-cli.Brewfile \
            https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/usr/share/ublue-os/homebrew/bluefin-cli.Brewfile
        curl -Lo /usr/share/ublue-os/bluefin-cli/bling.sh \
            https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/usr/share/ublue-os/bluefin-cli/bling.sh
        curl -Lo /usr/share/ublue-os/bluefin-cli/bling.fish \
            https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/usr/share/ublue-os/bluefin-cli/bling.fish
        cat >> /usr/share/ublue-os/just/80-bazzite.just <<EOF

# Bluefin-CLI Bling
bluefin-cli:
    @/usr/libexec/ublue-bling.sh
EOF
        ;;
esac

# Branding
cat <<< "$(jq '."image-name" |= "m2os" |
             ."image-vendor" |= "m2giles" |
             ."image-ref" |= "ostree-image-signed:docker://ghcr.io/m2giles/m2os"' \
             < /usr/share/ublue-os/image-info.json)" \
             > /tmp/image-info.json
cp /tmp/image-info.json /usr/share/ublue-os/image-info.json

sed -i '/^image-vendor/s/ublue-os/m2giles/' /usr/share/ublue-os/image-info.json

# Signing
cat <<< "$(jq '.transports.docker |=. + {
   "ghcr.io/m2giles/m2os": [
    {
        "type": "sigstoreSigned",
        "keypath": "/etc/pki/containers/m2os.pub",
        "signedIdentity": {
            "type": "matchRepository"
        }
    }
]}' < "/usr/etc/containers/policy.json")" > "/tmp/policy.json"
cp /tmp/policy.json /usr/etc/containers/policy.json
cp /tmp/cosign.pub /usr/etc/pki/containers/m2os.pub

systemctl enable --global p11-kit-server.socket
systemctl enable --global p11-kit-server.service

mkdir -p /usr/share/user-tmpfiles.d
cat > /usr/share/user-tmpfiles.d/discord-rpc.conf <<EOF
L %t/discord-ipc-0 - - - - app/com.discordapp.Discord/discord-ipc-0
EOF

cat > /usr/lib/tmpfiles.d/flatpak-overrides.conf<<EOF
L %S/flatpak/overrides/com.google.Chrome - - - - /usr/share/flatpak/overrides/com.google.Chrome
L %S/flatpak/overrides/com.microsoft.Edge - - - - /usr/share/flatpak/overrides/com.microsoft.Edge
L %S/flatpak/overrides/org.mozzila.firefox - - - - /usr/share/flatpak/overrides/org.mozzila.firefox
L %S/flatpak/overrides/org.mozzila.Thunderbird - - - - /usr/share/flatpak/overrides/org.mozzila.Thunderbird
L %S/flatpak/overrides/com.discordapp.Discord - - - - /usr/share/flatpak/overrides/com.discordapp.Discord
EOF

mkdir -p /usr/share/flatpak/overrides

cat > /usr/share/flatpak/overrides/com.google.Chrome <<EOF
[Context]
filesystems=~/.local/share/icons:create;~/.local/share/applications:create;xdg-run/p11-kit/pkcs11;~/.pki:create;
EOF

cat > /usr/share/flatpak/overrides/com.microsoft.Edge <<EOF
[Context]
filesystems=~/.local/share/icons:create;~/.local/share/applications:create;xdg-run/p11-kit/pkcs11;~/.pki:create;
EOF

cat > /usr/share/flatpak/overrides/org.mozilla.firefox <<EOF
[Context]
filesystems=xdg-run/p11-kit/pkcs11;

[Environment]
MOZ_ENABLE_WAYLAND=1
EOF

cat > /usr/share/flatpak/overrides/org.mozilla.Thunderbird <<EOF
[Context]
filesystems=xdg-run/p11-kit/pkcs11;

[Environment]
MOZ_ENABLE_WAYLAND=1
EOF

cat > /usr/share/flatpak/overrides/com.discordapp.Discord <<EOF
[Context]
sockets=wayland;
EOF
