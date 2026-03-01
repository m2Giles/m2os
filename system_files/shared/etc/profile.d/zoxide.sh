# shellcheck shell=sh

command -v zoxide >/dev/null 2>&1 || return 0

if [ "$(basename "$(readlink /proc/$$/exe)")" = "bash" ]; then
    eval "$(zoxide init bash)"
fi

