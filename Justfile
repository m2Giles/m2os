# Constants

repo_image_name := "m2os"
repo_name := "m2giles"
username := "m2"
IMAGE_REGISTRY := "ghcr.io/" + repo_name
FQ_IMAGE_NAME := IMAGE_REGISTRY + ":" + repo_image_name
images := '(
    [aurora]="aurora"
    [aurora-nvidia]="aurora-nvidia-open"
    [bazzite]="bazzite-gnome-nvidia-open"
    [bazzite-deck]="bazzite-deck-gnome"
    [bluefin]="bluefin"
    [bluefin-nvidia]="bluefin-nvidia-open"
    [cosmic]="cosmic"
    [cosmic-nvidia]="cosmic-nvidia-open"
    [ucore]="stable-zfs"
    [ucore-nvidia]="stable-nvidia-zfs"
)'

# Just Executable

export just := just_executable()

# SUDO

export SUDO_DISPLAY := if `if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then echo true; fi` == "true" { "true" } else { "false" }
export SUDOIF := if `id -u` == "0" { "" } else if SUDO_DISPLAY == "true" { "sudo --askpass" } else { "sudo" }

# Quiet By Default

export SET_X := if `id -u` == "0" { "1" } else { env('SET_X', '') }

# Podman By Default

export PODMAN := if path_exists("/usr/bin/podman") == "true" { env("PODMAN", "/usr/bin/podman") } else if path_exists("/usr/bin/docker") == "true" { env("PODMAN", "docker") } else { env("PODMAN", "exit 1 ; ") }

[private]
default:
    @{{ just }} --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        {{ just }} --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    {{ just }} --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        {{ just }} --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    {{ just }} --unstable --fmt -f Justfile || { exit 1; }

# Cleanup
[group('Utility')]
clean:
    #!/usr/bin/env bash
    set -euox pipefail
    touch {{ repo_image_name }}_
    {{ SUDOIF }} find {{ repo_image_name }}_* -type d -exec chmod 0755 {} \;
    {{ SUDOIF }} find {{ repo_image_name }}_* -type f -exec chmod 0644 {} \;
    find {{ repo_image_name }}_* -maxdepth 0 -exec rm -rf {} \;
    rm -f output*.env changelog*.md version.txt previous.manifest.json

