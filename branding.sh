#!/usr/bin/bash

set -eoux pipefail

if [[ "${IMAGE}" =~ cosmic|ucore ]]; then
    tee /usr/share/ublue-os/image-info.json <<'EOF'
{
  "image-name": "",
  "image-flavor": "",
  "image-vendor": "m2giles",
  "image-ref": "ostree-image-signed:docker://ghcr.io/m2giles/m2os",
  "image-tag": "",
  "base-image-name": "",
  "fedora-version": ""
}
EOF
fi

case "${IMAGE}" in
"bazzite"*|"bluefin"*)
    base_image="silverblue"
    ;;
"aurora"*)
    base_image="kinoite"
    ;;
"cosmic"*)
    base_image="${BASE_IMAGE}"
    ;;
"ucore"*)
    base_image="${BASE_IMAGE}"
    ;;
esac

image_flavor="main"
if [[ "$IMAGE" =~ nvidia ]]; then
    image_flavor="nvidia"
fi

# Branding
cat <<<"$(jq ".\"image-name\" |= \"m2os\" |
              .\"image-flavor\" |= \"${image_flavor}\" |
              .\"image-vendor\" |= \"m2giles\" |
              .\"image-ref\" |= \"ostree-image-signed:docker://ghcr.io/m2giles/m2os\" |
              .\"image-tag\" |= \"${IMAGE}${BETA:-}\" |
              .\"base-image-name\" |= \"${base_image}\" |
              .\"fedora-version\" |= \"$(rpm -E %fedora)\"" \
    </usr/share/ublue-os/image-info.json)" \
>/tmp/image-info.json
cp /tmp/image-info.json /usr/share/ublue-os/image-info.json

if [[ "$IMAGE" =~ bazzite ]]; then
    sed -i 's/image-branch/image-tag/' /usr/libexec/bazzite-fetch-image
fi

# OS Release File for Cosmic
if [[ "$IMAGE" =~ cosmic ]]; then
    sed -i "s/^VARIANT_ID=.*/VARIANT_ID=cosmic/" /usr/lib/os-release
    sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Cosmic-Atomic $(rpm -E %fedora) (FROM Fedora ${BASE_IMAGE^})\"/" /usr/lib/os-release
    sed -i "s/^NAME=.*/NAME=\"Cosmic Atomic\"/" /usr/lib/os-release
    sed -i "s/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME=\"cosmic-atomic\"/" /usr/lib/os-release
    sed -i "s/^ID=fedora/ID=cosmic-atomic\nID_LIKE=\"fedora\"/" /usr/lib/os-release
    sed -i "/^REDHAT_BUGZILLA_PRODUCT=/d; /^REDHAT_BUGZILLA_PRODUCT_VERSION=/d; /^REDHAT_SUPPORT_PRODUCT=/d; /^REDHAT_SUPPORT_PRODUCT_VERSION=/d" /usr/lib/os-release
fi
