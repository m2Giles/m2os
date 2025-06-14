#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

# Signing
mkdir -p /etc/containers
mkdir -p /etc/pki/containers
mkdir -p /etc/containers/registries.d/

if [ -f /usr/etc/containers/policy.json ]; then
    cp /usr/etc/containers/policy.json /etc/containers/policy.json
fi

cat <<<"$(jq '.transports.docker |=. + {
   "ghcr.io/m2giles/m2os": [
    {
        "type": "sigstoreSigned",
        "keyPaths": [
            "/etc/pki/containers/m2os.pub",
            "/etc/pki/containers/m2os-backup.pub"
        ],
        "signedIdentity": {
            "type": "matchRepository"
        }
    }
]}' <"/etc/containers/policy.json")" >"/tmp/policy.json"

cp /tmp/policy.json /etc/containers/policy.json
cp /ctx/cosign.pub /etc/pki/containers/m2os.pub
cp /ctx/cosign-backup.pub /etc/pki/containers/m2os-backup.pub

tee /etc/containers/registries.d/m2os.yaml <<EOF
docker:
  ghcr.io/m2giles/m2os:
    use-sigstore-attachments: true
EOF

mkdir -p /usr/etc/containers/
cp /etc/containers/policy.json /usr/etc/containers/policy.json
