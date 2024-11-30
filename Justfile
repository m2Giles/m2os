repo_image_name := "m2os"
repo_name := "m2giles"
username := "m2"
images := '(
    [aurora]="aurora"
    [aurora-nvidia]="aurora-nvidia"
    [bazzite]="bazzite-gnome-nvidia"
    [bazzite-deck]="bazzite-deck-gnome"
    [bluefin]="bluefin"
    [bluefin-nvidia]="bluefin-nvidia"
    [cosmic]="cosmic"
    [cosmic-nvidia]="cosmic-nvidia"
    [ucore]="stable-zfs"
    [ucore-nvidia]="stable-nvidia-zfs"
)'
export SUDOIF := if `id -u` == "0" { "" } else { "sudo" }
export SET_X := if `id -u` == "0" { "1" } else { "" }

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Cleanup
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -euox pipefail
    touch {{ repo_image_name }}_
    ${SUDOIF} find {{ repo_image_name }}_* -type d -exec chmod 0755 {} \;
    ${SUDOIF} find {{ repo_image_name }}_* -type f -exec chmod 0644 {} \;
    find {{ repo_image_name }}_* -maxdepth 0 -exec rm -rf {} \;
    rm -f output*.env changelog*.md version.txt previous.manifest.json

# Build Image
[group('Image')]
build image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    declare -A images={{ images }}
    check=${images[{{ image }}]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    BUILD_ARGS=()
    case "{{ image }}" in
    "aurora"*|"bluefin"*)
        BASE_IMAGE=${check}
        TAG_VERSION=stable-daily
        just verify-container ${BASE_IMAGE}:${TAG_VERSION}
        skopeo inspect docker://ghcr.io/ublue-os/${BASE_IMAGE}:${TAG_VERSION} > /tmp/inspect-"{{ image }}".json
        fedora_version="$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json | grep -oP 'fc\K[0-9]+')"
        ;;
    "bazzite"*)
        BASE_IMAGE=${check}
        TAG_VERSION=stable
        just verify-container ${BASE_IMAGE}:${TAG_VERSION}
        skopeo inspect docker://ghcr.io/ublue-os/${BASE_IMAGE}:${TAG_VERSION} > /tmp/inspect-"{{ image }}".json
        fedora_version="$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json | grep -oP 'fc\K[0-9]+')"
        ;;
    "cosmic"*)
        just verify-container bluefin:stable-daily
        fedora_version="$(skopeo inspect docker://ghcr.io/ublue-os/bluefin:stable-daily | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
        just verify-container coreos-stable-kernel:${fedora_version}
        BASE_IMAGE=base-main
        TAG_VERSION=${fedora_version}
        just verify-container ${BASE_IMAGE}:${TAG_VERSION}
        skopeo inspect docker://ghcr.io/ublue-os/coreos-stable-kernel:${fedora_version} > /tmp/inspect-"{{ image }}".json
        ;;
    "ucore"*)
        BASE_IMAGE=ucore
        TAG_VERSION=${check}
        just verify-container ${BASE_IMAGE}:${TAG_VERSION}
        fedora_version="$(skopeo inspect docker://ghcr.io/ublue-os/ucore:${check} | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
        just verify-container coreos-stable-kernel:${fedora_version}
        skopeo inspect docker://ghcr.io/ublue-os/coreos-stable-kernel:${fedora_version} > /tmp/inspect-"{{ image }}".json
        ;;
    esac
    BUILD_ARGS+=("--label" "org.opencontainers.image.title={{ repo_image_name }}")
    BUILD_ARGS+=("--label" "org.opencontainers.image.version={{ image }}-${fedora_version}.$(date +%Y%m%d)")
    BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json)")
    BUILD_ARGS+=("--build-arg" "IMAGE={{ image }}")
    BUILD_ARGS+=("--build-arg" "BASE_IMAGE=$BASE_IMAGE")
    BUILD_ARGS+=("--build-arg" "TAG_VERSION=$TAG_VERSION")
    BUILD_ARGS+=("--build-arg" "SET_X=${SET_X:-}")
    BUILD_ARGS+=("--tag" "localhost/{{ repo_image_name }}:{{ image }}")
    podman pull ghcr.io/ublue-os/"${BASE_IMAGE}":"${TAG_VERSION}"
    buildah build --format docker --label "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses." ${BUILD_ARGS[@]} .

    if [[ "${UID}" -gt "0" ]]; then
        just rechunk {{ image }}
    else
        podman rmi ghcr.io/ublue-os/"${BASE_IMAGE}":"${TAG_VERSION}"
    fi