# Build Image
[group('Image')]
build image="bluefin":
    #!/usr/bin/env bash
    echo "::group:: Container Build Prep"
    set ${SET_X:+-x} -eou pipefail
    declare -A images={{ images }}
    check=${images[{{ image }}]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    BUILD_ARGS=()
    case "{{ image }}" in
    "aurora"*|"bluefin"*)
        BASE_IMAGE="${check}"
        TAG_VERSION=stable-daily
        {{ just }} verify-container "${BASE_IMAGE}":"${TAG_VERSION}"
        skopeo inspect docker://ghcr.io/ublue-os/"${BASE_IMAGE}":"${TAG_VERSION}" > /tmp/inspect-"{{ image }}".json
        fedora_version="$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json | grep -oP 'fc\K[0-9]+')"
        ;;
    "bazzite"*)
        BASE_IMAGE=${check}
        TAG_VERSION=stable
        {{ just }} verify-container "${BASE_IMAGE}":"${TAG_VERSION}"
        skopeo inspect docker://ghcr.io/ublue-os/"${BASE_IMAGE}":"${TAG_VERSION}" > /tmp/inspect-"{{ image }}".json
        fedora_version="$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json | grep -oP 'fc\K[0-9]+')"
        ;;
    "cosmic"*)
        {{ just }} verify-container bluefin:stable-daily
        fedora_version="$(skopeo inspect docker://ghcr.io/ublue-os/bluefin:stable-daily | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
        {{ just }} verify-container akmods:coreos-stable-"${fedora_version}"
        BASE_IMAGE=base-main
        TAG_VERSION="${fedora_version}"
        {{ just }} verify-container "${BASE_IMAGE}":"${TAG_VERSION}"
        skopeo inspect docker://ghcr.io/ublue-os/akmods:coreos-stable-"${fedora_version}" > /tmp/inspect-"{{ image }}".json
        ;;
    "ucore"*)
        BASE_IMAGE=ucore
        TAG_VERSION="${check}"
        {{ just }} verify-container "${BASE_IMAGE}":"${TAG_VERSION}"
        fedora_version="$(skopeo inspect docker://ghcr.io/ublue-os/ucore:"${check}" | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
        {{ just }} verify-container akmods:coreos-stable-"${fedora_version}"
        skopeo inspect docker://ghcr.io/ublue-os/akmods:coreos-stable-"${fedora_version}" > /tmp/inspect-"{{ image }}".json
        ;;
    esac

    VERSION="{{ image }}-${fedora_version}.$(date +%Y%m%d)"
    skopeo list-tags docker://{{ FQ_IMAGE_NAME }} > /tmp/repotags.json
    if [[ $(jq "any(.Tags[]; contains(\"$VERSION\"))" < /tmp/repotags.json) == "true" ]]; then
        POINT="1"
        while jq -e "any(.Tags[]; contains(\"$VERSION.$POINT\"))" < /tmp/repotags.json
        do
            (( POINT++ ))
        done
    fi
    if [[ -n "${POINT:-}" ]]; then
        VERSION="${VERSION}.$POINT"
    fi
    BUILD_ARGS+=("--file" "Containerfile")
    BUILD_ARGS+=("--label" "org.opencontainers.image.title={{ repo_image_name }}")
    BUILD_ARGS+=("--label" "org.opencontainers.image.version=$VERSION")
    BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json)")
    BUILD_ARGS+=("--label" "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses.")
    BUILD_ARGS+=("--build-arg" "IMAGE={{ image }}")
    BUILD_ARGS+=("--build-arg" "BASE_IMAGE=$BASE_IMAGE")
    BUILD_ARGS+=("--build-arg" "TAG_VERSION=$TAG_VERSION")
    BUILD_ARGS+=("--build-arg" "SET_X=${SET_X:-}")
    BUILD_ARGS+=("--build-arg" "VERSION=$VERSION")
    BUILD_ARGS+=("--tag" "localhost/{{ repo_image_name }}:{{ image }}")
    BUILD_ARGS+=("--tag" "localhost/{{ repo_image_name }}:$VERSION")
    if [[ {{ PODMAN }} =~ podman ]]; then
        BUILD_ARGS+=("--pull=newer")
    elif [[ {{ PODMAN }} =~ docker ]]; then
        BUILD_ARGS+=("--pull=missing")
        if [[ "${TERM}" == "dumb" ]]; then
            BUILD_ARGS+=("--progress" "plain")
        fi
    fi
    echo "::endgroup::"

    {{ PODMAN }} build "${BUILD_ARGS[@]}" .

    if [[ "${UID}" -gt "0" ]]; then
        {{ just }} rechunk {{ image }}
    else
        {{ PODMAN }} rmi -f ghcr.io/ublue-os/"${BASE_IMAGE}":"${TAG_VERSION}"
    fi

