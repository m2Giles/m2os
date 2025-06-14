#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

# Change the Config File (First Boot Only?)
cat /usr/lib/ostree/prepare-root.conf
sed -i '{N; s/\[composefs\]\nenabled = no/\[composefs\]\nenabled = yes/g}' /usr/lib/ostree/prepare-root.conf
cat /usr/lib/ostree/prepare-root.conf

# Set Compose FS
ostree config set ex-integrity.composefs yes

# Remove ostree-grub2 if present
if rpm -q ostree-grub2; then
    dnf5 remove -y ostree-grub2
fi
