#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

# Signing
mkdir -p /etc/containers

yq -i '.transports.docker."ghcr.io/m2giles/m2os" = [{
    "type": "sigstoreSigned",
    "keyPaths": [
        "/etc/pki/containers/m2os.pub",
        "/etc/pki/containers/m2os-backup.pub"
    ],
    "signedIdentity": {
        "type": "matchRepository"
    }
}]' /etc/containers/policy.json
