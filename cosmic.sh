#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

if [[ -z "${KERNEL_FLAVOR:-}" ]]; then
    KERNEL_FLAVOR=coreos-stable
fi

# Get Kernel Version
QUALIFIED_KERNEL=$(skopeo inspect docker://ghcr.io/ublue-os/"${KERNEL_FLAVOR}"-kernel:"$(rpm -E %fedora)" | jq -r '.Labels["ostree.linux"]')

# Add Cosmic Repo
dnf5 -y copr enable ryanabx/cosmic-epoch

# Add Staging repo
dnf5 -y copr enable ublue-os/staging

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
    cosmic-desktop
    gnome-keyring
    NetworkManager-openvpn
    power-profiles-daemon
)

# Bluefin Packages
PACKAGES+=(
    cascadia-code-fonts
    clevis
    evtest
    fastfetch
    firewall-config
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
    samba-dcerpc
    samba-ldb-ldap-modules
    samba-winbind-clients
    samba-winbind-modules
    samba
    setools-console
    solaar
    tailscale
    topgrade
    usbmuxd
    uupd
    wireguard-tools
    wl-clipboard
)

RPM_FUSION=(
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-"$(rpm -E %fedora)".noarch.rpm
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"$(rpm -E %fedora)".noarch.rpm
)

dnf5 install -y "${RPM_FUSION[@]}"

# FWUPD
dnf5 swap -y \
    --repo=copr:copr.fedorainfracloud.org:ublue-os:staging \
    fwupd fwupd