# Rechunk Image
[private]
rechunk image="bluefin":
    #!/usr/bin/env bash
    echo "::group:: Rechunk Build Prep"
    set ${SET_X:+-x} -eou pipefail

    if [[ ! {{ PODMAN }} =~ podman ]]; then
        echo "Rechunk only supported with podman. Exiting..."
        exit 0
    fi

    ID=$({{ PODMAN }} images --filter reference=localhost/{{ repo_image_name }}:{{ image }} --format "'{{ '{{.ID}}' }}'")

    if [[ -z "$ID" ]]; then
        {{ just }} build {{ image }}
    fi

    if [[ "${UID}" -gt "0" && ! {{ PODMAN }} =~ docker ]]; then
        COPYTMP="$(mktemp -p "${PWD}" -d -t podman_scp.XXXXXXXXXX)"
        {{ SUDOIF }} TMPDIR="${COPYTMP}" {{ PODMAN }} image scp "${UID}"@localhost::localhost/{{ repo_image_name }}:{{ image }} root@localhost::localhost/{{ repo_image_name }}:{{ image }}
        rm -rf "${COPYTMP}"
    fi

    CREF=$({{ SUDOIF }} {{ PODMAN }} create localhost/{{ repo_image_name }}:{{ image }} bash)
    MOUNT=$({{ SUDOIF }} {{ PODMAN }} mount "$CREF")
    # FEDORA_VERSION="$({{ SUDOIF }} {{ PODMAN }} inspect "$CREF" | jq -r '.[]["Config"]["Labels"]["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
    OUT_NAME="{{ repo_image_name }}_{{ image }}"
    VERSION="$({{ SUDOIF }} {{ PODMAN }} inspect "$CREF" | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')"
    LABELS="
    org.opencontainers.image.title={{ repo_image_name }}:{{ image }}
    org.opencontainers.image.revision=$(git rev-parse HEAD)
    ostree.linux=$({{ SUDOIF }} {{ PODMAN }} inspect "$CREF" | jq -r '.[].["Config"]["Labels"]["ostree.linux"]')
    org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses.
    "
    echo "::endgroup::"

    echo "::group:: Rechunk Prune"
    {{ SUDOIF }} {{ PODMAN }} run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/1_prune.sh
    echo "::endgroup::"

    echo "::group:: Create Tree"
    {{ SUDOIF }} {{ PODMAN }} run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --volume "cache_ostree:/var/ostree" \
        --env TREE=/var/tree \
        --env REPO=/var/ostree/repo \
        --env RESET_TIMESTAMP=1 \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/2_create.sh
    {{ SUDOIF }} {{ PODMAN }} unmount "$CREF"
    {{ SUDOIF }} {{ PODMAN }} rm "$CREF"
    if [[ "${UID}" -gt "0" ]]; then
        {{ SUDOIF }} {{ PODMAN }} rmi -f localhost/{{ repo_image_name }}:{{ image }}
    fi
    {{ PODMAN }} rmi -f localhost/{{ repo_image_name }}:{{ image }}
    echo "::endgroup::"

    echo "::group:: Rechunk"
    {{ SUDOIF }} {{ PODMAN }} run --rm \
        --pull=newer \
        --security-opt label=disable \
        --volume "$PWD:/workspace" \
        --volume "$PWD:/var/git" \
        --volume cache_ostree:/var/ostree \
        --env REPO=/var/ostree/repo \
        --env PREV_REF={{ FQ_IMAGE_NAME }}:{{ image }} \
        --env LABELS="$LABELS" \
        --env OUT_NAME="$OUT_NAME" \
        --env VERSION="$VERSION" \
        --env VERSION_FN=/workspace/version.txt \
        --env OUT_REF="oci:$OUT_NAME" \
        --env GIT_DIR="/var/git" \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/3_chunk.sh
    echo "::endgroup::"

    echo "::group:: Cleanup"
    {{ SUDOIF }} find {{ repo_image_name }}_{{ image }} -type d -exec chmod 0755 {} \; || true
    {{ SUDOIF }} find {{ repo_image_name }}_{{ image }}* -type f -exec chmod 0644 {} \; || true
    if [[ "${UID}" -gt "0" ]]; then
        {{ SUDOIF }} chown -R "${UID}":"${GROUPS[0]}" "${PWD}"
        {{ just }} load-image {{ image }}
    elif [[ "${UID}" == "0" && -n "${SUDO_USER:-}" ]]; then
        {{ SUDOIF }} chown -R "${SUDO_UID}":"${SUDO_GID}" "/run/user/${SUDO_UID}/just"
        {{ SUDOIF }} chown -R "${SUDO_UID}":"${SUDO_GID}" "${PWD}"
    fi

    {{ SUDOIF }} {{ PODMAN }} volume rm cache_ostree
    echo "::endgroup::"

