#!/usr/bin/bash
#shellcheck disable=SC2115

set ${SET_X:+-x} -eou pipefail

repos=(
    charm
    docker-ce
    fedora-cisco-openh264
    fedora-updates
    fedora-updates-archive
    fedora-updates-testing
    ganto-lxc4-fedora-"$(rpm -E %fedora)"
    ganto-umoci-fedora-"$(rpm -E %fedora)"
    google-chrome
    negativo17-fedora-multimedia
    negativo17-fedora-nvidia
    nvidia-container-toolkit
    rpm-fusion-nonfree-nvidia-driver
    rpm-fusion-nonfree-steam
    tailscale
    ublue-os-staging-fedora-"$(rpm -E %fedora)"
    vscode
)

for repo in "${repos[@]}"; do
    if [[ -f "/etc/yum.repos.d/${repo}.repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/${repo}.repo"
    fi
done

if [[ ! "${IMAGE}" =~ ucore ]]; then
    coprs=()
    mapfile -t coprs <<<"$(find /etc/yum.repos.d/_copr*.repo)"
    for copr in "${coprs[@]}"; do
        sed -i 's@enabled=1@enabled=0@g' "$copr"
    done
fi

dnf5 clean all

# Cleanup extra directories in /usr/lib/modules
KERNEL_VERSION="$(rpm -q kernel-core | sed 's/kernel-core-//g')"

for kernel_dir in /usr/lib/modules/*; do
    echo "$kernel_dir"
    if [[ "$kernel_dir" != "/usr/lib/modules/$KERNEL_VERSION" ]]; then
        echo "Removing $kernel_dir"
        rm -rf "$kernel_dir"
    fi
done

# Fixup Groups
ETC_GROUPS="$(grep -v "root\|wheel" /etc/group)"
if [[ -n "${ETC_GROUPS:-}" ]]; then
    echo "Groups being appended to /usr/lib/group..."
    echo "$ETC_GROUPS"
    echo "$ETC_GROUPS" >>/usr/lib/group
fi

rm -rf /tmp/*
rm -rf /var/*
rm -rf /usr/etc
mkdir -p /tmp
mkdir -p /var/tmp
chmod -R 1777 /var/tmp

bootc container lint
ostree container commit
