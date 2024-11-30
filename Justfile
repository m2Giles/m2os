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
export SUDOIF := if `id -u` == "0" { "" } else { "/usr/bin/sudo" }
export SET_X := if `id -u` == "0" { "1" } else { env_var_or_default('SET_X', '') }
just := just_executable()

[private]
default:
    @{{ just }} --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    /usr/bin/find . -type f -name "*.just" | while /usr/bin/read -r file; do
        /usr/bin/echo "Checking syntax: $file"
        {{ just }} --unstable --fmt --check -f $file
    done
    /usr/bin/echo "Checking syntax: Justfile"
    {{ just }} --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    /usr/bin/find . -type f -name "*.just" | while /usr/bin/read -r file; do
        /usr/bin/echo "Checking syntax: $file"
        {{ just }} --unstable --fmt -f $file
    done
    /usr/bin/echo "Checking syntax: Justfile"
    {{ just }} --unstable --fmt -f Justfile || { exit 1; }

# Cleanup
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -euox pipefail
    /usr/bin/touch {{ repo_image_name }}_
    ${SUDOIF} find {{ repo_image_name }}_* -type d -exec chmod 0755 {} \;
    ${SUDOIF} find {{ repo_image_name }}_* -type f -exec chmod 0644 {} \;
    /usr/bin/find {{ repo_image_name }}_* -maxdepth 0 -exec rm -rf {} \;
    /usr/bin/rm -f output*.env changelog*.md version.txt previous.manifest.json

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
        {{ just }} verify-container ${BASE_IMAGE}:${TAG_VERSION}
        /usr/bin/skopeo inspect docker://ghcr.io/ublue-os/${BASE_IMAGE}:${TAG_VERSION} > /tmp/inspect-"{{ image }}".json
        fedora_version="$(/usr/bin/jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json | /usr/bin/grep -oP 'fc\K[0-9]+')"
        ;;
    "bazzite"*)
        BASE_IMAGE=${check}
        TAG_VERSION=stable
        {{ just }} verify-container ${BASE_IMAGE}:${TAG_VERSION}
        /usr/bin/skopeo inspect docker://ghcr.io/ublue-os/${BASE_IMAGE}:${TAG_VERSION} > /tmp/inspect-"{{ image }}".json
        fedora_version="$(/usr/bin/jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json | /usr/bin/grep -oP 'fc\K[0-9]+')"
        ;;
    "cosmic"*)
        {{ just }} verify-container bluefin:stable-daily
        fedora_version="$(/usr/bin/skopeo inspect docker://ghcr.io/ublue-os/bluefin:stable-daily | /usr/bin/jq -r '.Labels["ostree.linux"]' | /usr/bin/grep -oP 'fc\K[0-9]+')"
        {{ just }} verify-container coreos-stable-kernel:${fedora_version}
        BASE_IMAGE=base-main
        TAG_VERSION=${fedora_version}
        {{ just }} verify-container ${BASE_IMAGE}:${TAG_VERSION}
        /usr/bin/skopeo inspect docker://ghcr.io/ublue-os/coreos-stable-kernel:${fedora_version} > /tmp/inspect-"{{ image }}".json
        ;;
    "ucore"*)
        BASE_IMAGE=ucore
        TAG_VERSION=${check}
        {{ just }} verify-container ${BASE_IMAGE}:${TAG_VERSION}
        fedora_version="$(/usr/bin/skopeo inspect docker://ghcr.io/ublue-os/ucore:${check} | /usr/bin/jq -r '.Labels["ostree.linux"]' | /usr/bin/grep -oP 'fc\K[0-9]+')"
        {{ just }} verify-container coreos-stable-kernel:${fedora_version}
        /usr/bin/skopeo inspect docker://ghcr.io/ublue-os/coreos-stable-kernel:${fedora_version} > /tmp/inspect-"{{ image }}".json
        ;;
    esac
    BUILD_ARGS+=("--label" "org.opencontainers.image.title={{ repo_image_name }}")
    BUILD_ARGS+=("--label" "org.opencontainers.image.version={{ image }}-${fedora_version}.$(date +%Y%m%d)")
    BUILD_ARGS+=("--label" "ostree.linux=$(/usr/bin/jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json)")
    BUILD_ARGS+=("--label" "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses.")
    BUILD_ARGS+=("--build-arg" "IMAGE={{ image }}")
    BUILD_ARGS+=("--build-arg" "BASE_IMAGE=$BASE_IMAGE")
    BUILD_ARGS+=("--build-arg" "TAG_VERSION=$TAG_VERSION")
    BUILD_ARGS+=("--build-arg" "SET_X=${SET_X:-}")
    BUILD_ARGS+=("--tag" "localhost/{{ repo_image_name }}:{{ image }}")
    BUILD_ARGS+=("--format" "docker")
    /usr/bin/buildah build "${BUILD_ARGS[@]}" .

    if [[ "${UID}" -gt "0" ]]; then
        {{ just }} rechunk {{ image }}
    else
        /usr/bin/podman rmi ghcr.io/ublue-os/"${BASE_IMAGE}":"${TAG_VERSION}"
    fi

