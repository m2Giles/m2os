#!/usr/bin/bash

set -eoux pipefail

cat /usr/lib/ostree/prepare-root.conf
sed -i '{N; s/\[composefs\]\nenabled = no/\[composefs\]\nenabled = yes/g}' /usr/lib/ostree/prepare-root.conf
cat /usr/lib/ostree/prepare-root.conf
