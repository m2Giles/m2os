#!/usr/bin/bash

set -eoux pipefail

# Bazzite Changes
if [[ "${IMAGE}" == "bazzite-gnome-nvidia" ]]; then
    rpm-ostree install \
        sunshine \
        bootc
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
fi

# VSCode because it's still better for a lot of things
curl -Lo /etc/yum.repos.d/vscode.repo \
    https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/dx/etc/yum.repos.d/vscode.repo

# Emacs/Vscode/Swtpm
rpm-ostree install emacs swtpm code

# Docker sysctl.d
mkdir -p /usr/lib/sysctl.d
echo "net.ipv4.ip_forward = 1" > /usr/lib/sysctl.d/docker-ce.conf
sysctl -p

# Distrobox Assemble Files
curl -Lo /tmp/incus.ini \
    https://raw.githubusercontent.com/ublue-os/toolboxes/main/apps/incus/distrobox.ini

curl -Lo /tmp/docker.ini \
    https://raw.githubusercontent.com/ublue-os/toolboxes/main/apps/docker/distrobox.ini

mkdir -p /usr/etc/distrobox/

{ printf "\n"; cat /tmp/incus.ini; printf "\n"; cat /tmp/docker.ini; } >> /usr/etc/distrobox/distrobox.ini

# Groups
groupadd -g 250 incus-admin
groupadd -g 251 incus
groupadd -g 252 docker

# Branding
if [[ "${IMAGE}" == "bluefin" ]]; then
    sed -i '/^PRETTY_NAME/s/Bluefin/m2os-bluefin/' /usr/lib/os-release
    sed -i '/image-tag/s/stable/bluefin' /usr/share/ublue-os/image-info.json
elif [[ "${IMAGE}" == "aurora" ]]; then
    sed -i '/^PRETTY_NAME/s/Aurora/m2os-aurora/' /usr/lib/os-release
    sed -i '/image-tag/s/stable/aurora' /usr/share/ublue-os/image-info.json
elif [[ "${IMAGE}" == "bazzite-gnome-nvidia" ]]; then
    sed -i '/^PRETTY_NAME/s/Bazzite GNOME/m2os-bazzite/' /usr/lib/os-release
fi

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
