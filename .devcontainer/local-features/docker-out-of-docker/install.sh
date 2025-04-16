#!/usr/bin/env bash

set -e

echo "Using Docker out of Docker"

SOURCE_SOCKET="${SOURCE_SOCKET:-"/var/run/docker-host.sock"}"
TARGET_SOCKET="${TARGET_SOCKET:-"/var/run/docker.sock"}"
ENABLE_NONROOT_DOCKER="${ENABLE_NONROOT_DOCKER:-"true"}"
USERNAME="${USERNAME:-"{_REMOTE_USER:-"automatic"}"}"

mkdir -p /usr/local/bin

if [ "$(id -u)" -ne 0 ]; then
    echo '(!) Script must be run as root.' >&2
    exit 1
fi

if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" > /dev/null 2>&1; then
    USERNAME=root
fi

# Install Packages
apk add --no-cache \
    docker-cli \
    docker-cli-buildx \
    docker-cli-compose

# dockerfmt
while [[ -z "${DOCKER_FMT:-}" || "${DOCKER_FMT:-}" == "null" ]]; do
    DOCKER_FMT="$(curl -L https://api.github.com/repos/reteps/dockerfmt/releases/latest | jq -r '.assets[] | select(.name| test(".*linux-amd64.*gz$")).browser_download_url')" || (true && sleep 5)
done
curl --retry 3 -Lq "$DOCKER_FMT" | tar -xz -C /usr/bin/
ln -sf /usr/bin/dockerfmt /usr/bin/dockfmt

# Add User to Docker Group
if ! grep -qe "^docker:" </etc/group; then
    groupadd -r docker
fi

usermod -aG docker "${USERNAME}"

DOCKER_GID="$(grep -oP '^docker:x:\K[^:]+' /etc/group)"

if [ "${SOURCE_SOCKET}" != "${TARGET_SOCKET}" ]; then
    mkdir -p "$(dirname "$SOURCE_SOCKET")"
    touch "${SOURCE_SOCKET}"
    ln -s "${SOURCE_SOCKET}" "${TARGET_SOCKET}"
fi

# If enabling non-root access and specified user is found, setup socat and add script
chown -h "${USERNAME}":root "${TARGET_SOCKET}"
mkdir -p /usr/local/share
tee /usr/local/share/docker-out-of-docker-init.sh > /dev/null \
<< EOF
#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

set -e

SOCAT_PATH_BASE=/tmp/vscr-docker-from-docker
SOCAT_LOG=\${SOCAT_PATH_BASE}.log
SOCAT_PID=\${SOCAT_PATH_BASE}.pid

# Wrapper function to only use sudo if not already root
sudoIf()
{
    if [ "\$(id -u)" -ne 0 ]; then
        sudo "\$@"
    else
        "\$@"
    fi
}

# Log messages
log()
{
    echo -e "[\$(date)] \$@" | sudoIf tee -a \${SOCAT_LOG} > /dev/null
}

echo -e "\n** \$(date) **" | sudoIf tee -a \${SOCAT_LOG} > /dev/null
log "Ensuring ${USERNAME} has access to ${SOURCE_SOCKET} via ${TARGET_SOCKET}"

# If enabled, try to update the docker group with the right GID. If the group is root,
# fall back on using socat to forward the docker socket to another unix socket so
# that we can set permissions on it without affecting the host.
if [ "${ENABLE_NONROOT_DOCKER}" = "true" ] && [ "${SOURCE_SOCKET}" != "${TARGET_SOCKET}" ] && [ "${USERNAME}" != "root" ] && [ "${USERNAME}" != "0" ]; then
    SOCKET_GID=\$(stat -c '%g' ${SOURCE_SOCKET})
    if [ "\${SOCKET_GID}" != "0" ] && [ "\${SOCKET_GID}" != "${DOCKER_GID}" ] && ! grep -E ".+:x:\${SOCKET_GID}" /etc/group; then
        sudoIf groupmod --gid "\${SOCKET_GID}" docker
    else
        # Enable proxy if not already running
        if [ ! -f "\${SOCAT_PID}" ] || ! ps -p \$(cat \${SOCAT_PID}) > /dev/null; then
            log "Enabling socket proxy."
            log "Proxying ${SOURCE_SOCKET} to ${TARGET_SOCKET} for vscode"
            sudoIf rm -rf ${TARGET_SOCKET}
            (sudoIf socat UNIX-LISTEN:${TARGET_SOCKET},fork,mode=660,user=${USERNAME},backlog=128 UNIX-CONNECT:${SOURCE_SOCKET} 2>&1 | sudoIf tee -a \${SOCAT_LOG} > /dev/null & echo "\$!" | sudoIf tee \${SOCAT_PID} > /dev/null)
        else
            log "Socket proxy already running."
        fi
    fi
    log "Success"
fi

# Execute whatever commands were passed in (if any). This allows us
# to set this script to ENTRYPOINT while still executing the default CMD.
set +e
exec "\$@"
EOF

chmod +x /usr/local/share/docker-out-of-docker-init.sh
chown "${USERNAME}":root /usr/local/share/docker-out-of-docker-init.sh
