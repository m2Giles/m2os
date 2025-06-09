#!/usr/bin/bash

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

# Add Charm Repo
tee /etc/yum.repos.d/charm.repo <<'EOF'
[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key
EOF

# Add Tailscale Repo
dnf5 config-manager addrepo --from-repofile https://pkgs.tailscale.com/stable/fedora/tailscale.repo

# Cosmic Packages
PACKAGES=(
    NetworkManager-openvpn
    cosmic-edit
    cosmic-files
    cosmic-player
    cosmic-session
    cosmic-store
    cosmic-term
    distrobox
    flatpak
    gdisk
    gnome-disk-utility
    gnome-keyring
    gnome-keyring-pam
    plymouth-system-theme
    toolbox
)

# Bluefin Packages
PACKAGES+=(
    "bluefin-*"
    adcli
    adw-gtk3-theme
    bash-color-prompt
    bcache-tools
    bootc
    borgbackup
    cascadia-code-fonts
    clevis
    evtest
    fastfetch
    firewall-config
    fish
    foo2zjs
    git-credential-libsecret
    glow
    gum
    hplip
    libxcrypt-compat
    lm_sensors
    mesa-libGLU
    nerd-fonts
    oddjob-mkhomedir
    ptyxis
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
    tailscale
    tmux
    topgrade
    tuned
    tuned-gtk
    tuned-ppd
    tuned-profiles-atomic
    ublue-bling
    ublue-brew
    ublue-fastfetch
    ublue-setup-services
    usbmuxd
    wireguard-tools
    wl-clipboard
)

# FWUPD
dnf5 swap -y \
    --repo=copr:copr.fedorainfracloud.org:ublue-os:staging \
    fwupd fwupd

dnf5 install -y --allowerasing \
    --setopt=install_weak_deps=False \
    -x bluefin-readymade-config \
    "${PACKAGES[@]}"

# Remove Unneeded and Disable Repos
UNINSTALL_PACKAGES=(
    firefox
    firefox-langpacks
)

dnf5 remove -y "${UNINSTALL_PACKAGES[@]}"
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo

# Starship Shell Prompt
curl -Lo /tmp/starship.tar.gz "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz"
tar -xzf /tmp/starship.tar.gz -C /tmp
install -c -m 0755 /tmp/starship /usr/bin
# shellcheck disable=SC2016
echo 'eval "$(starship init bash)"' >>/etc/bashrc

# Systemd
systemctl enable cosmic-greeter
systemctl --global enable podman-auto-update.timer

# Hide Desktop Files. Hidden removes mime associations
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/htop.desktop
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/nvtop.desktop
