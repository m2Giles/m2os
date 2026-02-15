#!/usr/bin/bash

set -eoux pipefail

IMAGE_INFO="$(cat /usr/share/ublue-os/image-info.json)"
IMAGE_TAG="$(jq -c -r '."image-tag"' <<<"$IMAGE_INFO")"
IMAGE_REF="$(jq -c -r '."image-ref"' <<<"$IMAGE_INFO")"
IMAGE_REF="${IMAGE_REF##*://}"
sbkey='https://github.com/ublue-os/akmods/raw/main/certs/public_key.der'

# Configure Live Environment
rm -f /etc/xdg/autostart/org.gnome.Software.desktop

mkdir -p /usr/share/glib-2.0/schemas/
tee /usr/share/glib-2.0/schemas/zz2-org.gnome.shell.gschema.override <<EOF
[org.gnome.shell]
welcome-dialog-last-shown-version='4294967295'
favorite-apps = ['anaconda.desktop', 'documentation.desktop', 'discourse.desktop', 'org.mozilla.firefox.desktop', 'org.gnome.Nautilus.desktop']
EOF

mkdir -p "$(dirname /usr/share/gnome-shell/search-providers/org.gnome.Software-search-provider.ini)"
tee /usr/share/gnome-shell/search-providers/org.gnome.Software-search-provider.ini <<EOF
DefaultDisabled=true
EOF

glib-compile-schemas /usr/share/glib-2.0/schemas

systemctl disable \
    rpm-ostree-countme.service \
    tailscaled.service \
    bootloader-update.service \
    brew-upgrade.timer \
    brew-update.timer \
    brew-setup.service \
    rpm-ostreed-automatic.timer \
    uupd.timer \
    ublue-system-setup.service \
    ublue-guest-user.service \
    check-sb-key.service

systemctl --global disable \
    ublue-flatpak-manager.service \
    podman-auto-update.timer \
    ublue-user-setup.service

SPECS=(
    "libblockdev-btrfs"
    "libblockdev-lvm"
    "libblockdev-dm"
    "anaconda-live"
    "anaconda-webui"
)

dnf5 versionlock delete NetworkManager NetworkManager-wifi NetworkManager-libnm
dnf5 install -y --allowerasing "${SPECS[@]}"

tee /etc/anaconda/profile.d/bluefin.conf <<'EOF'
# Anaconda Configuration Profile for Bluefin
[Profile]
# Define the profile
profile_id = bluefin

[Profile Detection]
os_id = bluefin

[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
efi_dir = fedora
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1
default_partitioning =
    /     (min 1 GiB, max 70 GiB)
    /home (min 500 MiB, free 50 GiB)
    /var  (btrfs)

[User Interface]
custom_stylesheet = /usr/share/anaconda/pixmaps/silverblue/fedora-silverblue.css
hidden_spokes =
    NetworkSpoke
    PasswordSpoke
    UserSpoke
hidden_webui_pages =
    anaconda-screen-accounts

[Localization]
use_geolocation = False
EOF

tee /etc/anaconda/profile.d/cosmic.conf <<'EOF'
# Anaconda Configuration Profile for Cosmic
[Profile]
# Define the profile
profile_id = cosmic
base_profile = bluefin

[Profile Detection]
os_id = Cosmic

[User Interface]
custom_stylesheet = /usr/share/anaconda/pixmaps/silverblue/fedora-silverblue.css
hidden_spokes =
    PasswordSpoke
EOF

tee /etc/anaconda/profile.d/aurora.conf <<'EOF'
# Anaconda Configuration Profile for Aurora
[Profile]
# Define the profile
profile_id = aurora
base_profile = bluefin

[Profile Detection]
os_id = aurora

[User Interface]
custom_stylesheet = /usr/share/anaconda/pixmaps/fedora.css
hidden_spokes =
    PasswordSpoke
EOF

tee /etc/anaconda/profile.d/bazzite.conf <<'EOF'
# Anaconda Configuration Profile for Bazzite
[Profile]
# Define the profile
profile_id = bazzite
base_profile = bluefin

[Profile Detection]
os_id = bazzite

[User Interface]
custom_stylesheet = /usr/share/anaconda/pixmaps/fedora.css
EOF

# TODO: Figure out what happened to branding
# mkdir -p /usr/share/anaconda/pixmaps/silverblue

# if [[ "$IMAGE_TAG" =~ aurora|bluefin|cosmic ]]; then
#     git clone --depth=1 https://github.com/ublue-os/packages.git /root/packages
# elif [[ "$IMAGE_TAG" =~ bazzite ]]; then
#     git clone --depth=1 https://github.com/ublue-os/bazzite.git /root/packages
# fi

# if [[ "$IMAGE_TAG" =~ bluefin|cosmic ]]; then
#     cp -r /root/packages/bluefin/fedora-logos/src/anaconda/* /usr/share/anaconda/pixmaps/silverblue/
# elif [[ "$IMAGE_TAG" =~ bazzite ]]; then
#     cp -r /root/packages/installer/branding/* /usr/share/anaconda/pixmaps/
# elif [[ "$IMAGE_TAG" =~ aurora ]]; then
#     cp -r /root/packages/aurora/fedora-logos/src/anaconda/* /usr/share/anaconda/pixmaps/
# fi
# rm -rf /root/packages

tee -a /usr/share/anaconda/interactive-defaults.ks <<EOF
ostreecontainer --url=$IMAGE_REF:$IMAGE_TAG --transport=containers-storage --no-signature-verification
%include /usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%include /usr/share/anaconda/post-scripts/disable-fedora-flatpak.ks
%include /usr/share/anaconda/post-scripts/install-flatpaks.ks
%include /usr/share/anaconda/post-scripts/secureboot-enroll-key.ks
EOF

tee /usr/share/anaconda/post-scripts/install-configure-upgrade.ks <<EOF
%post --erroronfail
bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry $IMAGE_REF:$IMAGE_TAG
%end
EOF

tee /usr/share/anaconda/post-scripts/disable-fedora-flatpak.ks <<EOF
%post --erroronfail
systemctl disable flatpak-add-fedora-repos.service
%end
EOF

tee /usr/share/anaconda/post-scripts/disable-fedora-flatpak.ks <<'EOF'
%post --erroronfail --nochroot
deployment="$(ostree rev-parse --repo=/mnt/sysimage/ostree/repo ostree/0/1/0)"
target="/mnt/sysimage/ostree/deploy/default/deploy/$deployment.0/var/lib/"
mkdir -p "$target"
rsync -aAXUHKP /var/lib/flatpak "$target"
%end
EOF

curl --retry 15 -Lo /etc/sb_pubkey.der "$sbkey"
tee /usr/share/anaconda/post-scripts/disable-fedora-flatpak.ks <<'EOF'
%post --erroronfail --nochroot
readonly ENROLLMENT_PASSWORD="universalblue"
readonly SECUREBOOT_KEY="/etc/sb_pubkey.der"

if [[ ! -d "/sys/firmware/efi" ]]; then
    echo "EFI mode not detected. Skipping key enrollment."
    exit 0
fi

SYS_ID="$(cat /sys/devices/virtual/dmi/id/product_name)"
if [[ ":Jupiter:Galileo:" =~ ":$SYS_ID:" ]]; then
    echo "Steam Deck detected. Skipping Key Enrollment."
    exit 0
fi

mokutil --timeout -1 || :
echo -e "$ENROLLMENT_PASSWORD\n$ENROLLMENT_PASSWORD" | mokutil --import "$SECUREBOOT_KEY" || :
%end
EOF