# Rechunk Image
[private]
rechunk image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    ID=$(podman images --filter reference=localhost/{{ repo_image_name }}:{{ image }} --format "'{{ '{{.ID}}' }}'")

    if [[ -z "$ID" ]]; then
        just build {{ image }}
    fi

    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} podman image scp ${UID}@localhost::localhost/{{ repo_image_name }}:{{ image }} root@localhost::localhost/{{ repo_image_name }}:{{ image }}
    fi

    CREF=$(${SUDOIF} podman create localhost/{{ repo_image_name }}:{{ image }} bash)
    MOUNT=$(${SUDOIF} podman mount $CREF)
    FEDORA_VERSION="$(${SUDOIF} podman inspect $CREF | jq -r '.[]["Config"]["Labels"]["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
    OUT_NAME="{{ repo_image_name }}_{{ image }}"
    VERSION="{{ image }}-${FEDORA_VERSION}.$(date +%Y%m%d)"
    LABELS="
        org.opencontainers.image.title={{ repo_image_name }}:{{ image }}
        org.opencontainers.image.revision=$(git rev-parse HEAD)
        ostree.linux=$(podman inspect localhost/{{ repo_image_name }}:{{ image }} | jq -r '.[].["Config"]["Labels"]["ostree.linux"]')
        org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses."
    ${SUDOIF} podman run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/1_prune.sh
    ${SUDOIF} podman run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --volume "cache_ostree:/var/ostree" \
        --env TREE=/var/tree \
        --env REPO=/var/ostree/repo \
        --env RESET_TIMESTAMP=1 \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/2_create.sh
    ${SUDOIF} podman unmount "$CREF"
    ${SUDOIF} podman rm "$CREF"
    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} podman rmi localhost/{{ repo_image_name }}:{{ image }}
    fi
    podman rmi localhost/{{ repo_image_name }}:{{ image }}
    ${SUDOIF} podman run --rm \
        --pull=newer \
        --security-opt label=disable \
        --volume "$PWD:/workspace" \
        --volume "$PWD:/var/git" \
        --volume cache_ostree:/var/ostree \
        --env REPO=/var/ostree/repo \
        --env PREV_REF=ghcr.io/{{ repo_name }}/{{ repo_image_name }}:{{ image }} \
        --env LABELS="$LABELS" \
        --env OUT_NAME="$OUT_NAME" \
        --env VERSION="$VERSION" \
        --env VERSION_FN=/workspace/version.txt \
        --env OUT_REF="oci:$OUT_NAME" \
        --env GIT_DIR="/var/git" \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/3_chunk.sh

    ${SUDOIF} find {{ repo_image_name }}_{{ image }} -type d -exec chmod 0755 {} \; || true
    ${SUDOIF} find {{ repo_image_name }}_{{ image }}* -type f -exec chmod 0644 {} \; || true
    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} chown -R ${UID}:${GROUPS} "${PWD}"
    elif [[ "${UID}" == "0" && -n "${SUDO_USER:-}" ]]; then
        ${SUDOIF} chown -R ${SUDO_UID}:${SUDO_GID} "${PWD}"
    fi

    ${SUDOIF} podman volume rm cache_ostree

