#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

# AURORA helpers
if [[ ! ${IMAGE} =~ aurora ]]; then
    rm -f /usr/libexec/ssh-add-identities 
    rm -f /etc/environment.d/zed.conf
    rm -f /etc/xdg/autostart/ssh-add-identities.desktop
fi

# GSCHEMA OVERRIDES
if [[ ! "${IMAGE}" =~ bazzite|bluefin ]]; then
    rm -f /usr/share/glib-2.0/schemas/zz1-m2os-modifications.gschema.override
fi

if [[ ! "${IMAGE}" =~ bluefin ]]; then
    rm -f /usr/share/glib-2.0/schemas/zz2-m2os-modifications.gschema.override
fi

# Compile gschema overrides and include error checking for invalid overrides
mkdir -p /tmp/ublue-schema-test
find /usr/share/glib-2.0/schemas/ -type f ! -name "*.gschema.override" -exec cp {} /tmp/ublue-schema-test/ \;
cp /usr/share/glib-2.0/schemas/*-m2os-modifications.gschema.override /tmp/ublue-schema-test/ || :
echo "Running error test for m2os gschema override. Aborting if failed."
glib-compile-schemas --strict /tmp/ublue-schema-test || exit 1
echo "Compiling gschema to include m2os setting overrides"
glib-compile-schemas /usr/share/glib-2.0/schemas &>/dev/null