# Load Image into Podman and Tag
[private]
load-image image="bluefin":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    IMAGE=$({{ PODMAN }} pull oci:${PWD}/{{ repo_image_name }}_{{ image }})
    {{ PODMAN }} tag ${IMAGE} localhost/{{ repo_image_name }}:{{ image }}
    VERSION=$({{ PODMAN }} inspect $IMAGE | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')
    {{ PODMAN }} tag ${IMAGE} localhost/{{ repo_image_name }}:${VERSION}
    {{ PODMAN }} images
    rm -rf {{ repo_image_name }}_{{ image }}

# Get Tags
get-tags image="bluefin":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    VERSION=$({{ PODMAN }} inspect {{ repo_image_name }}:{{ image }} | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')
    echo "{{ image }} $VERSION"

# Build ISO
[group('ISO')]
build-iso image="bluefin" ghcr="0" clean="0":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    # Validate
    declare -A images={{ images }}
    check=${images[{{ image }}]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi

    # Verify ISO Build Container
    {{ just }} verify-container "build-container-installer" "ghcr.io/jasonn3" "https://raw.githubusercontent.com/JasonN3/build-container-installer/refs/heads/main/cosign.pub"

    mkdir -p {{ repo_image_name }}_build/{lorax_templates,flatpak-refs-{{ image }},output}
    echo 'append etc/anaconda/profile.d/fedora-kinoite.conf "\\n[User Interface]\\nhidden_spokes =\\n    PasswordSpoke"' \
         > {{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl

    # Build from GHCR or localhost
    if [[ "{{ ghcr }}" == "1" ]]; then
        IMAGE_FULL={{ FQ_IMAGE_NAME }}:{{ image }}
        IMAGE_REPO={{ IMAGE_REGISTRY }}
        # Verify Container for ISO
        {{ just }} verify-container "{{ repo_image_name }}:{{ image }}" "${IMAGE_REPO}" "https://raw.githubusercontent.com/{{ repo_name }}/{{ repo_image_name }}/refs/heads/main/cosign.pub"
        {{ PODMAN }} pull "${IMAGE_FULL}"
        TEMPLATES=(
            /github/workspace/{{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl
        )
    else
        IMAGE_FULL=localhost/{{ repo_image_name }}:{{ image }}
        IMAGE_REPO=localhost
        ID=$({{ PODMAN }} images --filter reference=${IMAGE_FULL} --format "'{{ '{{.ID}}' }}'")
        if [[ -z "$ID" ]]; then
            {{ just }} build {{ image }}
        fi
        TEMPLATES=(
            /github/workspace/{{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl
        )
    fi

    # Check if ISO already exists. Remove it.
    if [[ -f "{{ repo_image_name }}_build/output/{{ image }}.iso" || -f "{{ repo_image_name }}_build/output/{{ image }}.iso-CHECKSUM" ]]; then
        rm -f {{ repo_image_name }}_build/output/{{ image }}.iso*
    fi

    # Load image into rootful podman
    if [[ "${UID}" -gt "0" && ! {{ PODMAN }} =~ docker ]]; then
        COPYTMP="$(mktemp -p "${PWD}" -d -t podman_scp.XXXXXXXXXX)"
        {{ SUDOIF }} TMPDIR="${COPYTMP}" {{ PODMAN }} image scp "${UID}"@localhost::"${IMAGE_FULL}" root@localhost::"${IMAGE_FULL}"
        rm -rf "${COPYTMP}"
    fi

    # Generate Flatpak List
    TEMP_FLATPAK_INSTALL_DIR="$(mktemp -d -p /tmp flatpak-XXXXX)"
    FLATPAK_REFS_DIR="{{ repo_image_name }}_build/flatpak-refs-{{ image }}"
    FLATPAK_REFS_DIR_ABS="$(realpath ${FLATPAK_REFS_DIR})"
    mkdir -p "${FLATPAK_REFS_DIR_ABS}"
    case "{{ image }}" in
    *"aurora"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/aurora/refs/heads/main/aurora_flatpaks/flatpaks"
    ;;
    *"bazzite"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/bazzite/refs/heads/main/installer/gnome_flatpaks/flatpaks"
    ;;
    *"bluefin"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/bluefin/refs/heads/main/bluefin_flatpaks/flatpaks"
    ;;
    *"cosmic"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/cosmic/refs/heads/main/flatpaks.txt"
    ;;
    esac
    curl -Lo "${FLATPAK_REFS_DIR_ABS}"/flatpaks.txt "${FLATPAK_LIST_URL}"
    ADDITIONAL_FLATPAKS=(
        app/com.discordapp.Discord/x86_64/stable
        app/com.spotify.Client/x86_64/stable
        app/org.gimp.GIMP/x86_64/stable
        app/org.libreoffice.LibreOffice/x86_64/stable
        app/org.prismlauncher.PrismLauncher/x86_64/stable
    )
    if [[ "{{ image }}" =~ cosmic ]]; then
        ADDITIONAL_FLATPAKS+=(
            app/org.gnome.World.PikaBackup/x86_64/stable
            app/it.mijorus.gearlever/x86_64/stable
            runtime/org.gtk.Gtk3theme.adw-gtk3/x86_64/3.22
            runtime/org.gtk.Gtk3theme.adw-gtk3-dark/x86_64/3.22
        )
    elif [[ "{{ image }}" =~ bazzite ]]; then
        ADDITIONAL_FLATPAKS+=(app/org.gnome.World.PikaBackup/x86_64/stable)
    elif [[ "{{ image }}" =~ aurora|bluefin ]]; then
        ADDITIONAL_FLATPAKS+=(app/it.mijorus.gearlever/x86_64/stable)
    fi
    FLATPAK_REFS=()
    while IFS= read -r line; do
    FLATPAK_REFS+=("$line")
    done < "${FLATPAK_REFS_DIR}/flatpaks.txt"
    FLATPAK_REFS+=("${ADDITIONAL_FLATPAKS[@]}")
    echo "Flatpak refs: ${FLATPAK_REFS[*]}"
    # Generate installation script
    tee "${TEMP_FLATPAK_INSTALL_DIR}/install-flatpaks.sh"<<EOF
    mkdir -p /flatpak/flatpak /flatpak/triggers
    mkdir /var/tmp
    chmod -R 1777 /var/tmp
    flatpak config --system --set languages "*"
    flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --system -y flathub ${FLATPAK_REFS[@]}
    ostree refs --repo=\${FLATPAK_SYSTEM_DIR}/repo | grep '^deploy/' | grep -v 'org\.freedesktop\.Platform\.openh264' | sed 's/^deploy\///g' > /output/flatpaks-with-deps
    EOF
    # Create Flatpak List
    {{ SUDOIF }} {{ PODMAN }} run --rm --privileged \
    --entrypoint /bin/bash \
    -e FLATPAK_SYSTEM_DIR=/flatpak/flatpak \
    -e FLATPAK_TRIGGERS_DIR=/flatpak/triggers \
    -v "${FLATPAK_REFS_DIR_ABS}":/output \
    -v "${TEMP_FLATPAK_INSTALL_DIR}":/temp_flatpak_install_dir \
    "${IMAGE_FULL}" /temp_flatpak_install_dir/install-flatpaks.sh

    VERSION="$({{ SUDOIF }} {{ PODMAN }} inspect ${IMAGE_FULL} | jq -r '.[]["Config"]["Labels"]["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
    if [[ "{{ ghcr }}" == "1" && "{{ clean }}" == "1" ]]; then
        {{ SUDOIF }} {{ PODMAN }} rmi ${IMAGE_FULL}
    fi
    # list Flatpaks
    cat "${FLATPAK_REFS_DIR}"/flatpaks-with-deps
    #ISO Container Args
    iso_build_args=()
    if [[ "{{ ghcr }}" == "0" ]]; then
        iso_build_args+=(--volume "/var/lib/containers/storage:/var/lib/containers/storage")
    fi
    iso_build_args+=(--volume "${PWD}:/github/workspace/")
    iso_build_args+=(ghcr.io/jasonn3/build-container-installer:latest)
    iso_build_args+=(ADDITIONAL_TEMPLATES="${TEMPLATES[*]}")
    iso_build_args+=(ARCH="x86_64")
    iso_build_args+=(ENROLLMENT_PASSWORD="universalblue")
    iso_build_args+=(FLATPAK_REMOTE_REFS_DIR="/github/workspace/${FLATPAK_REFS_DIR}")
    iso_build_args+=(IMAGE_NAME="{{ repo_image_name }}")
    iso_build_args+=(IMAGE_REPO="${IMAGE_REPO}")
    iso_build_args+=(IMAGE_SIGNED="true")
    if [[ "{{ ghcr }}" == "0" ]]; then
        iso_build_args+=(IMAGE_SRC="containers-storage:${IMAGE_FULL}")
    fi
    iso_build_args+=(IMAGE_TAG="{{ image }}")
    iso_build_args+=(ISO_NAME="/github/workspace/{{ repo_image_name }}_build/output/{{ image }}.iso")
    iso_build_args+=(SECURE_BOOT_KEY_URL="https://github.com/ublue-os/akmods/raw/main/certs/public_key.der")
    iso_build_args+=(VARIANT="Kinoite")
    iso_build_args+=(VERSION="$VERSION")
    iso_build_args+=(WEB_UI="false")
    # Build ISO
    {{ SUDOIF }} {{ PODMAN }} run --rm --privileged --pull=newer --security-opt label=disable "${iso_build_args[@]}"
    if [[ "${UID}" -gt "0" ]]; then
        {{ SUDOIF }} chown -R "${UID}":"${GROUPS[0]}" "${PWD}"
        {{ SUDOIF }} {{ PODMAN }} rmi "${IMAGE_FULL}"
    elif [[ "${UID}" == "0" && -n "${SUDO_USER:-}" ]]; then
        {{ SUDOIF }} chown -R "${SUDO_UID}":"${SUDO_GID}" "${PWD}"
    fi

# Run ISO
[group('ISO')]
run-iso image="bluefin":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    if [[ ! -f "{{ repo_image_name }}_build/output/{{ image }}.iso" ]]; then
        {{ just }} build-iso {{ image }}
    fi
    port=8006;
    while grep -q "${port}" <<< "$(ss -tunalp)"; do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"
    (sleep 30 && xdg-open http://localhost:"${port}")&
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "BOOT_MODE=windows_secure")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/{{ repo_image_name }}_build/output/{{ image }}.iso":"/boot.iso":z)
    run_args+=(docker.io/qemux/qemu-docker)
    {{ PODMAN }} run "${run_args[@]}"

# Test Changelogs
[group('Changelogs')]
changelogs branch="stable" urlmd="" handwritten="":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    python3 changelogs.py {{ branch }} ./output-{{ branch }}.env ./changelog-{{ branch }}.md --workdir . --handwritten "{{ handwritten }}" --urlmd "{{ urlmd }}"

# Verify Container with Cosign
[group('Utility')]
verify-container container="" registry="ghcr.io/ublue-os" key="": install-cosign
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    # Public Key for Container Verification
    key={{ key }}
    if [[ -z "${key:-}" && "{{ registry }}" == "ghcr.io/ublue-os" ]]; then
        key="https://raw.githubusercontent.com/ublue-os/main/main/cosign.pub"
    fi

    # Verify Container using cosign public key
    if ! cosign verify --key "${key}" "{{ registry }}"/"{{ container }}" >/dev/null; then
        echo "NOTICE: Verification failed. Please ensure your public key is correct."
        exit 1
    fi

# Secureboot Check
[group('Utility')]
secureboot image="bluefin":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    # Get the vmlinuz to check
    kernel_release=$({{ PODMAN }} inspect "{{ repo_image_name }}":"{{ image }}" | jq -r '.[].Config.Labels["ostree.linux"]')
    TMP=$({{ PODMAN }} create "{{ repo_image_name }}":"{{ image }}" bash)
    {{ PODMAN }} cp "$TMP":/usr/lib/modules/"${kernel_release}"/vmlinuz /tmp/vmlinuz
    {{ PODMAN }} rm "$TMP"

    # Get the Public Certificates
    curl --retry 3 -Lo /tmp/kernel-sign.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key.der
    curl --retry 3 -Lo /tmp/akmods.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key_2.der
    openssl x509 -in /tmp/kernel-sign.der -out /tmp/kernel-sign.crt
    openssl x509 -in /tmp/akmods.der -out /tmp/akmods.crt

    # Make sure we have sbverify
    CMD="$(command -v sbverify)"
    if [[ -z "${CMD:-}" ]]; then
        temp_name="sbverify-${RANDOM}"
        {{ PODMAN }} run -dt \
            --entrypoint /bin/sh \
            --volume /tmp/vmlinuz:/tmp/vmlinuz:z \
            --volume /tmp/kernel-sign.crt:/tmp/kernel-sign.crt:z \
            --volume /tmp/akmods.crt:/tmp/akmods.crt:z \
            --name ${temp_name} \
            alpine:edge
        {{ PODMAN }} exec "${temp_name}" apk add sbsigntool
        CMD="{{ PODMAN }} exec ${temp_name} /usr/bin/sbverify"
    fi

    # Confirm that Signatures Are Good
    $CMD --list /tmp/vmlinuz
    returncode=0
    if ! $CMD --cert /tmp/kernel-sign.crt /tmp/vmlinuz || ! $CMD --cert /tmp/akmods.crt /tmp/vmlinuz; then
        echo "Secureboot Signature Failed...."
        returncode=1
    fi
    if [[ -n "${temp_name:-}" ]]; then
        {{ PODMAN }} rm -f "${temp_name}"
    fi
    exit "$returncode"

# Merge Changelogs
merge-changelog:
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    rm -f changelog.md
    cat changelog-stable.md changelog-bazzite.md > changelog.md
    last_tag=$(git tag --list {{ repo_image_name }}-\* | sort -V | tail -1)
    date_extract="$(echo ${last_tag:-} | grep -oP '{{ repo_image_name }}-\K[0-9]+')"
    date_version="$(echo ${last_tag:-} | grep -oP '\.\K[0-9]+$' || true)"
    if [[ "${date_extract:-}" == "$(date +%Y%m%d)" ]]; then
        tag="{{ repo_image_name }}-${date_extract:-}.$(( ${date_version:-} + 1 ))"
    else
        tag="{{ repo_image_name }}-$(date +%Y%m%d)"
    fi
    cat << EOF
    {
        "title": "$tag (#$(git rev-parse --short HEAD))",
        "tag": "$tag"
    }
    EOF

lint:
    # shell
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'
    # yaml
    yamllint -s {{ justfile_dir() }}
    # just
    {{ just }} check
    # just recipes
    {{ just }} lint-recipes

format:
    # shell
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
    # yaml
    yamlfmt {{ justfile_dir() }}
    # just
    {{ just }} fix

_lint-recipe linter recipe *args:
    {{ just }} -n {{ recipe }} {{ args }} 2>&1 | tee /tmp/{{ recipe }} >/dev/null && \
    echo "Linting {{ recipe }} with {{ linter }}" && \
    {{ linter }} /tmp/{{ recipe }} && rm /tmp/{{ recipe }} || \
    rm /tmp/{{ recipe }}

lint-recipes:
    #!/usr/bin/bash
    for recipe in build rechunk build-iso run-iso; do
        {{ just }} _lint-recipe "shellcheck -e SC2050,SC2194" "${recipe}" bluefin
    done

# Get Cosign if Needed
[private]
install-cosign:
    #!/usr/bin/bash

    # Get Cosign from Chainguard
    if [[ ! $(command -v cosign) ]]; then
        COSIGN_CONTAINER_ID=$({{ SUDOIF }} {{ PODMAN }} create cgr.dev/chainguard/cosign:latest bash)
        {{ SUDOIF }} {{ PODMAN }} cp "${COSIGN_CONTAINER_ID}":/usr/bin/cosign /usr/local/bin/cosign
        {{ SUDOIF }} {{ PODMAN }} rm -f "${COSIGN_CONTAINER_ID}"
    fi
    # Verify Cosign Image Signatures if needed
    if [[ -n "${COSIGN_CONTAINER_ID:-}" ]]; then
        if ! cosign verify --certificate-oidc-issuer=https://token.actions.githubusercontent.com --certificate-identity=https://github.com/chainguard-images/images/.github/workflows/release.yaml@refs/heads/main cgr.dev/chainguard/cosign >/dev/null; then
            echo "NOTICE: Failed to verify cosign image signatures."
            exit 1
        fi
    fi

# Login to GHCR
[group('CI')]
login-to-ghcr $user $token:
    @echo "$token" | {{ PODMAN }} login ghcr.io -u "$user" --password-stdin

# Push Images to Registry
[group('CI')]
push-to-registry $image $dryrun="true" $destination="":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Image Name and Version
    declare -A images={{ images }}
    check=${images[{{ image }}]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi

    if [[ -z "$destination" ]]; then
        destination="{{ IMAGE_REGISTRY }}"
    fi

    # Get Tag List
    declare -a TAGS="($(podman image list localhost/{{ repo_image_name }}:{{ image }} --noheading --format 'table {{{{ .Tag }}'))"
    if [[ "$dryrun" == "false" ]]; then
        for tag in "${TAGS[@]}"; do
            skopeo copy --retry-times=3 "containers-storage:localhost/{{ repo_image_name }}" "docker://$destination/{{ repo_image_name }}:$tag" >&2
        done
    fi
    digest="$(skopeo inspect docker://$destination/{{ repo_image_name }}:$image --format '{{{{ .Digest }}')"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "digest=$digest" >> "$GITHUB_OUTPUT"
    fi
    echo "$digest"

# Sign Images with Cosign
[group('CI')]
cosign-sign $digest $destination="": install-cosign
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    if [[ -z "$destination" ]]; then
        destination="{{ IMAGE_REGISTRY }}"
    fi
    @cosign sign -y --key env://COSIGN_PRIVATE_KEY "$destination/{{ repo_image_name }}:$digest"

# Generate SBOM
[group('CI')]
gen-sbom $image:
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Image Name and Version
    declare -A images={{ images }}
    check=${images[{{ image }}]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi

    # Get SYFT if needed
    SYFT_ID=""
    if [[ ! $(command -v syft) ]]; then
        SYFT_ID="$({{ SUDOIF }} podman create --pull=newer docker.io/anchore/syft:latest)"
        {{ SUDOIF }} podman cp "$SYFT_ID":/syft /usr/local/bin/syft
        {{ SUDOIF }} podman rm -f "$SYFT_ID" > /dev/null
        trap '{{ SUDOIF }} rm -f /usr/local/bin/syft; exit 1' SIGINT
    fi

    # Enable Podman Socket if needed
    if [[ "$EUID" -eq "0" ]] && ! systemctl is-active -q podman.socket; then
        systemctl start podman.socket
        started_podman="true"
    elif ! systemctl is-active -q --user podman.socket; then
        systemctl start --user podman.socket
        started_podman="true"
    fi

    # Make SBOM
    OUTPUT_PATH="$(mktemp -d)/sbom.json"
    SYFT_PARALLELISM="$(( $(nproc) * 2 ))"
    syft "{{ repo_image_name }}:{{ image }}" -o spdx-json="$OUTPUT_PATH" >&2

    # Cleanup
    if [[ "$EUID" -eq "0" && "${started_podman:-}" == "true" ]]; then
        systemctl stop podman.socket
    elif [[ "${started_podman:-}" == "true" ]]; then
        systemctl stop --user podman.socket
    fi
    if [[ -n "$SYFT_ID" ]]; then
        {{ SUDOIF }} rm -f /usr/local/bin/syft
    fi

    # Output Path
    echo "$OUTPUT_PATH"

# Add SBOM attestation
[group('CI')]
sbom-attest $image $dryrun="true" $digest="" $destination="": install-cosign
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Image Name and Version
    declare -A images={{ images }}
    check=${images[{{ image }}]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi

    # Set Destination
    if [[ -z "$destination" ]]; then
        destination="{{ IMAGE_REGISTRY }}"
    fi

    # Set Digest
    if [[ -z "$digest" ]]; then
        digest="$({{ PODMAN }} inspect localhost/{{ repo_image_name }}:$image --format '{{{{ .Digest }}')"
    fi

    # Generate SBOM
    sbom="$({{ just }} gen-sbom $image)"

    # ATTEST ARGS
    COSIGN_ATTEST_ARGS=(
       "--predicate" "./sbom.json"
       "--type" "spdxjson"
       "--key" "env://COSIGN_PRIVATE_KEY"
       "$destination/{{ repo_image_name }}:$digest"
    )

    if [[ "$dryrun" == "true" ]]; then
        COSIGN_ATTEST_ARGS+=(
            "--no-upload=true"
        )
    fi

    # Attest with SBOM
    cd "$(dirname $sbom)" && \
    cosign attest -y "${COSIGN_ATTEST_ARGS[@]}"
