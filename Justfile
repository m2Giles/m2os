set unstable := true

# Constants

repo_image_name := lowercase("m2os")
repo_name := lowercase("m2Giles")
IMAGE_REGISTRY := "ghcr.io" / repo_name
FQ_IMAGE_NAME := IMAGE_REGISTRY / repo_image_name

# Images

[private]
images := '(

    # Stable Images
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

    # Beta Images
    [aurora-beta]=' + aurora_beta + '
    [aurora-nvidia-beta]=' + aurora_nvidia_beta + '
    [bazzite-beta]=' + bazzite_beta + '
    [bazzite-deck-beta]=' + bazzite_deck_beta + '
    [bluefin-beta]=' + bluefin_beta + '
    [bluefin-nvidia-beta]=' + bluefin_nvidia_beta + '
    [cosmic-beta]="cosmic"
    [cosmic-nvidia-beta]="cosmic-nvidia-open"
    [ucore-beta]=' + ucore_beta + '
    [ucore-nvidia-beta]=' + ucore_nvidia_beta + '
)'

# Build Containers

[private]
isobuilder := "ghcr.io/jasonn3/build-container-installer:v1.3.0@sha256:c5a44ee1b752fd07309341843f8d9f669d0604492ce11b28b966e36d8297ad29"
[private]
rechunker := "ghcr.io/hhd-dev/rechunk:v1.2.2@sha256:e799d89f9a9965b5b0e89941a9fc6eaab62e9d2d73a0bfb92e6a495be0706907"
[private]
qemu := "ghcr.io/qemus/qemu:7.12@sha256:ab767a6b9c8cf527d521eee9686dce09933bc35599ee58be364eb8f3a03001ea"
[private]
cosign-installer := "cgr.dev/chainguard/cosign:latest@sha256:623d6fc89c114c1ceb5530aa96d609d07d4760959e40631564be22b533d8e253"
[private]
syft-installer := "ghcr.io/anchore/syft:v1.26.0@sha256:de078f51704a213906970b1475edd6006b8af50aa159852e125518237487b8c6"

# Base Containers