# Load Image into Podman and Tag
[private]
load-image image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    IMAGE=$(podman pull oci:${PWD}/{{ repo_image_name }}_{{ image }})
    podman tag ${IMAGE} localhost/{{ repo_image_name }}:{{ image }}
    VERSION=$(podman inspect $IMAGE | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')
    podman tag ${IMAGE} localhost/{{ repo_image_name }}:${VERSION}
    podman images
    rm -rf {{ repo_image_name }}_{{ image }}

# Get Tags
get-tags image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    VERSION=$(podman inspect {{ repo_image_name }}:{{ image }} | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')
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
    just verify-container "build-container-installer" "ghcr.io/jasonn3" "https://raw.githubusercontent.com/JasonN3/build-container-installer/refs/heads/main/cosign.pub"

    mkdir -p {{ repo_image_name }}_build/{lorax_templates,flatpak-refs-{{ image }},output}
    echo 'append etc/anaconda/profile.d/fedora-kinoite.conf "\\n[User Interface]\\nhidden_spokes =\\n    PasswordSpoke"' \
         > {{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl

    # Build from GHCR or localhost
    if [[ "{{ ghcr }}" == "1" ]]; then
        IMAGE_FULL=ghcr.io/{{ repo_name }}/{{ repo_image_name }}:{{ image }}
        IMAGE_REPO=ghcr.io/{{ repo_name }}
        # Verify Container for ISO
        just verify-container "{{ repo_image_name }}:{{ image }}" "${IMAGE_REPO}" "https://raw.githubusercontent.com/{{ repo_name }}/{{ repo_image_name }}/refs/heads/main/cosign.pub"
        podman pull "${IMAGE_FULL}"
        TEMPLATES=(
            /github/workspace/{{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl
        )
    else
        IMAGE_FULL=localhost/{{ repo_image_name }}:{{ image }}
        IMAGE_REPO=localhost
        ID=$(podman images --filter reference=${IMAGE_FULL} --format "'{{ '{{.ID}}' }}'")
        if [[ -z "$ID" ]]; then
            just build {{ image }}
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
    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} podman image scp "${UID}"@localhost::"${IMAGE_FULL}" root@localhost::"${IMAGE_FULL}"
    fi

    # Generate Flatpak List
    TEMP_FLATPAK_INSTALL_DIR="$(mktemp -d -p /tmp flatpak-XXXXX)"
    FLATPAK_REFS_DIR="{{ repo_image_name }}_build/flatpak-refs-{{ image }}"
    FLATPAK_REFS_DIR_ABS="$(realpath ${FLATPAK_REFS_DIR})"
    mkdir -p "${FLATPAK_REFS_DIR_ABS}"
    case "{{ image }}" in
    *"aurora"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/bluefin/refs/heads/main/aurora_flatpaks/flatpaks"
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
    curl -Lo ${FLATPAK_REFS_DIR_ABS}/flatpaks.txt "${FLATPAK_LIST_URL}"
        ADDITIONAL_FLATPAKS=(
            app/com.discordapp.Discord/x86_64/stable
            app/com.google.Chrome/x86_64/stable
            app/com.microsoft.Edge/x86_64/stable
            app/com.spotify.Client/x86_64/stable
            app/org.gimp.GIMP/x86_64/stable
            app/org.keepassxc.KeePassXC/x86_64/stable
            app/org.libreoffice.LibreOffice/x86_64/stable
            app/org.prismlauncher.PrismLauncher/x86_64/stable
    )
    if [[ "{{ image }}" =~ cosmic ]]; then
        ADDITIONAL_FLATPAKS+=(app/org.gnome.World.PikaBackup/x86_64/stable)
    fi
    if [[ "{{ image }}" =~ aurora|bluefin|cosmic ]]; then
        ADDITIONAL_FLATPAKS+=(
            app/com.github.Matoking.protontricks/x86_64/stable
            app/io.github.fastrizwaan.WineZGUI/x86_64/stable
            app/it.mijorus.gearlever/x86_64/stable
            app/com.vysp3r.ProtonPlus/x86_64/stable
            runtime/org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/23.08
            runtime/org.freedesktop.Platform.VulkanLayer.vkBasalt/x86_64/23.08
            runtime/org.freedesktop.Platform.VulkanLayer.OBSVkCapture/x86_64/23.08
            runtime/com.obsproject.Studio.Plugin.OBSVkCapture/x86_64/stable
            runtime/com.obsproject.Studio.Plugin.Gstreamer/x86_64/stable
            runtime/com.obsproject.Studio.Plugin.GStreamerVaapi/x86_64/stable
            runtime/org.gtk.Gtk3theme.adw-gtk3/x86_64/3.22
            runtime/org.gtk.Gtk3theme.adw-gtk3-dark/x86_64/3.22
    )
    fi
    if [[ "{{ image }}" =~ bazzite ]]; then
        ADDITIONAL_FLATPAKS+=(app/org.gnome.World.PikaBackup/x86_64/stable)
    fi
    FLATPAK_REFS=()
    while IFS= read -r line; do
    FLATPAK_REFS+=("$line")
    done < "${FLATPAK_REFS_DIR}/flatpaks.txt"
    FLATPAK_REFS+=("${ADDITIONAL_FLATPAKS[@]}")
    echo "Flatpak refs: ${FLATPAK_REFS[@]}"
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
    ${SUDOIF} podman run --rm --privileged \
    --entrypoint /bin/bash \
    -e FLATPAK_SYSTEM_DIR=/flatpak/flatpak \
    -e FLATPAK_TRIGGERS_DIR=/flatpak/triggers \
    -v ${FLATPAK_REFS_DIR_ABS}:/output \
    -v ${TEMP_FLATPAK_INSTALL_DIR}:/temp_flatpak_install_dir \
    ${IMAGE_FULL} /temp_flatpak_install_dir/install-flatpaks.sh

    VERSION="$(${SUDOIF} podman inspect ${IMAGE_FULL} | jq -r '.[]["Config"]["Labels"]["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
    if [[ "{{ ghcr }}" == "1" && "{{ clean }}" == "1" ]]; then
        ${SUDOIF} podman rmi ${IMAGE_FULL}
    fi
    # list Flatpaks
    cat ${FLATPAK_REFS_DIR}/flatpaks-with-deps
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
    ${SUDOIF} podman run --rm --privileged --pull=newer --security-opt label=disable "${iso_build_args[@]}"
    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} chown -R ${UID}:${GROUPS} "${PWD}"
        ${SUDOIF} podman rmi "${IMAGE_FULL}"
    elif [[ "${UID}" == "0" && -n "${SUDO_USER:-}" ]]; then
        ${SUDOIF} chown -R ${SUDO_UID}:${SUDO_GID} "${PWD}"
    fi

# Run ISO
[group('ISO')]
run-iso image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    if [[ ! -f "{{ repo_image_name }}_build/output/{{ image }}.iso" ]]; then
        just build-iso {{ image }}
    fi
    port=8006;
    while grep -q ${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"
    (sleep 30 && xdg-open http://localhost:${port})&
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
    podman run "${run_args[@]}"

# Test Changelogs
[group('Changelogs')]
changelogs branch="stable" urlmd="" handwritten="":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    python3 changelogs.py {{ branch }} ./output-{{ branch }}.env ./changelog-{{ branch }}.md --workdir . --handwritten "{{ handwritten }}" --urlmd "{{ urlmd }}"

# Verify Container with Cosign
[group('Utility')]
verify-container container="" registry="ghcr.io/ublue-os" key="":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Get Cosign if Needed
    if [[ ! $(command -v cosign) ]]; then
        COSIGN_CONTAINER_ID=$(${SUDOIF} podman create cgr.dev/chainguard/cosign:latest bash)
        ${SUDOIF} podman cp "${COSIGN_CONTAINER_ID}":/usr/bin/cosign /usr/local/bin/cosign
        ${SUDOIF} podman rm -f "${COSIGN_CONTAINER_ID}"
    fi

    # Verify Cosign Image Signatures if needed
    if [[ -n "${COSIGN_CONTAINER_ID:-}" ]]; then
        if ! cosign verify --certificate-oidc-issuer=https://token.actions.githubusercontent.com --certificate-identity=https://github.com/chainguard-images/images/.github/workflows/release.yaml@refs/heads/main cgr.dev/chainguard/cosign >/dev/null; then
            echo "NOTICE: Failed to verify cosign image signatures."
            exit 1
        fi
    fi

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
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Get the vmlinuz to check
    kernel_release=$(podman inspect "{{ repo_image_name }}":"{{ image }}" | jq -r '.[].Config.Labels["ostree.linux"]')
    TMP=$(podman create "{{ repo_image_name }}":"{{ image }}" bash)
    podman cp "$TMP":/usr/lib/modules/"${kernel_release}"/vmlinuz /tmp/vmlinuz
    podman rm "$TMP"

    # Get the Public Certificates
    curl --retry 3 -Lo /tmp/kernel-sign.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key.der
    curl --retry 3 -Lo /tmp/akmods.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key_2.der
    openssl x509 -in /tmp/kernel-sign.der -out /tmp/kernel-sign.crt
    openssl x509 -in /tmp/akmods.der -out /tmp/akmods.crt

    # Make sure we have sbverify
    CMD="$(command -v sbverify)"
    if [[ -z "${CMD:-}" ]]; then
        temp_name="sbverify-${RANDOM}"
        podman run -dt \
            --entrypoint /bin/sh \
            --volume /tmp/vmlinuz:/tmp/vmlinuz:z \
            --volume /tmp/kernel-sign.crt:/tmp/kernel-sign.crt:z \
            --volume /tmp/akmods.crt:/tmp/akmods.crt:z \
            --name ${temp_name} \
            alpine:edge
        podman exec ${temp_name} apk add sbsigntool
        CMD="podman exec ${temp_name} /usr/bin/sbverify"
    fi

    # Confirm that Signatures Are Good
    $CMD --list /tmp/vmlinuz
    returncode=0
    if ! $CMD --cert /tmp/kernel-sign.crt /tmp/vmlinuz || ! $CMD --cert /tmp/akmods.crt /tmp/vmlinuz; then
        echo "Secureboot Signature Failed...."
        returncode=1
    fi
    if [[ -n "${temp_name:-}" ]]; then
        podman rm -f "${temp_name}"
    fi
    exit "$returncode"

# Merge Changelogs
merge-changelog:
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    rm -f changelog.md
    cat changelog*.md > changelog.md
    last_tag=$(git tag --list {{ repo_image_name }}-* | sort -r | head -1)
    date_extract="$(echo ${last_tag:-} | cut -d "-" -f 2 | cut -d "." -f 1)"
    date_version="$(echo ${last_tag:-} | cut -d "." -f 2)"
    if [[ "${date_extract:-}" == "$(date +%Y%m%d)" ]]; then
        tag="{{ repo_image_name }}-${date_extract:-}.$(( ${date_version:-} + 1 ))"
    else
        tag="{{ repo_image_name }}-$(date +%Y%m%d).0"
    fi
    cat << EOF
    {
        "title": "$tag (#$(git rev-parse --short HEAD))",
        "tag": "$tag"
    }
    EOF
