#!/usr/bin/bash

if [[ -n "${CI:-}" ]]; then
    WHAT="$(basename -s .sh "${BASH_SOURCE[1]}" | tr '-' ' ')"
    echo -e "::group::\e[1m\e[36m === ${WHAT^^} ===\e[0m"
    trap "echo ::endgroup::" EXIT
fi