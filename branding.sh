#!/usr/bin/bash

set -eoux pipefail

# Branding
cat <<<"$(jq '."image-name" |= "m2os" |
             ."image-vendor" |= "m2giles" |
             ."image-ref" |= "ostree-image-signed:docker://ghcr.io/m2giles/m2os"' \
    </usr/share/ublue-os/image-info.json)" \
>/tmp/image-info.json
cp /tmp/image-info.json /usr/share/ublue-os/image-info.json

sed -i '/^image-vendor/s/ublue-os/m2giles/' /usr/share/ublue-os/image-info.json
