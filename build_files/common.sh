#!/usr/bin/bash

trap_build="ostree container commit;"

if [[ -n "${CI:-}" ]]; then
    WHAT="$(basename -s .sh "${BASH_SOURCE[1]}" | tr '-' ' ')"
    echo -e "::group::\e[1m\e[36m === ${WHAT^^} ===\e[0m"
    trap_build+=" echo '::endgroup::';"
fi

#shellcheck disable=SC2064
trap "$trap_build" EXIT

function ghcurl() {
    set +x
    if [[ -f /run/secrets/GITHUB_TOKEN ]]; then
        GITHUB_TOKEN="$(< /run/secrets/GITHUB_TOKEN)"
        AUTH_HEADER="Authorization: Bearer ${GITHUB_TOKEN}"
    else
        AUTH_HEADER=""
    fi

    URL="$1"
    shift
    OPTIONS=("$@")

    if [[ -n "$AUTH_HEADER" ]]; then
        curl -sSL -H "$AUTH_HEADER" "${OPTIONS[@]}" "$URL"
    else
        curl -sSL "${OPTIONS[@]}" "$URL"
    fi
    set -x
}