[private]
aurora := "ghcr.io/ublue-os/aurora:stable-daily@sha256:b75d2111d6046ebf3afbd2adc25200788b2a799f36e195d1654b517f461e56fa"
[private]
aurora_nvidia := "ghcr.io/ublue-os/aurora-nvidia-open:stable-daily@sha256:b8c718e38a653c3eab9daa281b24c62809e3b7b13f17f23915b352581b11b1fb"
[private]
bazzite := "ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable@sha256:4aac46b21e22113cae4b02133a4c78a697c3c6e927398ed326cb4f67839227d8"
[private]
bazzite_deck := "ghcr.io/ublue-os/bazzite-deck-gnome:stable@sha256:de25f06ba3cdb4454356ab4ecdffb3253c712a8b619633dfcea41e138aa27ba5"
[private]
bluefin := "ghcr.io/ublue-os/bluefin:stable-daily@sha256:3ecdd271ddf98d199f4f983cef35d4188e18ab12d8adc6125d5bff080e73ca83"
[private]
bluefin_nvidia := "ghcr.io/ublue-os/bluefin-nvidia-open:stable-daily@sha256:f981e1368b9469d81f5eefd80c1f9e43005666ecc96ce68491d2eee82e596e8e"
[private]
ucore := "ghcr.io/ublue-os/ucore:stable-zfs@sha256:4dfe5e3ee7d0736bdcc8788fa8ec0feb35dea09c0d2f1b670dce6a320706a79f"
[private]
ucore_nvidia := "ghcr.io/ublue-os/ucore:stable-nvidia-zfs@sha256:17985a44e4a7d555861a43053393b24cc5471b7fc21deb1ba52af3ce3514bd2b"
[private]
aurora_beta := "ghcr.io/ublue-os/aurora:latest@sha256:ee83936936a337764d9249e4a2370dc5c3bdb9869172b1547c7f30e8a8d79265"
[private]
aurora_nvidia_beta := "ghcr.io/ublue-os/aurora-nvidia-open:latest@sha256:1f64dc06e03f0e4a667f651da1b32f39c94864140ea3a54ead5760ba23bd8079"
[private]
bazzite_beta := "ghcr.io/ublue-os/bazzite-gnome-nvidia-open:testing@sha256:c5dcea32679599e2827fdb28edd27beb6d9dfc35ad7917f4ed42c6627956a3ee"
[private]
bazzite_deck_beta := "ghcr.io/ublue-os/bazzite-deck-gnome:testing@sha256:bbb8747ef8b1570f9a2cba69e80832bc4c6fa8db18cb57d2ec51d704bf4173ca"
[private]
bluefin_beta := "ghcr.io/ublue-os/bluefin:latest@sha256:7f7fa79d3b8b104b69e1a05b4740758d9ff9ec34151e338a2c0a4f90d9d73c50"
[private]
bluefin_nvidia_beta := "ghcr.io/ublue-os/bluefin-nvidia-open:latest@sha256:d862d0b36935bac989781cc2806fb6ee02acc64da97e2f2dfcf20a639059a8cf"
[private]
ucore_beta := "ghcr.io/ublue-os/ucore:testing-zfs@sha256:2cd2b1fa619eb81ee98f6ce1fb5b0283a075632ed901587ff4cd59effad97e3e"
[private]
ucore_nvidia_beta := "ghcr.io/ublue-os/ucore:testing-nvidia-zfs@sha256:7e21b7d32a4534186c2c612d09d883d6befa3d0c02f14097cbcd1b1e63fff67a"

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
    {{ SUDOIF }} find {{ repo_image_name }}_* -type d -exec chmod 0755 {} \;
    {{ SUDOIF }} find {{ repo_image_name }}_* -type f -exec chmod 0644 {} \;
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
    {{ if image =~ 'beta' { 'akmods_version="testing"' } else { 'akmods_version="stable"' } }}
    akmods="$(yq -r ".images[] | select(.name == \"akmods-${akmods_version}\")" {{ image-file }} | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"
    akmods_nvidia="$(yq -r ".images[] | select(.name == \"akmods-nvidia-open-${akmods_version}\")" {{ image-file }} | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"
    akmods_zfs="$(yq -r ".images[] | select(.name == \"akmods-zfs-${akmods_version}\")" {{ image-file }} | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"
    case "{{ image }}" in
    "aurora"*|"bazzite"*|"bluefin"*|"ucore"*)
        {{ just }} verify-container "${check#*-os/}"
        if [[ "{{ image }}" =~ bazzite ]]; then
            KERNEL_FLAVOR="bazzite"
        elif [[ "{{ image }}" =~ beta ]]; then
            KERNEL_FLAVOR="coreos-testing"
        else
            KERNEL_FLAVOR="coreos-stable"
        fi
        ;;
    "cosmic"*)
        {{ if image =~ 'beta' { 'bluefin=${images[bluefin]}' } else { 'bluefin="${images[bluefin-beta]}"' } }}
        {{ just }} verify-container "${bluefin#*-os/}"
        fedora_version="$(skopeo inspect docker://"${bluefin/:*@/@}" | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
        check="$(yq -r ".images[] | select(.name == \"base-${fedora_version}\")" {{ image-file }} | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"
        {{ just }} verify-container "${check#*-os/}"
        KERNEL_FLAVOR="$(yq -r ".images[] | select(.name == \"akmods-${akmods_version}\") | .tag" {{ image-file }})"
        KERNEL_FLAVOR="${KERNEL_FLAVOR%-*}"
        ;;
    esac

    if [[ "{{ image }}" =~ cosmic|(aurora.*|bluefin.*)-beta ]]; then
        {{ just }} verify-container "${akmods#*-os/}"
        {{ just }} verify-container "${akmods_nvidia#*-os/}"
        {{ just }} verify-container "${akmods_zfs#*-os/}"
        skopeo inspect docker://"${akmods/:*@/@}" > "$BUILDTMP/inspect-{{ image }}.json"
        BUILD_ARGS+=(
        "--build-arg" "akmods_digest=${akmods#*@}"
        "--build-arg" "akmods_nvidia_digest=${akmods_nvidia#*@}"
        "--build-arg" "akmods_zfs_digest=${akmods_zfs#*@}"
        )
    else
        skopeo inspect docker://"${check/:*@/@}" > "$BUILDTMP/inspect-{{ image }}.json"
    fi

    fedora_version="$(jq -r '.Labels["ostree.linux"]' < "$BUILDTMP/inspect-{{ image }}.json" | grep -oP 'fc\K[0-9]+')"
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
    {{ PODMAN }} pull "$check"

    #Build Args
    BUILD_ARGS+=(
        "--file" "Containerfile"
        "--label" "org.opencontainers.image.source=https://github.com/{{ repo_name }}/{{ repo_image_name }}"
        "--label" "org.opencontainers.image.title={{ repo_image_name }}"
        "--label" "org.opencontainers.image.version=$VERSION"
        "--label" "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses."
        "--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < "$BUILDTMP"/inspect-{{ image }}.json)"
        "--label" "ostree.kernel_flavor=$KERNEL_FLAVOR"
        "--build-arg" "IMAGE={{ image }}"
        "--build-arg" "BASE_IMAGE=${check%%:*}"
        "--build-arg" "TAG_VERSION=${check#*:}"
        "--build-arg" "SET_X=${SET_X:-}"
        "--build-arg" "VERSION=$VERSION"
        "--build-arg" "KERNEL_FLAVOR=$KERNEL_FLAVOR"
        "--tag" "localhost/{{ repo_image_name }}:{{ image }}"
    )
    echo "::endgroup::"

    {{ PODMAN }} build "${BUILD_ARGS[@]}" .

    if [[ -z "${CI:-}" ]]; then
        {{ just }} secureboot localhost/{{ repo_image_name }}:{{ image }}
        {{ just }} rechunk {{ image }}
    else
        {{ PODMAN }} rmi -f "${check%@*}"
    fi

# Rechunk Image
[group('Image')]
rechunk image="bluefin":
    #!/usr/bin/bash
    echo "::group:: Rechunk Build Prep"
    set ${SET_X:+-x} -eou pipefail

    {{ PODMAN }} image exists localhost/{{ repo_image_name }}:{{ image }} || {{ just }} build {{ image }}

    if [[ "${UID}" -gt "0" && "{{ PODMAN }}" =~ podman$ ]]; then
       # Use Podman Unshare, and then exit
       {{ PODMAN }} unshare -- {{ just }} rechunk {{ image }}
       # Exit with previous exit code
       exit "$?"
    fi

    CREF=$({{ PODMAN }} create localhost/{{ repo_image_name }}:{{ image }} bash)
    OUT_NAME="{{ repo_image_name }}_{{ image }}.tar"
    VERSION="$({{ PODMAN }} inspect "$CREF" | jq -r '.[].Config.Labels["org.opencontainers.image.version"]')"
    LABELS="
    org.opencontainers.image.source=https://github.com/{{ repo_name }}/{{ repo_image_name }}
    org.opencontainers.image.title={{ repo_image_name }}:{{ image }}
    org.opencontainers.image.revision=$(git rev-parse HEAD)
    ostree.linux=$({{ PODMAN }} inspect "$CREF" | jq -r '.[].Config.Labels["ostree.linux"]')
    org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses.
    "
    if [[ ! "{{ PODMAN }}" =~ remote ]]; then
        MOUNT=$({{ PODMAN }} mount "$CREF")
    else
        MOUNTFS="{{ BUILD_DIR }}/{{ image }}_rootfs"
        {{ SUDOIF }} rm -rf "$MOUNTFS"
        mkdir -p "$MOUNTFS"
        {{ PODMAN }} export "$CREF" | tar -xf - -C "$MOUNTFS"
        MOUNT="{{ GIT_ROOT }}/$MOUNTFS"
        {{ PODMAN }} rm "$CREF"
        {{ PODMAN }} rmi -f localhost/{{ repo_image_name }}:{{ image }}
    fi
    echo "::endgroup::"

    echo "::group:: Rechunk Prune"
    {{ PODMAN }} run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        {{ rechunker }} \
        /sources/rechunk/1_prune.sh
    echo "::endgroup::"

    echo "::group:: Create Tree"
    {{ PODMAN }} run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --volume "cache_ostree:/var/ostree" \
        --env TREE=/var/tree \
        --env REPO=/var/ostree/repo \
        --env RESET_TIMESTAMP=1 \
        --user 0:0 \
        {{ rechunker }} \
        /sources/rechunk/2_create.sh
    if [[ ! "{{ PODMAN }}" =~ remote ]]; then
        {{ PODMAN }} unmount "$CREF"
        {{ PODMAN }} rm "$CREF"
        {{ PODMAN }} rmi -f localhost/{{ repo_image_name }}:{{ image }}
    else
        {{ SUDOIF }} rm -rf "$MOUNTFS"
    fi
    echo "::endgroup::"

    echo "::group:: Rechunk"
    {{ PODMAN }} run --rm \
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
    {{ PODMAN }} volume rm cache_ostree
    echo "::endgroup::"

# Load Image into Podman and Tag
[group('CI')]
load-image image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    IMAGE=$({{ PODMAN }} pull oci-archive:{{ repo_image_name }}_{{ image }}.tar)
    podman tag "${IMAGE}" localhost/{{ repo_image_name }}:{{ image }}
    VERSION=$(skopeo inspect oci-archive:{{ repo_image_name }}_{{ image }}.tar | jq -r '.Labels["org.opencontainers.image.version"]')
    {{ PODMAN }} tag localhost/{{ repo_image_name }}:{{ image }} localhost/{{ repo_image_name }}:"${VERSION}"
    {{ PODMAN }} images

# Get Tags
[group('CI')]
get-tags image="bluefin":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    VERSION=$({{ PODMAN }} inspect {{ repo_image_name }}:{{ image }} | jq -r '.[].Config.Labels["org.opencontainers.image.version"]')
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
            {{ PODMAN }} pull "${IMAGE_FULL}"
        elif [[ "{{ ghcr }}" == "2" ]]; then
            {{ just }} load-image {{ image }}
            {{ PODMAN }} tag localhost/{{ repo_image_name }}:{{ image }} "$IMAGE_FULL"
        fi
    else
        IMAGE_FULL=localhost/{{ repo_image_name }}:{{ image }}
        {{ PODMAN }} image exists "$IMAGE_FULL" || {{ just }} build {{ image }}
    fi

    # Check if ISO already exists. Remove it.
    if [[ -f "{{ BUILD_DIR }}/output/{{ image }}.iso" || -f "{{ BUILD_DIR }}/output/{{ image }}.iso-CHECKSUM" ]]; then
        rm -f {{ BUILD_DIR }}/output/{{ image }}.iso*
    fi

    # Load image into rootful podman
    if [[ "${UID}" -gt "0" && ! "{{ PODMAN }}" =~ remote ]]; then
        mkdir -p {{ BUILD_DIR }}
        COPYTMP="$(mktemp -dp {{ BUILD_DIR }})"
        {{ SUDOIF }} TMPDIR="${COPYTMP}" {{ PODMAN }} image scp "${UID}"@localhost::"${IMAGE_FULL}" root@localhost::"${IMAGE_FULL}"
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
    *"bazzite"*|*"bluefin"*|*"cosmic"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/bazzite/refs/heads/main/installer/gnome_flatpaks/flatpaks"
    ;;
    esac
    curl -Lo "${FLATPAK_REFS_DIR}"/flatpaks.txt "${FLATPAK_LIST_URL}"
    ADDITIONAL_FLATPAKS=(
        app/com.discordapp.Discord/x86_64/stable
        app/com.google.Chrome/x86_64/stable
        app/com.spotify.Client/x86_64/stable
        app/com.yubico.yubioath/x86_64/stable
        app/it.mijorus.gearlever/x86_64/stable
        app/org.gnome.World.PikaBackup/x86_64/stable
        app/org.keepassxc.KeePassXC/x86_64/stable
        app/org.prismlauncher.PrismLauncher/x86_64/stable
        app/sh.loft.devpod/x86_64/stable
    )
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
    {{ SUDOIF }} {{ PODMAN }} run --rm --privileged \
    --entrypoint /bin/bash \
    -e FLATPAK_SYSTEM_DIR=/flatpak/flatpak \
    -e FLATPAK_TRIGGERS_DIR=/flatpak/triggers \
    -v "${FLATPAK_REFS_DIR_ABS}":/output \
    -v "{{ GIT_ROOT }}/${TEMP_FLATPAK_INSTALL_DIR}":/temp_flatpak_install_dir \
    "${IMAGE_FULL}" /temp_flatpak_install_dir/install-flatpaks.sh

    VERSION="$({{ SUDOIF }} {{ PODMAN }} inspect ${IMAGE_FULL} | jq -r '.[].Config.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
    # VERSION="41"
    if [[ "{{ ghcr }}" -ge "1" && "{{ clean }}" == "1" ]]; then
        {{ SUDOIF }} {{ PODMAN }} rmi ${IMAGE_FULL}
    fi
    # list Flatpaks
    cat "${FLATPAK_REFS_DIR}"/flatpaks-with-deps
    #ISO Container Args
    iso_build_args=()
    if [[ "{{ ghcr }}" == "0" && "{{ PODMAN }}" =~ podman$ ]]; then
        iso_build_args+=(--volume "/var/lib/containers/storage:/var/lib/containers/storage")
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
    if [[ "{{ ghcr }}" == "0" && "{{ PODMAN }}" =~ podman$ ]]; then
        iso_build_args+=(IMAGE_SRC="containers-storage:${IMAGE_FULL}")
    elif [[ "{{ ghcr }}" == "2" ]]; then
        iso_build_args+=(IMAGE_SRC="oci-archive:/github/workspace/{{ repo_image_name }}_{{ image }}.tar")
    fi
    iso_build_args+=(IMAGE_TAG="{{ image }}")
    iso_build_args+=(ISO_NAME="/github/workspace/{{ BUILD_DIR }}/output/{{ image }}.iso")
    iso_build_args+=(SECURE_BOOT_KEY_URL="https://github.com/ublue-os/akmods/raw/main/certs/public_key.der")
    iso_build_args+=(VARIANT="Kinoite")
    # Use F41 for installing
    iso_build_args+=(VERSION="$VERSION")
    iso_build_args+=(WEB_UI="false")
    # Build ISO
    {{ SUDOIF }} {{ PODMAN }} run --rm --privileged --security-opt label=disable "${iso_build_args[@]}"
    if [[ "${UID}" -gt "0" ]]; then
        {{ SUDOIF }} chown -R "${UID}":"${GROUPS[0]}" "$PWD"
        {{ SUDOIF }} {{ PODMAN }} rmi "${IMAGE_FULL}"
    elif [[ "${UID}" == "0" && -n "${SUDO_USER:-}" ]]; then
        {{ SUDOIF }} chown -R "${SUDO_UID}":"${SUDO_GID}" "$PWD"
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
    {{ PODMAN }} run "${run_args[@]}"

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
    kernel_release=$({{ PODMAN }} inspect "{{ image }}" | jq -r '.[].Config.Labels["ostree.linux"]')
    TMP=$({{ PODMAN }} create "{{ image }}" bash)
    TMPDIR="$(mktemp -d -p .)"
    trap 'rm -rf $TMPDIR' EXIT
    {{ PODMAN }} cp "$TMP":/usr/lib/modules/"${kernel_release}"/vmlinuz "$TMPDIR/vmlinuz"
    {{ PODMAN }} rm "$TMP"

    # Get the Public Certificates
    curl --retry 3 -Lo "$TMPDIR"/kernel-sign.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key.der
    curl --retry 3 -Lo "$TMPDIR"/akmods.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key_2.der
    openssl x509 -in "$TMPDIR"/kernel-sign.der -out "$TMPDIR"/kernel-sign.crt
    openssl x509 -in "$TMPDIR"/akmods.der -out "$TMPDIR"/akmods.crt

    # Make sure we have sbverify
    CMD="$(command -v sbverify)" || true
    if [[ -z "${CMD:-}" ]]; then
        temp_name="sbverify-${RANDOM}"
        {{ PODMAN }} run -dt \
            --entrypoint /bin/sh \
            --security-opt label=disable \
            --workdir {{ GIT_ROOT }} \
            --volume "{{ GIT_ROOT }}/$TMPDIR/:{{ GIT_ROOT }}/$TMPDIR" \
            --name ${temp_name} \
            alpine:edge
        {{ PODMAN }} exec "${temp_name}" apk add sbsigntool
        CMD="{{ PODMAN }} exec ${temp_name} /usr/bin/sbverify"
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
        {{ PODMAN }} rm -f "${temp_name}"
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
        {{ just }} _lint-recipe "shellcheck" "$recipe" bluefin
    done
    recipes=(
        clean
        install-cosign
        lint-recipes
        merge-changelog
    )
    for recipe in "${recipes[@]}"; do
        {{ just }} _lint-recipe "shellcheck" "$recipe"
    done

# Get Cosign if Needed
[group('CI')]
install-cosign:
    #!/usr/bin/bash
    set ${SET_X:+-x} -euo pipefail

    # Get Cosign from Chainguard
    if ! command -v cosign >/dev/null; then
        # TMPDIR
        TMPDIR="$(mktemp -d)"
        trap 'rm -rf $TMPDIR' EXIT SIGINT

        # Get Binary
        COSIGN_CONTAINER_ID="$({{ PODMAN }} create {{ cosign-installer }} bash)"
        {{ PODMAN }} cp "${COSIGN_CONTAINER_ID}":/usr/bin/cosign "$TMPDIR"/cosign
        {{ PODMAN }} rm -f "${COSIGN_CONTAINER_ID}"
        {{ PODMAN }} rmi -f {{ cosign-installer }}

        # Install
        {{ SUDOIF }} install -c -m 0755 "$TMPDIR"/cosign /usr/local/bin/cosign

        # Verify Cosign Image Signatures if needed
        if ! cosign verify --certificate-oidc-issuer=https://token.actions.githubusercontent.com --certificate-identity=https://github.com/chainguard-images/images/.github/workflows/release.yaml@refs/heads/main cgr.dev/chainguard/cosign >/dev/null; then
            echo "NOTICE: Failed to verify cosign image signatures."
            exit 1
        fi
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
            skopeo copy "oci-archive:{{ repo_image_name }}_{{ image }}.tar" "$destination/{{ repo_image_name }}:$tag" >&2
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
gen-sbom $input $output="": install-syft
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Make SBOM
    if [[ -z "$output" ]]; then
        OUTPUT_PATH="$(mktemp -d)/sbom.json"
    else
        OUTPUT_PATH="$output"
    fi
    syft scan "{{ input }}" -o spdx-json="$OUTPUT_PATH" --select-catalogers "rpm,+sbom-cataloger"

    # Output Path
    echo "$OUTPUT_PATH"

# Install Syft
[group('CI')]
install-syft:
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Get SYFT if needed
    if ! command -v syft >/dev/null; then
        # Make TMPDIR
        TMPDIR="$(mktemp -d)"
        trap 'rm -rf $TMPDIR' EXIT SIGINT

        # Get Binary
        SYFT_ID="$({{ PODMAN }} create {{ syft-installer }})"
        {{ PODMAN }} cp "$SYFT_ID":/syft "$TMPDIR"/syft
        {{ PODMAN }} rm -f "$SYFT_ID" > /dev/null
        {{ PODMAN }} rmi -f {{ syft-installer }}

        # Install
        {{ SUDOIF }} install -c -m 0755 "$TMPDIR"/syft /usr/local/bin/syft
    fi

# Add SBOM Signing
[group('CI')]
sbom-sign input $sbom="": install-cosign
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # set SBOM
    if [[ ! -f "$sbom" ]]; then
        sbom="$({{ just }} gen-sbom {{ input }})"
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

# SBOM Attest
[group('CI')]
sbom-attest input $sbom="" $destination="": install-cosign
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # set SBOM
    if [[ ! -f "$sbom" ]]; then
        sbom="$({{ just }} gen-sbom {{ input }})"
    fi

    # Compress
    sbom_type="urn:ublue-os:attestation:spdx+json+zstd:v1"
    compress_sbom="$sbom.zst"
    zstd "$sbom" -o "$compress_sbom"

    # Generate Payload
    base64_payload="payload.b64"
    base64 "$compress_sbom" | tr -d '\n' > "$base64_payload"

    # Generate Predicate
    predicate_file="wrapped-predicate.json"
    jq -n \
            --arg compression "zstd" \
            --arg mediaType "application/spdx+json" \
            --rawfile payload "$base64_payload" \
            '{compression: $compression, mediaType: $mediaType, payload: $payload}' \
            > "$predicate_file"

    rm "$base64_payload"

    # SBOM Attest args
    SBOM_ATTEST_ARGS=(
        "--predicate" "$predicate_file"
        "--type" "$sbom_type"
        "--key" "env://COSIGN_PRIVATE_KEY"
    )

    : "${destination:={{ IMAGE_REGISTRY }}}"
    digest="$(skopeo inspect "{{ input }}" --format '{{{{ .Digest }}')"

    cosign attest -y \
        "${SBOM_ATTEST_ARGS[@]}" \
        "$destination/{{ repo_image_name }}@${digest}"

# Utils

[private]
GIT_ROOT := justfile_dir()
[private]
BUILD_DIR := repo_image_name + "_build"
[private]
just := just_executable()
[private]
image-file := GIT_ROOT / "image-versions.yml"
[private]
yq := require("yq")
[private]
jq := require("jq")
[private]
skopeo := require("skopeo")

# SUDO

[private]
SUDO_DISPLAY := env("DISPLAY", "") || env("WAYLAND_DISPLAY", "")
[private]
export SUDOIF := if `id -u` == "0" { "" } else if SUDO_DISPLAY != "" { which("sudo") + " --askpass" } else { which("sudo") }

# Quiet By Default

[private]
export SET_X := if `id -u` == "0" { "1" } else { env("SET_X", "") }

# Podman By Default

[private]
export PODMAN := env("PODMAN", "") || which("podman") || require("podman-remote")
