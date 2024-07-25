#!/usr/bin/bash

function pull_image(){
    image="$1"
    count=0
    if ! podman pull "$image" && test $count -lt 3; then
        ((count++))
        pull_image "$image"
    fi
}

# Bash Prexec
curl -Lo /usr/share/bash-prexec https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh

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

# # Build zfs akmods
# pull_image ghcr.io/ublue-os/fsync:latest
# pull_image quay.io/fedora-ostree-desktops/base:"${FEDORA_VERSION}"
# cat > /tmp/Containerfile <<EOF
# FROM
# EOF
