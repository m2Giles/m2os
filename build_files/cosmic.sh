#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

# Add Cosmic Repo
if [[ "${IMAGE}" =~ beta ]]; then
    dnf5 -y copr enable ryanabx/cosmic-epoch
fi

# Add Staging repo
dnf5 -y copr enable ublue-os/staging

# Ublue Packages
dnf5 -y copr enable ublue-os/packages

# Add Nerd Fonts Repo
dnf5 -y copr enable che/nerd-fonts

# Enable Charm/Tailscale Repos
dnf5 config-manager setopt charm.enabled=1 tailscale-stable.enabled=1

# Cosmic Packages
PACKAGES=(
    NetworkManager-openvpn
    cosmic-files
    cosmic-initial-setup
    cosmic-player
    cosmic-session
    cosmic-store
    cosmic-term
    distrobox
    fedora-release-cosmic-atomic
    fedora-release-identity-cosmic-atomic
    flatpak
    gdisk
    gnome-disk-utility
    gnome-keyring
    gnome-keyring-pam
    playerctl
    plymouth-system-theme
    pop-launcher
    system-config-printer
    toolbox
    xdg-desktop-portal-gtk
)

# Bluefin Packages
PACKAGES+=(
    adcli
    adw-gtk3-theme
    alsa-firmware
    bash-color-prompt
    bcache-tools
    bootc
    borgbackup
    cascadia-code-fonts
    clevis
    cryfs
    davfs2
    ddcutil
    evolution-data-server
    evolution-ews-core
    evtest
    fastfetch
    firewall-config
    fish
    flatpak-spawn
    foo2zjs
    fuse-encfs
    git-credential-libsecret
    glow
    gnupg2-scdaemon
    gum
    gvfs
    gvfs-archive
    gvfs-fuse
    gvfs-nfs
    gvfs-smb
    hplip
    ibus-mozc
    ifuse
    igt-gpu-tools
    iwd
    krb5-workstation
    libavcodec
    libcamera-gstreamer
    libcamera-tools
    libinput-utils
    libsss_autofs
    libwacom
    libwacom-data
    libwacom-utils
    libxcrypt-compat
    lm_sensors
    lsb_release
    make
    mesa-libGLU
    mozc
    nerd-fonts
    oddjob-mkhomedir
    openssh-askpass
    pam-u2f
    pam_yubico
    pulseaudio-utils
    rclone
    restic
    samba
    samba-dcerpc
    samba-ldb-ldap-modules
    samba-winbind-clients
    samba-winbind-modules
    setools-console
    sssd-ad
    sssd-krb5
    sssd-nfs-idmap
    symlinks
    tailscale
    tmux
    topgrade
    tuned
    tuned-gtk
    tuned-ppd
    tuned-profiles-atomic
    usbip
    usbmuxd
    wireguard-tools
    wl-clipboard
    yubikey-manager
)

# FWUPD
dnf5 swap -y \
    --repo=copr:copr.fedorainfracloud.org:ublue-os:staging \
    fwupd fwupd

dnf5 install -y --allowerasing \
    --setopt=install_weak_deps=False \
    "${PACKAGES[@]}"

# Remove Unneeded and Disable Repos
UNINSTALL_PACKAGES=(
    firefox
    firefox-langpacks
)

dnf5 remove -y "${UNINSTALL_PACKAGES[@]}"
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo

# Starship Shell Prompt
ghcurl "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/starship.tar.gz
tar -xzf /tmp/starship.tar.gz -C /tmp
install -c -m 0755 /tmp/starship /usr/bin

# Systemd
systemctl enable cosmic-greeter
systemctl --global enable podman-auto-update.timer

# Hide Desktop Files. Hidden removes mime associations
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/htop.desktop
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/nvtop.desktop