# Rechunk Image
[private]
rechunk image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    ID=$(/usr/bin/podman images --filter reference=localhost/{{ repo_image_name }}:{{ image }} --format "'{{ '{{.ID}}' }}'")

    if [[ -z "$ID" ]]; then
        {{ just }} build {{ image }}
    fi

    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} /usr/bin/podman image scp ${UID}@localhost::localhost/{{ repo_image_name }}:{{ image }} root@localhost::localhost/{{ repo_image_name }}:{{ image }}
    fi

    CREF=$(${SUDOIF} /usr/bin/podman create localhost/{{ repo_image_name }}:{{ image }} /usr/bin/bash)
    MOUNT=$(${SUDOIF} /usr/bin/podman mount $CREF)
    FEDORA_VERSION="$(${SUDOIF} /usr/bin/podman inspect $CREF | /usr/bin/jq -r '.[]["Config"]["Labels"]["ostree.linux"]' | /usr/bin/grep -oP 'fc\K[0-9]+')"
    OUT_NAME="{{ repo_image_name }}_{{ image }}"
    VERSION="{{ image }}-${FEDORA_VERSION}.$(date +%Y%m%d)"
    LABELS="
        org.opencontainers.image.title={{ repo_image_name }}:{{ image }}
        org.opencontainers.image.revision=$(git rev-parse HEAD)
        ostree.linux=$(/usr/bin/podman inspect localhost/{{ repo_image_name }}:{{ image }} | /usr/bin/jq -r '.[].["Config"]["Labels"]["ostree.linux"]')
        org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses."
    ${SUDOIF} /usr/bin/podman run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/1_prune.sh
    ${SUDOIF} /usr/bin/podman run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --volume "cache_ostree:/var/ostree" \
        --env TREE=/var/tree \
        --env REPO=/var/ostree/repo \
        --env RESET_TIMESTAMP=1 \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/2_create.sh
    ${SUDOIF} /usr/bin/podman unmount "$CREF"
    ${SUDOIF} /usr/bin/podman rm "$CREF"
    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} /usr/bin/podman rmi localhost/{{ repo_image_name }}:{{ image }}
    fi
    /usr/bin/podman rmi localhost/{{ repo_image_name }}:{{ image }}
    ${SUDOIF} /usr/bin/podman run --rm \
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

    ${SUDOIF} /usr/bin/find {{ repo_image_name }}_{{ image }} -type d -exec chmod 0755 {} \; || true
    ${SUDOIF} /usr/bin/find {{ repo_image_name }}_{{ image }}* -type f -exec chmod 0644 {} \; || true
    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} /usr/bin/chown -R ${UID}:${GROUPS} "${PWD}"
    elif [[ "${UID}" == "0" && -n "${SUDO_USER:-}" ]]; then
        ${SUDOIF} /usr/bin/chown -R ${SUDO_UID}:${SUDO_GID} "${PWD}"
    fi

    ${SUDOIF} /usr/bin/podman volume rm cache_ostree

