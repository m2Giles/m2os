#!/usr/bin/bash

trap_build="ostree container commit;"

if [[ -n "${CI:-}" ]]; then
    WHAT="$(basename -s .sh "${BASH_SOURCE[1]}" | tr '-' ' ')"
    echo -e "::group::\e[1m\e[36m === ${WHAT^^} ===\e[0m"
    trap_build+=" echo '::endgroup::';"
fi

#shellcheck disable=SC2064
trap "$trap_build" EXIT
