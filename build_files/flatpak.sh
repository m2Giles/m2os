#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

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
ConditionPathExists=!/etc/.%N.stamp
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/libexec/m2os-flatpak-overrides.sh
ExecStop=/usr/bin/touch /etc/.%N.stamp

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