# Load Image into Podman and Tag
[private]
load-image image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    IMAGE=$(/usr/bin/podman pull oci:${PWD}/{{ repo_image_name }}_{{ image }})
    /usr/bin/podman tag ${IMAGE} localhost/{{ repo_image_name }}:{{ image }}
    VERSION=$(/usr/bin/podman inspect $IMAGE | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')
    /usr/bin/podman tag ${IMAGE} localhost/{{ repo_image_name }}:${VERSION}
    /usr/bin/podman images
    /usr/bin/rm -rf {{ repo_image_name }}_{{ image }}

# Get Tags
get-tags image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    VERSION=$(/usr/bin/podman inspect {{ repo_image_name }}:{{ image }} | /usr/bin/jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')
    /usr/bin/echo "{{ image }} $VERSION"

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
    {{ just }} verify-container "build-container-installer" "ghcr.io/jasonn3" "https://raw.githubusercontent.com/JasonN3/build-container-installer/refs/heads/main/cosign.pub"

    /usr/bin/mkdir -p {{ repo_image_name }}_build/{lorax_templates,flatpak-refs-{{ image }},output}
    /usr/bin/echo 'append etc/anaconda/profile.d/fedora-kinoite.conf "\\n[User Interface]\\nhidden_spokes =\\n    PasswordSpoke"' \
         > {{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl

    # Build from GHCR or localhost
    if [[ "{{ ghcr }}" == "1" ]]; then
        IMAGE_FULL=ghcr.io/{{ repo_name }}/{{ repo_image_name }}:{{ image }}
        IMAGE_REPO=ghcr.io/{{ repo_name }}
        # Verify Container for ISO
        {{ just }} verify-container "{{ repo_image_name }}:{{ image }}" "${IMAGE_REPO}" "https://raw.githubusercontent.com/{{ repo_name }}/{{ repo_image_name }}/refs/heads/main/cosign.pub"
        /usr/bin/podman pull "${IMAGE_FULL}"
        TEMPLATES=(
            /github/workspace/{{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl
        )
    else
        IMAGE_FULL=localhost/{{ repo_image_name }}:{{ image }}
        IMAGE_REPO=localhost
        ID=$(/usr/bin/podman images --filter reference=${IMAGE_FULL} --format "'{{ '{{.ID}}' }}'")
        if [[ -z "$ID" ]]; then
            {{ just }} build {{ image }}
        fi
        TEMPLATES=(
            /github/workspace/{{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl
        )
    fi

    # Check if ISO already exists. Remove it.
    if [[ -f "{{ repo_image_name }}_build/output/{{ image }}.iso" || -f "{{ repo_image_name }}_build/output/{{ image }}.iso-CHECKSUM" ]]; then
        /usr/bin/rm -f {{ repo_image_name }}_build/output/{{ image }}.iso*
    fi

    # Load image into rootful podman
    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} /usr/bin/podman image scp "${UID}"@localhost::"${IMAGE_FULL}" root@localhost::"${IMAGE_FULL}"
    fi

    # Generate Flatpak List
    TEMP_FLATPAK_INSTALL_DIR="$(/usr/bin/mktemp -d -p /tmp flatpak-XXXXX)"
    FLATPAK_REFS_DIR="{{ repo_image_name }}_build/flatpak-refs-{{ image }}"
    FLATPAK_REFS_DIR_ABS="$(/usr/bin/realpath ${FLATPAK_REFS_DIR})"
    /usr/bin/mkdir -p "${FLATPAK_REFS_DIR_ABS}"
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
    /usr/bin/curl -Lo ${FLATPAK_REFS_DIR_ABS}/flatpaks.txt "${FLATPAK_LIST_URL}"
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
    while IFS= /usr/bin/read -r line; do
    FLATPAK_REFS+=("$line")
    done < "${FLATPAK_REFS_DIR}/flatpaks.txt"
    FLATPAK_REFS+=("${ADDITIONAL_FLATPAKS[@]}")
    /usr/bin/echo "Flatpak refs: ${FLATPAK_REFS[@]}"
    # Generate installation script
    /usr/bin/tee "${TEMP_FLATPAK_INSTALL_DIR}/install-flatpaks.sh"<<EOF
    /usr/bin/mkdir -p /flatpak/flatpak /flatpak/triggers
    /usr/bin/mkdir /var/tmp
    /usr/bin/chmod -R 1777 /var/tmp
    /usr/bin/flatpak config --system --set languages "*"
    /usr/bin/flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
    /usr/bin/flatpak install --system -y flathub ${FLATPAK_REFS[@]}
    /usr/bin/ostree refs --repo=\${FLATPAK_SYSTEM_DIR}/repo | /usr/bin/grep '^deploy/' | /usr/bin/grep -v 'org\.freedesktop\.Platform\.openh264' | /usr/bin/sed 's/^deploy\///g' > /output/flatpaks-with-deps
    EOF
    # Create Flatpak List
    ${SUDOIF} /usr/bin/podman run --rm --privileged \
    --entrypoint /bin/bash \
    -e FLATPAK_SYSTEM_DIR=/flatpak/flatpak \
    -e FLATPAK_TRIGGERS_DIR=/flatpak/triggers \
    -v ${FLATPAK_REFS_DIR_ABS}:/output \
    -v ${TEMP_FLATPAK_INSTALL_DIR}:/temp_flatpak_install_dir \
    ${IMAGE_FULL} /temp_flatpak_install_dir/install-flatpaks.sh

    VERSION="$(${SUDOIF} /usr/bin/podman inspect ${IMAGE_FULL} | /usr/bin/jq -r '.[]["Config"]["Labels"]["ostree.linux"]' | /usr/bin/grep -oP 'fc\K[0-9]+')"
    if [[ "{{ ghcr }}" == "1" && "{{ clean }}" == "1" ]]; then
        ${SUDOIF} /usr/bin/podman rmi ${IMAGE_FULL}
    fi
    # list Flatpaks
    /usr/bin/cat ${FLATPAK_REFS_DIR}/flatpaks-with-deps
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
    ${SUDOIF} /usr/bin/podman run --rm --privileged --pull=newer --security-opt label=disable "${iso_build_args[@]}"
    if [[ "${UID}" -gt "0" ]]; then
        ${SUDOIF} /usr/bin/chown -R ${UID}:${GROUPS} "${PWD}"
        ${SUDOIF} /usr/bin/podman rmi "${IMAGE_FULL}"
    elif [[ "${UID}" == "0" && -n "${SUDO_USER:-}" ]]; then
        ${SUDOIF} /usr/bin/chown -R ${SUDO_UID}:${SUDO_GID} "${PWD}"
    fi

# Run ISO
[group('ISO')]
run-iso image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    if [[ ! -f "{{ repo_image_name }}_build/output/{{ image }}.iso" ]]; then
        {{ just }} build-iso {{ image }}
    fi
    port=8006;
    while grep -q ${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"
    (sleep 30 && /usr/bin/xdg-open http://localhost:${port})&
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
    /usr/bin/podman run "${run_args[@]}"

# Test Changelogs
[group('Changelogs')]
changelogs branch="stable" urlmd="" handwritten="":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    /usr/bin/python3 changelogs.py {{ branch }} ./output-{{ branch }}.env ./changelog-{{ branch }}.md --workdir . --handwritten "{{ handwritten }}" --urlmd "{{ urlmd }}"

# Verify Container with Cosign
[group('Utility')]
verify-container container="" registry="ghcr.io/ublue-os" key="":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Get Cosign if Needed
    if [[ ! $(/usr/bin/command -v cosign) ]]; then
        COSIGN_CONTAINER_ID=$(${SUDOIF} /usr/bin/podman create cgr.dev/chainguard/cosign:latest /bin/sh)
        ${SUDOIF} /usr/bin/podman cp "${COSIGN_CONTAINER_ID}":/usr/bin/cosign /usr/local/bin/cosign
        ${SUDOIF} /usr/bin/podman rm -f "${COSIGN_CONTAINER_ID}"
    fi

    COSIGN="$(/usr/bin/command -v cosign)"

    # Verify Cosign Image Signatures if needed
    if [[ -n "${COSIGN_CONTAINER_ID:-}" ]]; then
        if ! ${COSIGN} verify --certificate-oidc-issuer=https://token.actions.githubusercontent.com --certificate-identity=https://github.com/chainguard-images/images/.github/workflows/release.yaml@refs/heads/main cgr.dev/chainguard/cosign >/dev/null; then
            /usr/bin/echo "NOTICE: Failed to verify cosign image signatures."
            exit 1
        fi
    fi

    # Public Key for Container Verification
    key={{ key }}
    if [[ -z "${key:-}" && "{{ registry }}" == "ghcr.io/ublue-os" ]]; then
        key="https://raw.githubusercontent.com/ublue-os/main/main/cosign.pub"
    fi

    # Verify Container using cosign public key
    if ! ${COSIGN} verify --key "${key}" "{{ registry }}"/"{{ container }}" >/dev/null; then
        /usr/bin/echo "NOTICE: Verification failed. Please ensure your public key is correct."
        exit 1
    fi

# Secureboot Check
[group('Utility')]
secureboot image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Get the vmlinuz to check
    kernel_release=$(/usr/bin/podman inspect "{{ repo_image_name }}":"{{ image }}" | /usr/bin/jq -r '.[].Config.Labels["ostree.linux"]')
    TMP=$(/usr/bin/podman create "{{ repo_image_name }}":"{{ image }}" /usr/bin/bash)
    podman cp "$TMP":/usr/lib/modules/"${kernel_release}"/vmlinuz /tmp/vmlinuz
    podman rm "$TMP"

    # Get the Public Certificates
    /usr/bin/curl --retry 3 -Lo /tmp/kernel-sign.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key.der
    /usr/bin/curl --retry 3 -Lo /tmp/akmods.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key_2.der
    /usr/bin/openssl x509 -in /tmp/kernel-sign.der -out /tmp/kernel-sign.crt
    /usr/bin/openssl x509 -in /tmp/akmods.der -out /tmp/akmods.crt

    # Make sure we have sbverify
    CMD="$(/usr/bin/command -v sbverify)"
    if [[ -z "${CMD:-}" ]]; then
        temp_name="sbverify-${RANDOM}"
        /usr/bin/podman run -dt \
            --entrypoint /bin/sh \
            --volume /tmp/vmlinuz:/tmp/vmlinuz:z \
            --volume /tmp/kernel-sign.crt:/tmp/kernel-sign.crt:z \
            --volume /tmp/akmods.crt:/tmp/akmods.crt:z \
            --name ${temp_name} \
            alpine:edge
        podman exec ${temp_name} apk add sbsigntool
        CMD="/usr/bin/podman exec ${temp_name} /usr/bin/sbverify"
    fi

    # Confirm that Signatures Are Good
    $CMD --list /tmp/vmlinuz
    returncode=0
    if ! $CMD --cert /tmp/kernel-sign.crt /tmp/vmlinuz || ! $CMD --cert /tmp/akmods.crt /tmp/vmlinuz; then
        /usr/bin/echo "Secureboot Signature Failed...."
        returncode=1
    fi
    if [[ -n "${temp_name:-}" ]]; then
        /usr/bin/podman rm -f "${temp_name}"
    fi
    exit "$returncode"

# Merge Changelogs
merge-changelog:
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    /usr/bin/rm -f changelog.md
    /usr/bin/cat changelog*.md > changelog.md
    last_tag=$(/usr/bin/git tag --list {{ repo_image_name }}-* | /usr/bin/sort -r | /usr/bin/head -1)
    date_extract="$(/usr/bin/echo ${last_tag:-} | /usr/bin/grep -oP 'm2os-\K[0-9]+')"
    date_version="$(/usr/bin/echo ${last_tag:-} | /usr/bin/grep -oP '\.\K[1-9]$' || /usr/bin/true)"
    if [[ "${date_extract:-}" == "$(date +%Y%m%d)" ]]; then
        tag="{{ repo_image_name }}-${date_extract:-}.$(( ${date_version:-} + 1 ))"
    else
        tag="{{ repo_image_name }}-$(date +%Y%m%d)"
    fi
    /usr/bin/cat << EOF
    {
        "title": "$tag (#$(git rev-parse --short HEAD))",
        "tag": "$tag"
    }
    EOF
