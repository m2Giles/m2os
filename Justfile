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

[private]
default:
    @just --list

# Check Just Syntax
just-check:
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
just-fix:
    just --unstable --fmt -f Justfile || { exit 1; }

# Build m2os Image
build image="bluefin" target="":
    #!/usr/bin/bash
    set -eou pipefail
    declare -A images={{ images }}
    image={{ image }}
    target={{ target }}
    if [[ "${image}" =~ -beta$ ]]; then
        target="beta"
        image=${image:0:-5}
    fi
    if [[ "$target" != beta]]
    check=${images[$image]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    if [[ "${target}" == "beta" ]]; then
        just build-beta "${image}" 
        exit 0
    fi
    BUILD_ARGS=()
    BUILD_ARGS+=("--label" "org.opencontainers.image.title=m2os")
    BUILD_ARGS+=("--label" "org.opencontainers.image.version=localbuild")
    BUILD_ARGS+=("--build-arg" "IMAGE=${image}")
    case "${image}" in
    "aurora"*|"bluefin"*)
        skopeo inspect docker://ghcr.io/ublue-os/bluefin:stable-daily > /tmp/inspect.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${image}")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=stable-daily")
        BUILD_ARGS+=("--tag" "localhost/m2os:${image}")
        ;;
    "bazzite"*)
        skopeo inspect docker://ghcr.io/ublue-os/bazzite:stable > /tmp/inspect.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${check}")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=stable")
        BUILD_ARGS+=("--tag" "localhost/m2os:${image}")
        ;;
    "cosmic"*)
        skopeo inspect docker://ghcr.io/ublue-os/bluefin:stable-daily > /tmp/inspect.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=base-main")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect.json | grep -oP 'fc\K[0-9]+')")
        BUILD_ARGS+=("--tag" "localhost/m2os:${image}")
        ;;
    "ucore"*)
        skopeo inspect docker://ghcr.io/ublue-os/ucore:${check} > /tmp/inspect.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=ucore-hci")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=${check}")
        BUILD_ARGS+=("--tag" "localhost/m2os:${image}")
        ;;
    esac
    buildah build --format docker --label "org.opencontainers.image.description=m2os is my OCI image built from ublue projects. It mainly extends them for my uses." ${BUILD_ARGS[@]} .

# Build m2os Beta Image
[private]
build-beta image="bluefin":
    #!/usr/bin/bash
    set -eou pipefail
    declare -A images={{ images }}
    image={{ image }}
    check=${images[$image]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    BUILD_ARGS=()
    BUILD_ARGS+=("--label" "org.opencontainers.image.title=m2os")
    BUILD_ARGS+=("--label" "org.opencontainers.image.version=localbuild-$(date +%Y%m%d-%H:%M:%S)")
    BUILD_ARGS+=("--build-arg" "IMAGE=${image}")
    case "${image}" in
    "aurora"*|"bluefin"*)
        skopeo inspect docker://ghcr.io/ublue-os/bluefin:beta > /tmp/inspect.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${image}")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=beta")
        BUILD_ARGS+=("--tag" "localhost/m2os:${image}")
        ;;
    "bazzite"*)
        skopeo inspect docker://ghcr.io/ublue-os/bazzite:unstable > /tmp/inspect.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${check}")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=unstable")
        BUILD_ARGS+=("--tag" "localhost/m2os:${image}")
        ;;
    "cosmic"*)
        skopeo inspect docker://ghcr.io/ublue-os/bluefin:beta > /tmp/inspect.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=base-main")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect.json | grep -oP 'fc\K[0-9]+')")
        BUILD_ARGS+=("--tag" "localhost/m2os:${image}")
        ;;
    *)
        echo "No Image Yet..."
        exit 1
        ;;
    esac
    buildah build --format docker --label "org.opencontainers.image.description=m2os is my OCI image built from ublue projects. It mainly extends them for my uses." ${BUILD_ARGS[@]} .

