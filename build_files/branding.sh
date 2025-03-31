#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

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
"bazzite"* | "bluefin"*)
    base_image="silverblue"
    ;;
"aurora"*)
    base_image="kinoite"
    ;;
"cosmic"*)
    #shellcheck disable=2153
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
    sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Bluefin $(echo "${IMAGE^}" | cut -d - -f1) (Version: ${VERSION} / FROM Universal Blue ${BASE_IMAGE} $(rpm -E %fedora))\"|" /usr/lib/os-release
    sed -i "s/^VARIANT_ID=.*/VARIANT_ID=${IMAGE}/" /usr/lib/os-release
    sed -i "s/^NAME=.*/NAME=\"${IMAGE^} Atomic\"/" /usr/lib/os-release
    sed -i "s/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME=\"${IMAGE^}-atomic\"/" /usr/lib/os-release
    sed -i "s/^ID=fedora/ID=${IMAGE^}\nID_LIKE=\"fedora\"/" /usr/lib/os-release
    sed -i "/^REDHAT_BUGZILLA_PRODUCT=/d; /^REDHAT_BUGZILLA_PRODUCT_VERSION=/d; /^REDHAT_SUPPORT_PRODUCT=/d; /^REDHAT_SUPPORT_PRODUCT_VERSION=/d" /usr/lib/os-release
else
    sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"$(echo "${IMAGE^}" | cut -d - -f1) (Version: ${VERSION} / FROM ${BASE_IMAGE^} $(rpm -E %fedora))\"|" /usr/lib/os-release
fi

sed -i "s|^VERSION=.*|VERSION=\"${VERSION} (${base_image^})\"|" /usr/lib/os-release
sed -i "s|^OSTREE_VERSION=.*|OSTREE_VERSION=\'${VERSION}\'|" /usr/lib/os-release
echo "IMAGE_ID=\"${IMAGE}\"" >>/usr/lib/os-release
echo "IMAGE_VERSION=\"${VERSION}\"" >>/usr/lib/os-release
ln -sf /usr/lib/os-release /etc/os-release
