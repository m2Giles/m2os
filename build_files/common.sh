#!/usr/bin/bash

if [[ -n "${CI:-}" ]]; then
    echo -e "::group::\e[1m\e[36m === ${BASH_SOURCE[0]##*/} ===\e[0m"
    trap "echo ::endgroup::" EXIT
fi