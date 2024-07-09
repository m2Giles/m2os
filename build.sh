#!/usr/bin/bash

set -eoux pipefail

# Global Environment Variables

tee -a /etc/environment <<EOF
EDITOR=/usr/bin/vim
VISUAL=/usr/bin/emacs
EOF

# VSCode because it's still better for a lot of things
curl -Lo /etc/yum.repos.d/vscode.repo \
    https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/dx/etc/yum.repos.d/vscode.repo

# Sunshine
curl -Lo /etc/yum.repos.d/_copr_matte-schwartz-sunshine.repo \
    https://copr.fedorainfracloud.org/coprs/matte-schwartz/sunshine/repo/fedora-"${FEDORA_VERSION}"/matte-schwartz-sunshine-fedora-"${FEDORA_VERSION}".repo

curl -Lo /usr/lib/systemd/system/sunshine-workaround.service \
    https://raw.githubusercontent.com/ublue-os/bazzite/main/system_files/desktop/shared/usr/lib/systemd/system/sunshine-workaround.service

systemctl enable sunshine-workaround.service

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

echo 'volume="/lib/modules:/lib/modules:ro"' | tee -a /tmp/docker.ini

if [[ -f $(find /usr/lib/modules/*/extra/zfs/zfs.ko 2> /dev/null) ]]; then
    echo 'additional_packages="zfsutils-linux"' | tee -a /tmp/incus.ini
    echo 'additional_packages="zfsutils-linux"' | tee -a /tmp/docker.ini
fi

tee /tmp/fedora.ini <<EOF
[fedora]
image=ghcr.io/ublue-os/fedora-toolbox:latest
nvidia=true
entry=false
volume="/home/linuxbrew/:/home/linuxbrew:rslave"
EOF

tee /tmp/ubuntu.ini <<EOF
[fedora]
image=ghcr.io/ublue-os/ubuntu-toolbox:latest
nvidia=true
entry=false
volume="/home/linuxbrew/:/home/linuxbrew:rslave"
EOF

mkdir -p /usr/etc/distrobox/

tee -a /usr/etc/distrobox/distrobox.ini < /tmp/incus.ini
printf "\n" | tee -a /usr/etc/distrobox/distrobox.ini
tee -a /usr/etc/distrobox/distrobox.ini < /tmp/docker.ini
printf "\n" | tee -a /usr/etc/distrobox/distrobox.ini
tee -a /usr/etc/distrobox/distrobox.ini < /tmp/fedora.ini
printf "\n" | tee -a /usr/etc/distrobox/distrobox.ini
tee -a /usr/etc/distrobox/distrobox.ini < /tmp/ubuntu.ini

tee /usr/etc/distrobox/distrobox.conf <<'EOF'
container_always_pull=false
container_generate_entry=false
container_manager="podman"
distrobox_sudo_program="/usr/bin/systemd-run --uid=0 --gid=0 -d -E TERM="$TERM" -t -q -P -G"
EOF

tee /usr/lib/systemd/system/distrbox-assemble@.service <<EOF
[Unit]
Description=Distrobox Assemble %i
Requires=network-online.target local-fs.target
After=network-online.target local-fs.target

[Service]
User=1000
Type=oneshot
ExecStart=/usr/bin/distrobox-assemble create --file /usr/etc/distrobox/distrobox.ini -n %i
EOF

tee /usr/lib/systemd/system/distrbox-autostart@.service <<EOF
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
tee /usr/etc/systemd/system/distrobox-autostart@.service.d/override.conf <<EOF
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
case "${IMAGE}" in
    "bluefin"*)
        sed -i '/^PRETTY_NAME/s/Bluefin/m2os-bluefin/' /usr/lib/os-release
        sed -i "/image-tag/s/stable/${IMAGE}/" /usr/share/ublue-os/image-info.json
        ;;
    "aurora"*)
        sed -i '/^PRETTY_NAME/s/Aurora/m2os-aurora/' /usr/lib/os-release
        sed -i "/image-tag/s/stable/${IMAGE}/" /usr/share/ublue-os/image-info.json
        ;;
    "bazzite-deck"*)
        sed -i '/^PRETTY_NAME/s/"Bazzite GNOME"/m2os-bazzite-deck/' /usr/lib/os-release
        sed -i "/image-tag/s/stable/bazzite-deck/" /usr/share/ublue-os/image-info.json
        /tmp/bazzite.sh
        ;;
    "bazzite-gnome"*)
        sed -i '/^PRETTY_NAME/s/"Bazzite GNOME"/m2os-bazzite/' /usr/lib/os-release
        sed -i "/image-tag/s/stable/bazzite/" /usr/share/ublue-os/image-info.json
        /tmp/bazzite.sh
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

# # Signing
# cat <<< "$(jq '.transports.docker |=. + {
#    "ghcr.io/m2giles/m2os": [
#     {
#         "type": "sigstoreSigned",
#         "keyPath": "/etc/pki/containers/m2os.pub",
#         "signedIdentity": {
#             "type": "matchRepository"
#         }
#     }
# ]}' < "/usr/etc/containers/policy.json")" > "/tmp/policy.json"
# cp /tmp/policy.json /usr/etc/containers/policy.json
cp /tmp/cosign.pub /usr/etc/pki/containers/m2os.pub
tee /usr/etc/containers/registries.d/m2os.yaml <<EOF
docker:
  ghcr.io/m2giles/m2os:
    use-sigstore-attachments: true
EOF

systemctl enable --global p11-kit-server.socket
systemctl enable --global p11-kit-server.service

mkdir -p /usr/share/user-tmpfiles.d
tee /usr/share/user-tmpfiles.d/discord-rpc.conf <<EOF
L %t/discord-ipc-0 - - - - app/com.discordapp.Discord/discord-ipc-0
EOF

tee /usr/share/user-tmpfiles.d/keepassxc-integration.conf <<EOF
C %h/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json - - - - /run/keepassxc-integration/firefox-keepassxc.json
C %h/.var/app/com.google.Chrome/config/google-chrome/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json - - - - /run/keepassxc-integration/chromium-keepassxc.json
C %h/.var/app/com.microsoft.Edge/config/microsoft-edge/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json - - - - /run/keepassxc-integration/chromium-keepassxc.json
EOF

tee /usr/lib/tmpfiles.d/keepassxc-integration.conf <<EOF
C %t/keepassxc-integration - - - - /usr/libexec/keepassxc-integration
EOF

tee /usr/lib/systemd/system/m2os-flatpak-overrides.service <<EOF
[Unit]
Description=Set Overrides for Flatpaks
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/libexec/m2os-flatpak-overrides.sh

[Install]
WantedBy=default.target multi-user.target
EOF

tee /usr/libexec/m2os-flatpak-overrides.sh <<'EOF'
#!/usr/bin/bash

# Themeing Support
flatpak override \
    --system \
    --filesystem=xdg-config/gtk-4.0:ro \
    --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem=xdg-data/icons:ro

# Google Chrome
flatpak override \
    --system \
    --filesystem=~/.local/share/icons:create \
    --filesystem=~/.local/share/applications:create \
    --filesystem=~/.pki:create \
    --filesystem=xdg-run/p11-kit/pkcs11 \
    --filesystem=/run/keepassxc-integration \
    --filesystem=/var/lib/flatpak/app/org.keepassxc.KeePassXC:ro \
    --filesystem=/var/lib/flatpak/runtime/org.kde.Platform:ro \
    --filesystem=xdg-data/flatpak/app/org.keepassxc.KeePassXC:ro \
    --filesystem=xdg-data/flatpak/runtime/org.kde.Platform:ro \
    --filesystem=xdg-run/app/org.keepassxc.KeePassXC:create \
    com.google.Chrome

# Microsoft-Edge
flatpak override \
    --system \
    --filesystem=~/.pki:create \
    --filesystem=xdg-run/p11-kit/pkcs11 \
    --filesystem=/run/keepassxc-integration \
    --filesystem=/var/lib/flatpak/app/org.keepassxc.KeePassXC:ro \
    --filesystem=/var/lib/flatpak/runtime/org.kde.Platform:ro \
    --filesystem=xdg-data/flatpak/app/org.keepassxc.KeePassXC:ro \
    --filesystem=xdg-data/flatpak/runtime/org.kde.Platform:ro \
    --filesystem=xdg-run/app/org.keepassxc.KeePassXC:create \
    com.microsoft.Edge

# Mozilla Firefox
flatpak override \
    --system \
    --filesystem=xdg-run/p11-kit/pkcs11 \
    --filesystem=/run/keepassxc-integration \
    --filesystem=/var/lib/flatpak/app/org.keepassxc.KeePassXC:ro \
    --filesystem=/var/lib/flatpak/runtime/org.kde.Platform:ro \
    --filesystem=xdg-data/flatpak/app/org.keepassxc.KeePassXC:ro \
    --filesystem=xdg-data/flatpak/runtime/org.kde.Platform:ro \
    --filesystem=xdg-run/app/org.keepassxc.KeePassXC:create \
    --env=MOZ_ENABLE_WAYLAND=1 \
    --env=MOZ_USE_XINPUT2=1 \
    org.mozilla.firefox

# Firefox Nvidia
IMAGE_FLAVOR=$(jq -r '."image-flavor"' < /usr/share/ublue-os/image-info.json)
if [[ $IMAGE_FLAVOR =~ "nvidia" ]] && [ $(grep -o "\-display" <<< "$(lshw -C display)" | wc -l) -le 1 ] && grep -q "vendor: NVIDIA Corporation" <<< $(lshw -C display); then
  flatpak override \
    --system \
    --filesystem=host-os \
    --env=LIBVA_DRIVER_NAME=nvidia \
    --env=LIBVA_DRIVERS_PATH=/run/host/usr/lib64/dri \
    --env=LIBVA_MESSAGING_LEVEL=1 \
    --env=MOZ_DISABLE_RDD_SANDBOX=1 \
    --env=NVD_BACKEND=direct \
    org.mozilla.firefox
else
  # Undo if user was previously using a Nvidia image and is no longer
  flatpak override \
    --system \
    --nofilesystem=host-os \
    --unset-env=LIBVA_DRIVER_NAME \
    --unset-env=LIBVA_DRIVERS_PATH \
    --unset-env=LIBVA_MESSAGING_LEVEL \
    --unset-env=MOZ_DISABLE_RDD_SANDBOX \
    --unset-env=NVD_BACKEND \
    org.mozilla.firefox
fi

# Mozilla Thunderbird
flatpak override \
    --system \
    --filesystem=xdg-run/p11-kit/pkcs11 \
    --env=MOZ_ENABLE_WAYLAND=1 \
    --env=MOZ_USE_XINPUT2=1 \
    org.mozilla.Thunderbird

# LibreOffice
flatpak override \
    --system \
    --socket=cups \
    --socket=session-bus \
    org.libreoffice.LibreOffice

#Discord
flatpak override \
    --system \
    --socket=wayland
EOF
chmod +x /usr/libexec/m2os-flatpak-overrides.sh
systemctl enable m2os-flatpak-overrides.service

mkdir /usr/libexec/keepassxc-integration
tee /usr/libexec/keepassxc-integration/keepassxc-proxy-wrapper <<'EOF'
#!/usr/bin/bash

APP_REF="org.keepassxc.KeePassXC/x86_64/stable"

for inst in "/var/lib/flatpak/" "$HOME/.local/share/flatpak/"; do
    if [ -d "$inst/app/$APP_REF" ]; then
        FLATPAK_INST="$inst"
        break
    fi
done

[ -z "$FLATPAK_INST" ] && exit 1

APP_PATH="$FLATPAK_INST/app/$APP_REF/active"
RUNTIME_REF=$(awk -F'=' '$1=="runtime" { print $2 }' < "$APP_PATH/metadata")
RUNTIME_PATH="$FLATPAK_INST/runtime/$RUNTIME_REF/active"

exec flatpak-spawn \
    --env=LD_LIBRARY_PATH="/app/lib:$APP_PATH" \
    --app-path="$APP_PATH/files" \
    --usr-path="$RUNTIME_PATH/files" \
    -- keepassxc-proxy "$@"
EOF
chmod +x /usr/libexec/keepassxc-integration/keepassxc-proxy-wrapper

tee /usr/libexec/keepassxc-integration/firefox-keepassxc.json <<EOF
{
    "allowed_extensions": [
        "keepassxc-browser@keepassxc.org"
    ],
    "description": "KeePassXC integration with native messaging support",
    "name": "org.keepassxc.keepassxc_browser",
    "path": "/run/keepassxc-integration/keepassxc-proxy-wrapper",
    "type": "stdio"
}
EOF

tee /usr/libexec/keepassxc-integration/chromium-keepassxc.json <<EOF
{
    "allowed_origins": [
        "chrome-extension://pdffhmdngciaglkoonimfcmckehcpafo/",
        "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/"
    ],
    "description": "KeePassXC integration with native messaging support",
    "name": "org.keepassxc.keepassxc_browser",
    "path": "/run/keepassxc-integration/keepassxc-proxy-wrapper",
    "type": "stdio"
}
EOF