# Fetch Kernel
skopeo copy docker://ghcr.io/ublue-os/"${KERNEL_FLAVOR}"-kernel:"$(rpm -E %fedora)"-"${QUALIFIED_KERNEL}" dir:/tmp/kernel-rpms
KERNEL_TARGZ=$(jq -r '.layers[].digest' </tmp/kernel-rpms/manifest.json | cut -d : -f 2)
tar -xvzf /tmp/kernel-rpms/"$KERNEL_TARGZ" -C /
mv /tmp/rpms/* /tmp/kernel-rpms/

KERNEL_RPMS=(
    "/tmp/kernel-rpms/kernel-${QUALIFIED_KERNEL}.rpm"
    "/tmp/kernel-rpms/kernel-core-${QUALIFIED_KERNEL}.rpm"
    "/tmp/kernel-rpms/kernel-modules-${QUALIFIED_KERNEL}.rpm"
    "/tmp/kernel-rpms/kernel-modules-core-${QUALIFIED_KERNEL}.rpm"
    "/tmp/kernel-rpms/kernel-modules-extra-${QUALIFIED_KERNEL}.rpm"
    "/tmp/kernel-rpms/kernel-uki-virt-${QUALIFIED_KERNEL}.rpm"
)

# Fetch AKMODS
skopeo copy docker://ghcr.io/ublue-os/akmods:"${KERNEL_FLAVOR}"-"$(rpm -E %fedora)"-"${QUALIFIED_KERNEL}" dir:/tmp/akmods
AKMODS_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods/manifest.json | cut -d : -f 2)
tar -xvzf /tmp/akmods/"$AKMODS_TARGZ" -C /tmp/
mv /tmp/rpms/* /tmp/akmods/

AKMODS_RPMS=(
    /tmp/akmods/kmods/*xone*.rpm
    /tmp/akmods/kmods/*v4l2loopback*.rpm
    v4l2loopback
)

# Fetch ZFS
if [[ "${KERNEL_FLAVOR}" =~ coreos ]]; then
    skopeo copy docker://ghcr.io/ublue-os/akmods-zfs:"${KERNEL_FLAVOR}"-"$(rpm -E %fedora)"-"${QUALIFIED_KERNEL}" dir:/tmp/akmods-zfs
    ZFS_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods-zfs/manifest.json | cut -d : -f 2)
    tar -xvzf /tmp/akmods-zfs/"$ZFS_TARGZ" -C /tmp/
    mv /tmp/rpms/* /tmp/akmods-zfs/
    echo "zfs" >/usr/lib/modules-load.d/zfs.conf

    ZFS_RPMS=(
        /tmp/akmods-zfs/kmods/zfs/kmod-zfs-"${QUALIFIED_KERNEL}"-*.rpm
        /tmp/akmods-zfs/kmods/zfs/libnvpair3-*.rpm
        /tmp/akmods-zfs/kmods/zfs/libuutil3-*.rpm
        /tmp/akmods-zfs/kmods/zfs/libzfs5-*.rpm
        /tmp/akmods-zfs/kmods/zfs/libzpool5-*.rpm
        /tmp/akmods-zfs/kmods/zfs/python3-pyzfs-*.rpm
        /tmp/akmods-zfs/kmods/zfs/zfs-*.rpm
        pv
    )
else
    ZFS_RPMS=()
fi

# Delete Kernel Packages for Install
for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra; do
    rpm --erase $pkg --nodeps
done

# Enable Repo
sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo

# Install
dnf5 install -y "${PACKAGES[@]}" "${KERNEL_RPMS[@]}" "${AKMODS_RPMS[@]}" "${ZFS_RPMS[@]}"

# Fetch Nvidia
if [[ "${IMAGE}" =~ cosmic-nvidia ]]; then
    skopeo copy docker://ghcr.io/ublue-os/akmods-nvidia:"${KERNEL_FLAVOR}"-"$(rpm -E %fedora)"-"${QUALIFIED_KERNEL}" dir:/tmp/akmods-rpms
    dnf5 config-manager setopt fedora-multimedia.enabled=0
    dnf5 config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
    NVIDIA_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods-rpms/manifest.json | cut -d : -f 2)
    tar -xvzf /tmp/akmods-rpms/"$NVIDIA_TARGZ" -C /tmp/
    mv /tmp/rpms/* /tmp/akmods-rpms/
    # Install Nvidia RPMs
    curl -Lo /tmp/nvidia-install.sh https://raw.githubusercontent.com/ublue-os/hwe/main/nvidia-install.sh
    sed -i "s/rpm-ostree install/dnf install -y/" /tmp/nvidia-install.sh
    chmod +x /tmp/nvidia-install.sh
    IMAGE_NAME="" RPMFUSION_MIRROR="" /tmp/nvidia-install.sh
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json
    ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so
    dnf5 config-manager setopt fedora-multimedia.enabled=1 fedora-nvidia.enabled=0
fi

depmod -a -v "${QUALIFIED_KERNEL}"

# Remove Unneeded and Disable Repos
UNINSTALL_PACKAGES=(
    firefox
    firefox-langpacks
    rpmfusion-free-release
    rpmfusion-nonfree-release
)

dnf5 remove -y "${UNINSTALL_PACKAGES[@]}"
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo

# Starship Shell Prompt
curl -Lo /tmp/starship.tar.gz "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz"
tar -xzf /tmp/starship.tar.gz -C /tmp
install -c -m 0755 /tmp/starship /usr/bin
# shellcheck disable=SC2016
echo 'eval "$(starship init bash)"' >>/etc/bashrc

# Convince the installer we are in CI
touch /.dockerenv

# Make these so script will work
mkdir -p /var/home
mkdir -p /var/roothome

# Brew Install Script
curl -Lo /tmp/brew-install https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
chmod +x /tmp/brew-install
/tmp/brew-install
tar --zstd -cvf /usr/share/homebrew.tar.zst /home/linuxbrew/.linuxbrew
mkdir -p /etc/security/limits.d
tee /etc/security/limits.d/30-brew-limits.conf <<'EOF'
#This file sets the resource limits for the users logged in via PAM,
#more specifically, users logged in on via SSH or tty (console).
#Limits related to terminals in Wayland/Xorg sessions depend on a
#change to /etc/systemd/user.conf.
#This does not affect resource limits of the system services.
#This file overrides defaults set in /etc/security/limits.conf

* soft nofile 4096
root soft nofile 4096
EOF

# Brew Services
curl -Lo /usr/lib/systemd/system/brew-setup.service \
    https://raw.githubusercontent.com/ublue-os/bluefin/refs/heads/main/system_files/shared/usr/lib/systemd/system/brew-setup.service
curl -Lo /usr/lib/systemd/system/brew-update.service \
    https://raw.githubusercontent.com/ublue-os/bluefin/refs/heads/main/system_files/shared/usr/lib/systemd/system/brew-update.service
curl -Lo /usr/lib/systemd/system/brew-upgrade.service \
    https://raw.githubusercontent.com/ublue-os/bluefin/refs/heads/main/system_files/shared/usr/lib/systemd/system/brew-upgrade.service
curl -Lo /usr/lib/systemd/system/brew-update.timer \
    https://raw.githubusercontent.com/ublue-os/bluefin/refs/heads/main/system_files/shared/usr/lib/systemd/system/brew-update.timer
curl -Lo /usr/lib/systemd/system/brew-upgrade.timer \
    https://raw.githubusercontent.com/ublue-os/bluefin/refs/heads/main/system_files/shared/usr/lib/systemd/system/brew-upgrade.timer

echo 'd /var/home/linuxbrew 0755 1000 1000 - -' >>/usr/lib/tmpfiles.d/homebrew.conf

tee /etc/profile.d/brew-bash-completion.sh <<'EOF'
#!/bin/sh
# shellcheck shell=sh disable=SC1091,SC2039,SC2166
# Check for interactive bash and that we haven't already been sourced.
if [ "x${BASH_VERSION-}" != x -a "x${PS1-}" != x -a "x${BREW_BASH_COMPLETION-}" = x ]; then

    # Check for recent enough version of bash.
    if [ "${BASH_VERSINFO[0]}" -gt 4 ] ||
        [ "${BASH_VERSINFO[0]}" -eq 4 -a "${BASH_VERSINFO[1]}" -ge 2 ]; then
        if [ -w /home/linuxbrew/.linuxbrew ]; then
            if ! test -L /home/linuxbrew/.linuxbrew/etc/bash_completion.d/brew; then
                /home/linuxbrew/.linuxbrew/bin/brew completions link > /dev/null
            fi
        fi
        if test -d /home/linuxbrew/.linuxbrew/etc/bash_completion.d; then
            for rc in /home/linuxbrew/.linuxbrew/etc/bash_completion.d/*; do
                if test -r "$rc"; then
                . "$rc"
                fi
            done
            unset rc
        fi
    fi
    BREW_BASH_COMPLETION=1
    export BREW_BASH_COMPLETION
fi
EOF

# Systemd
systemctl enable cosmic-greeter
systemctl enable power-profiles-daemon
systemctl enable brew-setup.service
systemctl enable brew-upgrade.timer
systemctl enable brew-update.timer
systemctl --global enable podman-auto-update.timer

# Hide Desktop Files. Hidden removes mime associations
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/htop.desktop
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/nvtop.desktop

#Disable autostart behaviour
rm -f /etc/xdg/autostart/solaar.desktop
