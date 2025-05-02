set unstable := true

# Constants

repo_image_name := "m2os"
repo_name := "m2giles"
username := "m2"
IMAGE_REGISTRY := "ghcr.io" / repo_name
FQ_IMAGE_NAME := IMAGE_REGISTRY / repo_image_name

# Images

[private]
images := '(
    [aurora]=' + aurora + '
    [aurora-nvidia]=' + aurora_nvidia + '
    [bazzite]=' + bazzite + '
    [bazzite-deck]=' + bazzite_deck + '
    [bluefin]=' + bluefin + '
    [bluefin-nvidia]=' + bluefin_nvidia + '
    [cosmic]="cosmic"
    [cosmic-nvidia]="cosmic-nvidia-open"
    [ucore]=' + ucore + '
    [ucore-nvidia]=' + ucore_nvidia + '
)'

# Build Containers

[private]
isobuilder := "ghcr.io/jasonn3/build-container-installer:v1.2.4@sha256:99156bea504884d10b2c9fe85f7b171deea18a2619269d7a7e6643707e681ad7"
[private]
rechunker := "ghcr.io/hhd-dev/rechunk:v1.2.2@sha256:e799d89f9a9965b5b0e89941a9fc6eaab62e9d2d73a0bfb92e6a495be0706907"
[private]
qemu := "ghcr.io/qemus/qemu:7.11@sha256:27accf2d0f4ecfdc7bdf1cd551f886f4a63501337eb78839af906502bd800d82"
[private]
cosign-installer := "cgr.dev/chainguard/cosign:latest@sha256:0222cde7f7ebe430c88fddc33b237434b67e34034daa140353c78b1937810faf"
[private]
syft-installer := "ghcr.io/anchore/syft:v1.23.1@sha256:d4c82a5ea021455ac8d645b5d398166681a1c9ed6b69df78f8efe226a5e9688b"

# Base Containers

[private]
aurora := "ghcr.io/ublue-os/aurora:stable-daily@sha256:208a171dae442655cd9c7135e11b859b4e8ec79256932ba3b75c5ba3109af36b"
[private]
aurora_nvidia := "ghcr.io/ublue-os/aurora-nvidia-open:stable-daily@sha256:fbfcc4cc622cddbd2fea93a5c439bef07c8dcb415c0dd777090dfca38d65d1cc"
[private]
bazzite := "ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable@sha256:eb2983ddedf93b3c8f0217014e863cd932ce5b6cbd2f4a1bb8ef8474e4d476bb"
[private]
bazzite_deck := "ghcr.io/ublue-os/bazzite-deck-gnome:stable@sha256:bc9bd11fa8a7c0cc89e6c3e5be11fce9d685be4b0c127ada581e8de9b75decb3"
[private]
bluefin := "ghcr.io/ublue-os/bluefin:stable-daily@sha256:932946f93314c116a9efce6362d450b472b467d29efef332ca56803e2abf6204"
[private]
bluefin_nvidia := "ghcr.io/ublue-os/bluefin-nvidia-open@sha256:19faa3af1723250917a709ed11763a6d1e381afd4488a4676e02fffa68572a93"
[private]
ucore := "ghcr.io/ublue-os/ucore:stable-zfs@sha256:3d91a38dd5bd8bcb3fecffd5bbb5e6c7c9a364dcd81732f8855e310dced7a59c"
[private]
ucore_nvidia := "ghcr.io/ublue-os/ucore:stable-nvidia-zfs@sha256:1fcd729dbad24a6a193a416cae54b305a8fdf827175118f5572de265e773e3f8"

[private]
default:
    @{{ just }} --list

# Check Just Syntax
[group('Just')]
@check:
    {{ just }} --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
@fix:
    {{ just }} --unstable --fmt -f Justfile

