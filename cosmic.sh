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
    adcli
    borgbackup
    bootc
    cascadia-code-fonts
    evtest
    fastfetch
    firewall-config
    foo2zjs
    gcc
    git-credential-libsecret
    glow
    gum
    hplip
    krb5-workstation
    ifuse
    input-leap
    input-remapper
    libimobiledevice
    libxcrypt-compat
    libsss_autofs
    lm_sensors
    make
    mesa-libGLU
    nerd-fonts
    oddjob-mkhomedir
    ptyxis
    pulseaudio-utils
    python3-pip
    restic
    samba-dcerpc
    samba-ldb-ldap-modules
    samba-winbind-clients
    samba-winbind-modules
    samba
    setools-console
    solaar
    sssd-ad
    sssd-ipa
    sssd-krb5
    sssd-nfs-idmap
    stress-ng
    tailscale
    usbmuxd
    wireguard-tools
    xprop
    wl-clipboard
    zsh
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
KERNEL_TARGZ=$(jq -r '.layers[].digest' < /tmp/kernel-rpms/manifest.json | cut -d : -f 2)
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
AKMODS_TARGZ=$(jq -r '.layers[].digest' < /tmp/akmods/manifest.json | cut -d : -f 2)
tar -xvzf /tmp/akmods/"$AKMODS_TARGZ" -C /tmp/
mv /tmp/rpms/* /tmp/akmods/

AKMODS_RPMS=(
    /tmp/akmods/kmods/*xone*.rpm
    /tmp/akmods/kmods/*openrazer*.rpm
    /tmp/akmods/kmods/*v4l2loopback*.rpm
    v4l2loopback
)

# Fetch ZFS
if [[ "${KERNEL_FLAVOR}" == "coreos-stable" ]]; then
    skopeo copy docker://ghcr.io/ublue-os/akmods-zfs:coreos-stable-"$(rpm -E %fedora)"-"${QUALIFIED_KERNEL}" dir:/tmp/akmods-zfs
    ZFS_TARGZ=$(jq -r '.layers[].digest' < /tmp/akmods-zfs/manifest.json | cut -d : -f 2)
    tar -xvzf /tmp/akmods-zfs/"$ZFS_TARGZ" -C /tmp/
    mv /tmp/rpms/* /tmp/akmods-zfs/
    echo "zfs" > /usr/lib/modules-load.d/zfs.conf

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

# Nvidia Modprobe and Dracut
echo "options nvidia NVreg_TemporaryFilePath=/var/tmp" >> /usr/lib/modprobe.d/nvidia-atomic.conf

tee /usr/lib/modprobe.d/nvidia-modeset.conf <<'EOF'
# Nvidia modesetting support. Set to 0 or comment to disable kernel modesetting
# support. This must be disabled in case of SLI Mosaic.

options nvidia-drm modeset=1 fbdev=1
EOF

echo 'force_drivers+=" nvidia nvidia-drm nvidia-modeset nvidia-peermem nvidia-uvm "' >> /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

# Fetch Nvidia or Delete Nvidia Configs
if [[ "${IMAGE}" =~ cosmic-nvidia ]]; then

    skopeo copy docker://ghcr.io/ublue-os/akmods-nvidia:${KERNEL_FLAVOR}-"$(rpm -E %fedora)"-"${QUALIFIED_KERNEL}" dir:/tmp/akmods-rpms
    NVIDIA_TARGZ=$(jq -r '.layers[].digest' < /tmp/akmods-rpms/manifest.json | cut -d : -f 2)
    tar -xvzf /tmp/akmods-rpms/"$NVIDIA_TARGZ" -C /tmp/
    mv /tmp/rpms/* /tmp/akmods-rpms/
    dnf5 install -y /tmp/akmods-rpms/ublue-os/ublue-os-nvidia-addons-*.rpm

    # Enable Repos
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/nvidia-container-toolkit.repo

    source /tmp/akmods-rpms/kmods/nvidia-vars

    NVIDIA_RPMS=(
        libnvidia-fbc
        libnvidia-ml.i686
        libva-nvidia-driver
        mesa-vulkan-drivers.i686
        nvidia-driver
        nvidia-driver-cuda
        nvidia-driver-cuda-libs.i686
        nvidia-driver-libs.i686
        nvidia-modprobe
        nvidia-persistenced
        nvidia-settings
        nvidia-container-toolkit
        "/tmp/akmods-rpms/kmods/kmod-nvidia-${KERNEL_VERSION}-${NVIDIA_AKMOD_VERSION}.fc${RELEASE}.rpm"
    )
else
    rm -f /usr/lib/modprobe.d/nvidia-{modeset,atomic}.conf
    rm -f /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
fi

# Delete Kernel Packages for Install
for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra
do
    rpm --erase $pkg --nodeps
done

# Enable Repo
sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo

# Install
dnf5 install -y "${PACKAGES[@]}" "${KERNEL_RPMS[@]}" "${NVIDIA_RPMS[@]}" "${AKMODS_RPMS[@]}" "${ZFS_RPMS[@]}"
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

if [[ "${IMAGE}" =~ cosmic-nvidia ]]; then
    # Disable Repos
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/nvidia-container-toolkit.repo

    # Correct Flavor
    sed -i "s/^MODULE_VARIANT=.*/MODULE_VARIANT=$KERNEL_MODULE_TYPE/" /etc/nvidia/kernel.conf

    # Enable Services
    systemctl enable nvidia-persistenced.service ublue-nvctk-cdi.service

    # SELinux
    semodule --verbose --install /usr/share/selinux/packages/nvidia-container.pp
fi

# Starship Shell Prompt
curl -Lo /tmp/starship.tar.gz "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz"
tar -xzf /tmp/starship.tar.gz -C /tmp
install -c -m 0755 /tmp/starship /usr/bin
# shellcheck disable=SC2016
echo 'eval "$(starship init bash)"' >> /etc/bashrc

# Bash Prexec
curl -Lo /usr/share/bash-prexec https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh

# Topgrade Install
pip install --prefix=/usr topgrade

# Install ublue-update
dnf5 install -y ublue-update
mkdir -p /etc/ublue-update
tee /etc/ublue-update/ublue-update.toml <<'EOF'
[checks]
    min_battery_percent = 20.0
    max_cpu_load_percent = 50.0
    max_mem_percent = 90.0
    network_not_metered = true  # Abort if network connection is metered
[notify]
    dbus_notify = false
EOF

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

echo 'd /var/home/linuxbrew 0755 1000 1000 - -' >> /usr/lib/tmpfiles.d/homebrew.conf

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
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/fish.desktop
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/htop.desktop
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/nvtop.desktop

#Disable autostart behaviour
rm -f /etc/xdg/autostart/solaar.desktop
