# shellcheck shell=sh

command -v atuin >/dev/null 2>&1 || return 0

export ATUIN_INIT_FLAGS="--disable-up-arrow"

if [ "$(basename "$(readlink /proc/$$/exe)")" = "bash" ]; then
    eval "$(atuin init bash "$ATUIN_INIT_FLAGS")"
fi