# Cleanup
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -euox pipefail
    touch {{ repo_image_name }}_ || true
    ${SUDOIF} find {{ repo_image_name }}_* -type d -exec chmod 0755 {} \;
    ${SUDOIF} find {{ repo_image_name }}_* -type f -exec chmod 0644 {} \;
    find {{ repo_image_name }}_* -maxdepth 0 -exec rm -rf {} \;
    rm -f output*.env changelog*.md version.txt previous.manifest.json
    rm -f ./*.sbom.*

# Build Image
[group('Image')]
build image="bluefin":
    #!/usr/bin/bash
    echo "::group:: Container Build Prep"
    set ${SET_X:+-x} -eou pipefail
    declare -A images={{ images }}
    check=${images[{{ image }}]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    BUILD_ARGS=()
    mkdir -p {{ BUILD_DIR }}
    BUILDTMP="$(mktemp -d -p {{ BUILD_DIR }})"
    trap 'rm -rf $BUILDTMP' EXIT SIGINT
    case "{{ image }}" in
    "aurora"*|"bazzite"*|"bluefin"*|"ucore"*)
        {{ just }} verify-container "${check#*-os/}"
        skopeo inspect docker://"${check/:*@/@}" > "$BUILDTMP/inspect-{{ image }}.json"
        fedora_version="$(jq -r '.Labels["ostree.linux"]' < "$BUILDTMP/inspect-{{ image }}.json" | grep -oP 'fc\K[0-9]+')"
        ;;
    "cosmic"*)
        bluefin="${images[bluefin]}"
        {{ just }} verify-container "${bluefin#*-os/}"
        fedora_version="$(skopeo inspect docker://"${bluefin/:*@/@}" | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
        {{ just }} verify-container akmods:coreos-stable-"${fedora_version}"
        {{ just }} verify-container akmods-zfs:coreos-stable-"${fedora_version}"
        skopeo inspect docker://ghcr.io/ublue-os/akmods:coreos-stable-"${fedora_version}" > "$BUILDTMP/inspect-{{ image }}.json"
        BASE_IMAGE=base-main
        DIGEST="$(skopeo inspect docker://ghcr.io/ublue-os/base-main:"${fedora_version}" --format '{{ '{{ .Digest }}' }}')"
        {{ just }} verify-container "${BASE_IMAGE}:${fedora_version}@${DIGEST}"
        check="ghcr.io/ublue-os/${BASE_IMAGE}:${fedora_version}@${DIGEST}"
        ;;
    esac

    VERSION="{{ image }}-${fedora_version}.$(date +%Y%m%d)"
    skopeo list-tags docker://{{ FQ_IMAGE_NAME }} > "$BUILDTMP"/repotags.json
    if [[ $(jq "any(.Tags[]; contains(\"$VERSION\"))" < "$BUILDTMP"/repotags.json) == "true" ]]; then
        POINT="1"
        while jq -e "any(.Tags[]; contains(\"$VERSION.$POINT\"))" >/dev/null < "$BUILDTMP"/repotags.json
        do
            (( POINT++ ))
        done
    fi
    if [[ -n "${POINT:-}" ]]; then
        VERSION="${VERSION}.$POINT"
    fi
    # Pull The image
    ${PODMAN} pull "$check"

    #Build Args
    BUILD_ARGS+=("--file" "Containerfile")
    BUILD_ARGS+=("--label" "org.opencontainers.image.source=https://github.com/{{ repo_name }}/{{ repo_image_name }}")
    BUILD_ARGS+=("--label" "org.opencontainers.image.title={{ repo_image_name }}")
    BUILD_ARGS+=("--label" "org.opencontainers.image.version=$VERSION")
    BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < "$BUILDTMP"/inspect-{{ image }}.json)")
    BUILD_ARGS+=("--label" "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses.")
    BUILD_ARGS+=("--build-arg" "IMAGE={{ image }}")
    BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${check%%:*}")
    BUILD_ARGS+=("--build-arg" "TAG_VERSION=${check#*:}")
    BUILD_ARGS+=("--build-arg" "SET_X=${SET_X:-}")
    BUILD_ARGS+=("--build-arg" "VERSION=$VERSION")
    BUILD_ARGS+=("--tag" "localhost/{{ repo_image_name }}:{{ image }}")
    if [[ "${PODMAN}" =~ docker ]] && [ "${TERM}" = "dumb" ]; then
        BUILD_ARGS+=("--progress" "plain")
    fi
    echo "::endgroup::"

    ${PODMAN} build "${BUILD_ARGS[@]}" .

    if [[ -z "${CI:-}" ]]; then
        {{ just }} secureboot localhost/{{ repo_image_name }}:{{ image }}
        {{ just }} rechunk {{ image }}
    else
        ${PODMAN} rmi -f "${check%@*}"
    fi

# Rechunk Image
[group('Image')]
rechunk image="bluefin":
    #!/usr/bin/bash
    echo "::group:: Rechunk Build Prep"
    set ${SET_X:+-x} -eou pipefail

    ${PODMAN} image exists localhost/{{ repo_image_name }}:{{ image }} || {{ just }} build {{ image }}

    if [[ "${UID}" -gt "0" && "${PODMAN}" =~ podman$ ]]; then
       # Use Podman Unshare, and then exit
       ${PODMAN} unshare -- {{ just }} rechunk {{ image }}
       # Exit with previous exit code
       exit "$?"
    fi

    CREF=$(${PODMAN} create localhost/{{ repo_image_name }}:{{ image }} bash)
    OUT_NAME="{{ repo_image_name }}_{{ image }}.tar"
    VERSION="$(${PODMAN} inspect "$CREF" | jq -r '.[].Config.Labels["org.opencontainers.image.version"]')"
    LABELS="
    org.opencontainers.image.source=https://github.com/{{ repo_name }}/{{ repo_image_name }}
    org.opencontainers.image.title={{ repo_image_name }}:{{ image }}
    org.opencontainers.image.revision=$(git rev-parse HEAD)
    ostree.linux=$(${PODMAN} inspect "$CREF" | jq -r '.[].Config.Labels["ostree.linux"]')
    org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses.
    "
    if [[ ! "${PODMAN}" =~ docker|remote ]]; then
        MOUNT=$(${PODMAN} mount "$CREF")
    else
        MOUNTFS="{{ BUILD_DIR }}/{{ image }}_rootfs"
        ${SUDOIF} rm -rf "$MOUNTFS"
        mkdir -p "$MOUNTFS"
        ${PODMAN} export "$CREF" | tar -xf - -C "$MOUNTFS"
        MOUNT="{{ GIT_ROOT }}/$MOUNTFS"
        ${PODMAN} rm "$CREF"
        ${PODMAN} rmi -f localhost/{{ repo_image_name }}:{{ image }}
    fi
    echo "::endgroup::"

    echo "::group:: Rechunk Prune"
    ${PODMAN} run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        {{ rechunker }} \
        /sources/rechunk/1_prune.sh
    echo "::endgroup::"

    echo "::group:: Create Tree"
    ${PODMAN} run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --volume "cache_ostree:/var/ostree" \
        --env TREE=/var/tree \
        --env REPO=/var/ostree/repo \
        --env RESET_TIMESTAMP=1 \
        --user 0:0 \
        {{ rechunker }} \
        /sources/rechunk/2_create.sh
    if [[ ! "${PODMAN}" =~ docker|remote ]]; then
        ${PODMAN} unmount "$CREF"
        ${PODMAN} rm "$CREF"
        ${PODMAN} rmi -f localhost/{{ repo_image_name }}:{{ image }}
    else
        ${SUDOIF} rm -rf "$MOUNTFS"
    fi
    echo "::endgroup::"

    echo "::group:: Rechunk"
    ${PODMAN} run --rm \
        --security-opt label=disable \
        --volume "{{ GIT_ROOT }}:/workspace" \
        --volume "{{ GIT_ROOT }}:/var/git" \
        --volume cache_ostree:/var/ostree \
        --env REPO=/var/ostree/repo \
        --env PREV_REF={{ FQ_IMAGE_NAME }}:{{ image }} \
        --env LABELS="$LABELS" \
        --env OUT_NAME="$OUT_NAME" \
        --env VERSION="$VERSION" \
        --env VERSION_FN=/workspace/version.txt \
        --env OUT_REF="oci-archive:$OUT_NAME" \
        --env GIT_DIR="/var/git" \
        --user 0:0 \
        {{ rechunker }} \
        /sources/rechunk/3_chunk.sh
    echo "::endgroup::"
    echo "::group:: Cleanup"
    if [[ -z "${CI:-}" ]]; then
        {{ just }} load-image {{ image }}
    fi
    ${PODMAN} volume rm cache_ostree
    echo "::endgroup::"

# Load Image into Podman and Tag
[group('CI')]
load-image image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    if [[ "${PODMAN}" =~ podman ]]; then
        IMAGE=$(podman pull oci-archive:{{ repo_image_name }}_{{ image }}.tar)
        podman tag "${IMAGE}" localhost/{{ repo_image_name }}:{{ image }}
    else
        skopeo copy oci-archive:{{ repo_image_name }}_{{ image }}.tar docker-daemon:localhost/{{ repo_image_name }}:{{ image }}
    fi
    VERSION=$(skopeo inspect oci-archive:{{ repo_image_name }}_{{ image }}.tar | jq -r '.Labels["org.opencontainers.image.version"]')
    ${PODMAN} tag localhost/{{ repo_image_name }}:{{ image }} localhost/{{ repo_image_name }}:"${VERSION}"
    ${PODMAN} images

# Get Tags
[group('CI')]
get-tags image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    VERSION=$(${PODMAN} inspect {{ repo_image_name }}:{{ image }} | jq -r '.[].Config.Labels["org.opencontainers.image.version"]')
    echo "{{ image }} $VERSION"

# Build ISO
[group('ISO')]
build-iso image="bluefin" ghcr="0" clean="0":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    # Validate
    declare -A images={{ images }}
    check=${images[{{ image }}]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi

    # Verify ISO Build Container
    {{ just }} verify-container "{{ isobuilder }}" "" "https://raw.githubusercontent.com/JasonN3/build-container-installer/refs/heads/main/cosign.pub"

    mkdir -p {{ BUILD_DIR }}/{lorax_templates,flatpak-refs-{{ image }},output}
    echo 'append etc/anaconda/profile.d/fedora-kinoite.conf "\\n[User Interface]\\nhidden_spokes =\\n    PasswordSpoke"' \
         > {{ BUILD_DIR }}/lorax_templates/remove_root_password_prompt.tmpl

    # Build from GHCR or localhost
    IMAGE_REPO={{ IMAGE_REGISTRY }}
    TEMPLATES=("/github/workspace/{{ BUILD_DIR }}/lorax_templates/remove_root_password_prompt.tmpl")
    if [[ "{{ ghcr }}" -gt "0" ]]; then
        IMAGE_FULL={{ FQ_IMAGE_NAME }}:{{ image }}
        if [[ "{{ ghcr }}" == "1" ]]; then
            # Verify Container for ISO
            {{ just }} verify-container "{{ repo_image_name }}:{{ image }}" "${IMAGE_REPO}" "https://raw.githubusercontent.com/{{ repo_name }}/{{ repo_image_name }}/refs/heads/main/cosign.pub"
            ${PODMAN} pull "${IMAGE_FULL}"
        elif [[ "{{ ghcr }}" == "2" ]]; then
            {{ just }} load-image {{ image }}
            ${PODMAN} tag localhost/{{ repo_image_name }}:{{ image }} "$IMAGE_FULL"
        fi
    else
        IMAGE_FULL=localhost/{{ repo_image_name }}:{{ image }}
        ${PODMAN} image exists "$IMAGE_FULL" || {{ just }} build {{ image }}
    fi

    # Check if ISO already exists. Remove it.
    if [[ -f "{{ BUILD_DIR }}/output/{{ image }}.iso" || -f "{{ BUILD_DIR }}/output/{{ image }}.iso-CHECKSUM" ]]; then
        rm -f {{ BUILD_DIR }}/output/{{ image }}.iso*
    fi

    # Load image into rootful podman
    if [[ "${UID}" -gt "0" && ! "${PODMAN}" =~ docker|remote ]]; then
        mkdir -p {{ BUILD_DIR }}
        COPYTMP="$(mktemp -dp {{ BUILD_DIR }})"
        ${SUDOIF} TMPDIR="${COPYTMP}" ${PODMAN} image scp "${UID}"@localhost::"${IMAGE_FULL}" root@localhost::"${IMAGE_FULL}"
        rm -rf "${COPYTMP}"
    fi

    # Generate Flatpak List
    TEMP_FLATPAK_INSTALL_DIR="$(mktemp -dp {{ BUILD_DIR }})"
    trap 'rm -rf "$TEMP_FLATPAK_INSTALL_DIR"' EXIT SIGINT
    FLATPAK_REFS_DIR="{{ BUILD_DIR }}/flatpak-refs-{{ image }}"
    mkdir -p "${FLATPAK_REFS_DIR}"
    FLATPAK_REFS_DIR_ABS="{{ GIT_ROOT }}/${FLATPAK_REFS_DIR}"
    case "{{ image }}" in
    *"aurora"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/aurora/refs/heads/main/aurora_flatpaks/flatpaks"
    ;;
    *"bazzite"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/bazzite/refs/heads/main/installer/gnome_flatpaks/flatpaks"
    ;;
    *"bluefin"*|*"cosmic"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/bluefin/refs/heads/main/iso_files/system-flatpaks.txt"
    ;;
    esac
    curl -Lo "${FLATPAK_REFS_DIR}"/flatpaks.txt "${FLATPAK_LIST_URL}"
    ADDITIONAL_FLATPAKS=(
        app/com.discordapp.Discord/x86_64/stable
        app/com.spotify.Client/x86_64/stable
        app/org.gimp.GIMP/x86_64/stable
        app/org.libreoffice.LibreOffice/x86_64/stable
        app/org.prismlauncher.PrismLauncher/x86_64/stable
    )
    if [[ "{{ image }}" =~ bazzite ]]; then
        ADDITIONAL_FLATPAKS+=(app/org.gnome.World.PikaBackup/x86_64/stable)
    elif [[ "{{ image }}" =~ aurora|bluefin|cosmic ]]; then
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
    mkdir /var/roothome
    chmod -R 1777 /var/tmp
    flatpak config --system --set languages "*"
    flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --system -y flathub ${FLATPAK_REFS[@]}
    ostree refs --repo=\${FLATPAK_SYSTEM_DIR}/repo | grep '^deploy/' | grep -v 'org\.freedesktop\.Platform\.openh264' | sed 's/^deploy\///g' > /output/flatpaks-with-deps
    EOF
    # Create Flatpak List
    [[ ! -f "$FLATPAK_REFS_DIR/flatpaks-with-deps" ]] && \
    ${SUDOIF} ${PODMAN} run --rm --privileged \
    --entrypoint /bin/bash \
    -e FLATPAK_SYSTEM_DIR=/flatpak/flatpak \
    -e FLATPAK_TRIGGERS_DIR=/flatpak/triggers \
    -v "${FLATPAK_REFS_DIR_ABS}":/output \
    -v "{{ GIT_ROOT }}/${TEMP_FLATPAK_INSTALL_DIR}":/temp_flatpak_install_dir \
    "${IMAGE_FULL}" /temp_flatpak_install_dir/install-flatpaks.sh

    VERSION="$(${SUDOIF} ${PODMAN} inspect ${IMAGE_FULL} | jq -r '.[].Config.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
    if [[ "{{ ghcr }}" -ge "1" && "{{ clean }}" == "1" ]]; then
        ${SUDOIF} ${PODMAN} rmi ${IMAGE_FULL}
    fi
    # list Flatpaks
    cat "${FLATPAK_REFS_DIR}"/flatpaks-with-deps
    #ISO Container Args
    iso_build_args=()
    if [[ "{{ ghcr }}" == "0" && "${PODMAN}" =~ podman ]]; then
        iso_build_args+=(--volume "/var/lib/containers/storage:/var/lib/containers/storage")
    elif [[ "{{ ghcr }}" == "0" && "${PODMAN}" =~ docker ]]; then
        iso_build_args+=(--volume "/var/run/docker.sock:/var/run/docker.sock")
    fi
    iso_build_args+=(--volume "{{ GIT_ROOT }}:/github/workspace/")
    iso_build_args+=({{ isobuilder }})
    iso_build_args+=(ADDITIONAL_TEMPLATES="${TEMPLATES[@]}")
    iso_build_args+=(ARCH="x86_64")
    iso_build_args+=(ENROLLMENT_PASSWORD="universalblue")
    iso_build_args+=(FLATPAK_REMOTE_REFS_DIR="/github/workspace/${FLATPAK_REFS_DIR}")
    iso_build_args+=(IMAGE_NAME="{{ repo_image_name }}")
    iso_build_args+=(IMAGE_REPO="${IMAGE_REPO}")
    iso_build_args+=(IMAGE_SIGNED="true")
    if [[ "{{ ghcr }}" == "0" && "${PODMAN}" =~ podman ]]; then
        iso_build_args+=(IMAGE_SRC="containers-storage:${IMAGE_FULL}")
    elif [[ "{{ ghcr }}" == "0" && "${PODMAN}" =~ docker ]]; then
        iso_build_args+=(IMAGE_SRC="docker-daemon:${IMAGE_FULL}")
    elif [[ "{{ ghcr }}" == "2" ]]; then
        iso_build_args+=(IMAGE_SRC="oci-archive:/github/workspace/{{ repo_image_name }}_{{ image }}.tar")
    fi
    iso_build_args+=(IMAGE_TAG="{{ image }}")
    iso_build_args+=(ISO_NAME="/github/workspace/{{ BUILD_DIR }}/output/{{ image }}.iso")
    iso_build_args+=(SECURE_BOOT_KEY_URL="https://github.com/ublue-os/akmods/raw/main/certs/public_key.der")
    iso_build_args+=(VARIANT="Kinoite")
    iso_build_args+=(VERSION="$VERSION")
    iso_build_args+=(WEB_UI="false")
    # Build ISO
    ${SUDOIF} ${PODMAN} run --rm --privileged --security-opt label=disable "${iso_build_args[@]}"
    if [[ "${PODMAN}" =~ docker ]]; then
        ${SUDOIF} chown -R "${UID}":"${GROUPS[0]}" "$PWD"
    elif [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} chown -R "${UID}":"${GROUPS[0]}" "$PWD"
        ${SUDOIF} ${PODMAN} rmi "${IMAGE_FULL}"
    elif [[ "${UID}" == "0" && -n "${SUDO_USER:-}" ]]; then
        ${SUDOIF} chown -R "${SUDO_UID}":"${SUDO_GID}" "$PWD"
    fi

# Run ISO
[group('ISO')]
run-iso image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    if [[ ! -f "{{ BUILD_DIR }}/output/{{ image }}.iso" ]]; then
        {{ just }} build-iso {{ image }}
    fi
    port=8006;
    while grep -q "${port}" <<< "$(ss -tunalp)"; do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"
    (sleep 30 && (xdg-open http://localhost:"${port}" || true))&
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "BOOT_MODE=windows_secure")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "{{ GIT_ROOT }}/{{ BUILD_DIR }}/output/{{ image }}.iso":"/boot.iso":z)
    run_args+=({{ qemu }})
    ${PODMAN} run "${run_args[@]}"

# Test Changelogs
[group('Changelogs')]
changelogs target="Desktop" urlmd="" handwritten="":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    python3 changelogs.py {{ target }} ./output-{{ target }}.env ./changelog-{{ target }}.md --workdir . --handwritten "{{ handwritten }}" --urlmd "{{ urlmd }}"

# Verify Container with Cosign
[group('Utility')]
verify-container container="" registry="ghcr.io/ublue-os" key="": install-cosign
    #!/usr/bin/bash
    set "${SET_X:+-x}" -eou pipefail

    # Public Key for Container Verification
    key={{ key }}
    if [[ -z "${key:-}" ]] && [[ "{{ container }}" =~ ghcr.io/ublue-os || "{{ registry }}" == "ghcr.io/ublue-os" ]]; then
        key="https://raw.githubusercontent.com/ublue-os/main/main/cosign.pub"
    fi

    target="{{ container }}"
    if [[ "" != "{{ registry }}" ]]; then
        target="{{ registry }}"/"{{ container }}"
    fi

    # Verify Container using cosign public key
    if ! cosign verify --key "${key}" "${target}" >/dev/null; then
        echo "NOTICE: Verification failed. Please ensure your public key is correct."
        exit 1
    fi

# Secureboot Check
[group('CI')]
secureboot image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    # Get the vmlinuz to check
    kernel_release=$(${PODMAN} inspect "{{ image }}" | jq -r '.[].Config.Labels["ostree.linux"]')
    TMP=$(${PODMAN} create "{{ image }}" bash)
    TMPDIR="$(mktemp -d -p .)"
    trap 'rm -rf $TMPDIR' EXIT
    ${PODMAN} cp "$TMP":/usr/lib/modules/"${kernel_release}"/vmlinuz "$TMPDIR/vmlinuz"
    ${PODMAN} rm "$TMP"

    # Get the Public Certificates
    curl --retry 3 -Lo "$TMPDIR"/kernel-sign.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key.der
    curl --retry 3 -Lo "$TMPDIR"/akmods.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key_2.der
    openssl x509 -in "$TMPDIR"/kernel-sign.der -out "$TMPDIR"/kernel-sign.crt
    openssl x509 -in "$TMPDIR"/akmods.der -out "$TMPDIR"/akmods.crt

    # Make sure we have sbverify
    CMD="$(command -v sbverify)" || true
    if [[ -z "${CMD:-}" ]]; then
        temp_name="sbverify-${RANDOM}"
        ${PODMAN} run -dt \
            --entrypoint /bin/sh \
            --security-opt label=disable \
            --workdir {{ GIT_ROOT }} \
            --volume "{{ GIT_ROOT }}/$TMPDIR/:{{ GIT_ROOT }}/$TMPDIR" \
            --name ${temp_name} \
            alpine:edge
        ${PODMAN} exec "${temp_name}" apk add sbsigntool
        CMD="${PODMAN} exec ${temp_name} /usr/bin/sbverify"
    fi

    # Confirm that Signatures Are Good
    $CMD --list "$TMPDIR/vmlinuz"
    returncode=0
    if ! $CMD --cert "$TMPDIR/kernel-sign.crt" "$TMPDIR/vmlinuz" ||
       ! $CMD --cert "$TMPDIR/akmods.crt" "$TMPDIR/vmlinuz"; then
        echo "Secureboot Signature Failed...."
        returncode=1
    fi
    if [[ -n "${temp_name:-}" ]]; then
        ${PODMAN} rm -f "${temp_name}"
    fi
    exit "$returncode"

# Merge Changelogs
[group('Changelogs')]
merge-changelog:
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    rm -f changelog.md
    mapfile -t changelogs < <(find . -type f -name changelog\*.md | sort -r)
    cat "${changelogs[@]}" > changelog.md
    last_tag=$(git tag --list {{ repo_image_name }}-\* | sort -V | tail -1)
    date_extract="$(echo "${last_tag:-}" | grep -oP '{{ repo_image_name }}-\K[0-9]+')"
    date_version="$(echo "${last_tag:-}" | grep -oP '\.\K[0-9]+$' || true)"
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

# Lint Files
[group('Utility')]
@lint:
    # shell
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'
    # yaml
    yamllint -s {{ justfile_dir() }}
    # just
    {{ just }} check
    # just recipes
    {{ just }} lint-recipes

# Format Files
[group('Utility')]
@format:
    # shell
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
    # yaml
    yamlfmt {{ justfile_dir() }}
    # just
    {{ just }} fix

# Linter Helper
[group('Utility')]
_lint-recipe linter recipe *args:
    #!/usr/bin/bash
    set -eou pipefail
    mkdir -p {{ BUILD_DIR }}
    TMPDIR="$(mktemp -d -p {{ BUILD_DIR }})"
    trap 'rm -rf "$TMPDIR"' EXIT SIGINT
    {{ just }} -n {{ recipe }} {{ args }} 2>&1 | tee "$TMPDIR"/{{ recipe }} >/dev/null
    linter=({{ linter }})
    echo "Linting {{ style('warning') }}{{ recipe }}{{ NORMAL }} with {{ style('command') }}${linter[0]}{{ NORMAL }}"
    {{ linter }} "$TMPDIR"/{{ recipe }} && rm "$TMPDIR"/{{ recipe }} || rm "$TMPDIR"/{{ recipe }}

# Linter Helper
[group('Utility')]
lint-recipes:
    #!/usr/bin/bash
    recipes=(
        build
        build-iso
        changelogs
        cosign-sign
        gen-sbom
        get-tags
        load-image
        push-to-registry
        rechunk
        run-iso
        sbom-sign
        secureboot
        verify-container
    )
    for recipe in "${recipes[@]}"; do
        {{ just }} _lint-recipe "shellcheck -s bash -e SC2050,SC2194" "$recipe" bluefin
    done
    recipes=(
        clean
        install-cosign
        lint-recipes
        merge-changelog
    )
    for recipe in "${recipes[@]}"; do
        {{ just }} _lint-recipe "shellcheck -s bash -e SC2050,SC2194" "$recipe"
    done

# Get Cosign if Needed
[group('CI')]
install-cosign:
    #!/usr/bin/bash
    # shellcheck disable=SC2086
    set "${SET_X:+-x}" -euo pipefail

    # Get Cosign from Chainguard
    if [[ ! "$(command -v cosign)" ]]; then
        COSIGN_CONTAINER_ID="$(${SUDOIF} ${PODMAN} create {{ cosign-installer }} bash)"
        ${SUDOIF} ${PODMAN} cp "${COSIGN_CONTAINER_ID}":/usr/bin/cosign /usr/local/bin/cosign
        ${SUDOIF} ${PODMAN} rm -f "${COSIGN_CONTAINER_ID}"
    fi
    # Verify Cosign Image Signatures if needed
    if [[ -n "${COSIGN_CONTAINER_ID:-}" ]]; then
        if ! cosign verify --certificate-oidc-issuer=https://token.actions.githubusercontent.com --certificate-identity=https://github.com/chainguard-images/images/.github/workflows/release.yaml@refs/heads/main cgr.dev/chainguard/cosign >/dev/null; then
            echo "NOTICE: Failed to verify cosign image signatures."
            exit 1
        fi
        ${SUDOIF} ${PODMAN} rmi -f {{ cosign-installer }}
    fi

# Login to GHCR
[group('CI')]
@login-to-ghcr $user $token:
    echo "$token" | podman login ghcr.io -u "$user" --password-stdin
    echo "$token" | docker login ghcr.io -u "$user" --password-stdin

# Push Images to Registry
[group('CI')]
push-to-registry image $dryrun="true" $destination="":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    if [[ -z "$destination" ]]; then
        destination="docker://{{ IMAGE_REGISTRY }}"
    fi

    # Get Tag List
    declare -a TAGS=("$(skopeo inspect oci-archive:{{ repo_image_name }}_{{ image }}.tar | jq -r '.Labels["org.opencontainers.image.version"]')")
    TAGS+=("{{ image }}")

    # Push
    if [[ "{{ dryrun }}" == "false" ]]; then
        for tag in "${TAGS[@]}"; do
            skopeo copy "oci-archive:{{ repo_image_name }}_{{ image }}.tar" "$destination/{{ repo_image_name }}:$tag"
        done
    fi

    # Pass Digest
    digest="$(skopeo inspect "oci-archive:{{ repo_image_name }}_{{ image }}.tar" --format '{{{{ .Digest }}')"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "digest=$digest" >> "$GITHUB_OUTPUT"
    fi
    echo "$digest"

# Sign Images with Cosign
[group('CI')]
cosign-sign digest $destination="": install-cosign
    #!/usr/bin/bash
    set "${SET_X:+-x}" -eou pipefail
    if [[ -z "$destination" ]]; then
        destination="{{ IMAGE_REGISTRY }}"
    fi
    cosign sign -y --key env://COSIGN_PRIVATE_KEY "$destination/{{ repo_image_name }}@{{ digest }}"

# Generate SBOM
[group('CI')]
gen-sbom $input $output="":
    #!/usr/bin/bash
    # shellcheck disable=SC2086
    set ${SET_X:+-x} -eou pipefail

    # Get SYFT if needed
    SYFT_ID=""
    if [[ ! "$(command -v syft)" ]]; then
        SYFT_ID="$(${SUDOIF} ${PODMAN} create {{ syft-installer }})"
        ${SUDOIF} ${PODMAN} cp "$SYFT_ID":/syft /usr/local/bin/syft
        ${SUDOIF} ${PODMAN} rm -f "$SYFT_ID" > /dev/null
        ${SUDOIF} ${PODMAN} rmi -f {{ syft-installer }}
    fi

    # Enable Podman Socket if needed
    if [[ "$EUID" -eq "0" && "${PODMAN}" =~ podman ]] && ! systemctl is-active -q podman.socket; then
        systemctl start podman.socket
        started_podman="true"
    elif ! systemctl is-active -q --user podman.socket && [[ "${PODMAN}" =~ podman ]]; then
        systemctl start --user podman.socket
        started_podman="true"
    fi

    # Make SBOM
    if [[ -z "$output" ]]; then
        OUTPUT_PATH="$(mktemp -d)/sbom.json"
    else
        OUTPUT_PATH="$output"
    fi
    env SYFT_PARALLELISM="$(nproc)" syft scan "{{ input }}" -o spdx-json="$OUTPUT_PATH"

    # Cleanup
    if [[ "$EUID" -eq "0" && "${started_podman:-}" == "true" ]]; then
        systemctl stop podman.socket
    elif [[ "${started_podman:-}" == "true" ]]; then
        systemctl stop --user podman.socket
    fi

    # Output Path
    echo "$OUTPUT_PATH"

# Add SBOM attestation
[group('CI')]
sbom-sign image $sbom="": install-cosign
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # set SBOM
    if [[ ! -f "$sbom" ]]; then
        sbom="$({{ just }} gen-sbom {{ image }})"
    fi

    # Sign-blob Args
    SBOM_SIGN_ARGS=(
       "--key" "env://COSIGN_PRIVATE_KEY"
       "--output-signature" "$sbom.sig"
       "$sbom"
    )

    # Sign SBOM
    cosign sign-blob -y "${SBOM_SIGN_ARGS[@]}"

    # Verify-blob Args
    SBOM_VERIFY_ARGS=(
        "--key" "cosign.pub"
        "--signature" "$sbom.sig"
        "$sbom"
    )

    # Verify Signature
    cosign verify-blob "${SBOM_VERIFY_ARGS[@]}"

# Utils

GIT_ROOT := justfile_dir()
BUILD_DIR := repo_image_name + "_build"
just := just_executable()

# SUDO

SUDO_DISPLAY := `echo ${DISPLAY:-} || echo ${WAYLAND_DISPLAY:-}`
export SUDOIF := if `id -u` == "0" { "" } else if SUDO_DISPLAY != "" { which("sudo") + " --askpass" } else { which("sudo") }

# Quiet By Default

export SET_X := if `id -u` == "0" { "1" } else { env('SET_X', '') }

# Podman By Default

export PODMAN := env("PODMAN", "") || which("podman") || require("podman-remote")
