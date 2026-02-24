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
if [[ $IMAGE_FLAVOR =~ "nvidia" ]] && [ "$(grep -o "\-display" <<< "$(lshw -C display)" | wc -l)" -le 1 ] && grep -q "vendor: NVIDIA Corporation" <<< "$(lshw -C display)"; then
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
    --filesystem=xdg-run/p11-kit/pkcs11:ro \
    --env=MOZ_ENABLE_WAYLAND=1 \
    --env=MOZ_USE_XINPUT2=1 \
    org.mozilla.Thunderbird

# LibreOffice
flatpak override \
    --system \
    --socket=cups \
    --socket=session-bus \
    org.libreoffice.LibreOffice

# Discord
flatpak override \
    --system \
    --socket=wayland \
    com.discordapp.Discord

# VSCode
flatpak override \
    --system \
    --socket=wayland \
    --filesystem=xdg-run/podman:ro \
    --filesystem=/run/docker-host:ro \
    --filesystem=/run/podman-host:ro \
    --filesystem=~/.var/app/sh.loft.devpod/data/devpod-cli:ro \
    --filesystem=/tmp \
    com.visualstudio.code

# DevPod
flatpak override \
    --system \
    --socket=wayland \
    --filesystem=/run/docker-host:ro \
    --filesystem=/run/podman-host:ro \
    --env=WEBKIT_DISABLE_COMPOSITING_MODE=1 \
    sh.loft.devpod