# Remove Image
remove image="":
    #!/usr/bin/bash
    set -eou pipefail
    declare -A images={{ images }}
    image={{ image }}
    check_image="$image"
    if [[ "$check_image" =~ beta ]]; then
        check_image=${check_image:0:-5}
    fi
    check=${images[$check_image]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    podman rmi localhost/m2os:${image}

# Remove All Images
removeall:
    #!/usr/bin/bash
    set -euo pipefail
    declare -A images={{ images }}
    for image in ${!images[@]}
    do
        podman rmi localhost/m2os:"$image" || true
        podman rmi localhost/m2os:"$image"-beta || true
    done

# Cleanup
clean:
    find ${PWD}/m2os_* -maxdepth 0 -exec rm -rf {} \; || true
    rm -rf previous.manifest.json

# Rechunk Image
rechunk image="bluefin":
    #!/usr/bin/bash
    set -eou pipefail
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif podman image scp ${UID}@localhost::localhost/m2os:{{ image }} root@localhost::localhost/m2os:{{ image }}
    CREF=$(sudoif podman create localhost/m2os:{{ image }} bash)
    MOUNT=$(sudoif podman mount $CREF)
    OUT_NAME="m2os_{{ image }}"
    LABELS="
        org.opencontainers.image.title=m2os
        org.opencontainers.image.version=localbuild-$(date +%Y%m%d-%H:%M:%S)
        ostree.linux=$(skopeo inspect containers-storage:localhost/m2os:{{ image }} | jq -r '.Labels["ostree.linux"]')
        org.opencontainers.image.description=m2os is my OCI image built from ublue projects. It mainly extends them for my uses."
    sudoif podman run --rm \
        --security-opt label=disable \
        -v "$MOUNT":/var/tree \
        -e TREE=/var/tree \
        -u 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/1_prune.sh
    sudoif podman run --rm \
        --security-opt label=disable \
        -v "$MOUNT":/var/tree \
        -e TREE=/var/tree \
        -v "cache_ostree:/var/ostree" \
        -e REPO=/var/ostree/repo \
        -e RESET_TIMESTAMP=1 \
        -u 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/2_create.sh
    sudoif podman unmount "$CREF"
    sudoif podman rm "$CREF"
    sudoif podman run --rm \
        --pull=newer \
        --security-opt label=disable \
        -v "$PWD:/workspace" \
        -v "$PWD:/var/git" \
        -v cache_ostree:/var/ostree \
        -e REPO=/var/ostree/repo \
        -e PREV_REF=ghcr.io/m2giles/m2os:{{ image }} \
        -e LABELS="$LABELS" \
        -e OUT_NAME="$OUT_NAME" \
        -e VERSION_FN=/workspace/version.txt \
        -e OUT_REF="oci:$OUT_NAME" \
        -e GIT_DIR="/var/git" \
        -u 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/3_chunk.sh
    sudoif chown ${UID}:${GROUPS} -R "${PWD}"
    sudoif podman volume rm cache_ostree
    IMAGE=$(sudoif podman pull oci:${PWD}/m2os_{{ image }})
    sudoif podman tag ${IMAGE} localhost/m2os:{{ image }}
    sudoif podman image scp root@localhost::localhost/m2os:{{ image }} ${UID}@localhost::localhost/m2os:{{ image }}
    sudoif podman rmi localhost/m2os:{{ image }}
    sudoif chmod 0755 "${PWD}"/"{$OUT_NAME}"
    sudoif chmod 0755 "${PWD}"/"{$OUT_NAME}"/blobs
    sudoif chmod 0755 "${PWD}"/"{$OUT_NAME}"/blobs/sha256
    sudoif chown ${UID}:${GROUPS} -R "${PWD}"/"${OUT_NAME}"

# Build and Rechunk
build-rechunk image="bluefin": (build image) (rechunk image)

# Build ISO
iso image="bluefin" ghcr="":
    #!/usr/bin/bash
    set -eoux pipefail
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    mkdir -p m2os_build/{lorax_templates,flatpak-refs,output}
    echo 'append etc/anaconda/profile.d/fedora-kinoite.conf "\\n[User Interface]\\nhidden_spokes =\\n    PasswordSpoke"' \
         > m2os_build/lorax_templates/remove_root_password_prompt.tmpl

    if [[ {{ ghcr }} =~ true|yes|y|Yes|YES|Y|ghcr ]]; then
        IMAGE_FULL=ghcr.io/m2giles/m2os:{{ image }}
        IMAGE_REPO=ghcr.io/m2giles
        podman pull "${IMAGE_FULL}"
    else
        IMAGE_FULL=localhost/m2os:{{ image }}
        IMAGE_REPO=localhost
    fi
    # Load image into rootful podman
    sudoif podman image scp ${UID}@localhost::${IMAGE_FULL} root@localhost::${IMAGE_FULL}
    TEMP_FLATPAK_INSTALL_DIR="$(mktemp -d -p /tmp flatpak-XXXXX)"
    FLATPAK_REFS_DIR=m2os_build/flatpak-refs
    FLATPAK_REFS_DIR_ABS="$(realpath ${FLATPAK_REFS_DIR})"
    mkdir -p "${FLATPAK_REFS_DIR_ABS}"
    case {{ image }} in
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
    if [[ {{ image }} =~ cosmic ]]; then
    ADDITIONAL_FLATPAKS+=(app/org.gnome.World.PikaBackup/x86_64/stable)
    fi
    if [[ {{ image }} =~ aurora|bluefin|cosmic ]]; then
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
    if [[ {{ image }} =~ bazzite ]]; then
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
    podman run --rm --privileged \
    --entrypoint /bin/bash \
    -e FLATPAK_SYSTEM_DIR=/flatpak/flatpak \
    -e FLATPAK_TRIGGERS_DIR=/flatpak/triggers \
    -v ${FLATPAK_REFS_DIR_ABS}:/output \
    -v ${TEMP_FLATPAK_INSTALL_DIR}:/temp_flatpak_install_dir \
    ${IMAGE_FULL} /temp_flatpak_install_dir/install-flatpaks.sh
    # list Flatpaks
    cat ${FLATPAK_REFS_DIR}/flatpaks-with-deps
    # Build ISOs
    iso_build_args=()
    iso_build_args+=(--volume /run/podman/podman.sock:/var/run/docker.sock)
    iso_build_args+=(--volume ${PWD}:/github/workspace/)
    iso_build_args+=(ghcr.io/jasonn3/build-container-installer:latest)
    iso_build_args+=(ADDITIONAL_TEMPLATES=/github/workspace/m2os_build/lorax_templates/remove_root_password_prompt.tmpl)
    iso_build_args+=(ENROLLMENT_PASSWORD="universalblue")
    iso_build_args+=(FLATPAK_REMOTE_REFS_DIR="/github/workspace/${FLATPAK_REFS_DIR}")
    iso_build_args+=(IMAGE_NAME="${IMAGE_FULL}")
    iso_build_args+=(IMAGE_REPO="${IMAGE_REPO}")
    iso_build_args+=(VARIANT=Kinoite)
    iso_build_args+=(VERSION=$(skopeo inspect containers-storage:${IMAGE_FULL}| jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+'))
    iso_build_args+=(IMAGE_TAG={{ image }})
    iso_build_args+=(SECUREBOOT_KEY_URL="https://github.com/ublue-os/akmods/raw/main/certs/public_key.der")
    iso_build_args+=(ISO_NAME=/github/workspace/m2os_build/output/{{ image }}.iso)
    sudoif podman run --rm --privileged --pull=newer "${iso_build_args[@]}"
    sudoif chown ${UID}:${GROUPS} -R "${PWD}"
    sudoif podman rmi "${IMAGE_FULL}"
