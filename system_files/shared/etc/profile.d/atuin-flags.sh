# shellcheck shell=sh

command -v atuin >/dev/null 2>&1 || return 0

if [ "$(basename "$(readlink /proc/$$/exe)")" = "bash" ]; then
    export ATUIN_INIT_FLAGS="--disable-up-arrow"
fi
