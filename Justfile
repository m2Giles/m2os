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

[private]
default:
    @just --list

# Check Just Syntax
check:
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
fix:
    just --unstable --fmt -f Justfile || { exit 1; }

# Remove Image
remove image="":
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
    podman rmi localhost/{{ repo_image_name }}:${image}
    sudoif podman rmi localhost/{{ repo_image_name }}:${image}

# Remove All Images
removeall:
    #!/usr/bin/bash
    set -euo pipefail
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
    declare -A images={{ images }}
    for image in ${!images[@]}
    do
        podman rmi localhost/{{ repo_image_name }}:"$image" || true
        podman rmi localhost/{{ repo_image_name }}:"$image"-beta || true
        sudoif podman rmi localhost/{{ repo_image_name }}:"$image" || true
        sudoif podman rmi localhost/{{ repo_image_name }}:"$image"-beta || true
    done

# Cleanup
clean:
    find ${PWD}/{{ repo_image_name }}_* -maxdepth 0 -exec rm -rf {} \; || true
    rm -rf previous.manifest.json

# Build Image
build image="bluefin" target="":
    #!/usr/bin/bash
    set -eou pipefail
    declare -A images={{ images }}
    image={{ image }}
    if [[ "${image}" =~ -beta$ ]]; then
        target="beta"
        image=${image:0:-5}
    fi
    if [[ "${target:-}" != "beta" ]] && [[ -n "{{ target }}" ]]; then
        echo "Invalid Option..."
        exit 1
    fi
    check=${images[$image]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    if [[ "${target:-}" == "beta" ]]; then
        just build-beta "${image}" 
        exit 0
    fi
    BUILD_ARGS=()
    BUILD_ARGS+=("--label" "org.opencontainers.image.title={{ repo_image_name }}")
    BUILD_ARGS+=("--label" "org.opencontainers.image.version=localbuild")
    BUILD_ARGS+=("--build-arg" "IMAGE=${image}")
    BUILD_ARGS+=("--tag" "localhost/{{ repo_image_name }}:${image}")
    case "${image}" in
    "aurora"*|"bluefin"*)
        podman pull ghcr.io/ublue-os/${image}:stable-daily
        skopeo inspect containers-storage:ghcr.io/ublue-os/${image}:stable-daily > /tmp/inspect-{{ image }}.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${image}")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=stable-daily")
        ;;
    "bazzite"*)
        podman pull ghcr.io/ublue-os/${check}:stable
        skopeo inspect containers-storage:ghcr.io/ublue-os/${check}:stable > /tmp/inspect-{{ image }}.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${check}")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=stable")
        ;;
    "cosmic"*)
        fedora_version="$(skopeo inspect docker://ghcr.io/ublue-os/bluefin:stable-daily | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
        podman pull ghcr.io/ublue-os/base-main:"${fedora_version}"
        BUILD_ARGS+=("--label" "ostree.linux=$(skopeo inspect docker://ghcr.io/ublue-os/coreos-stable-kernel:${fedora_version} | jq -r '.Labels["ostree.linux"]')")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=base-main")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=${fedora_version}")
        ;;
    "ucore"*)
        podman pull ghcr.io/ublue-os/ucore-hcr:"${check}"
        skopeo inspect containers-storage:ghcr.io/ublue-os/ucore-hci:${check} > /tmp/inspect-{{ image }}.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=ucore-hci")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=${check}")
        ;;
    esac
    buildah build --format docker --label "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses." ${BUILD_ARGS[@]} .
    just rechunk {{ image }}

# Build Beta Image
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
    BUILD_ARGS+=("--label" "org.opencontainers.image.title={{ repo_image_name }}")
    BUILD_ARGS+=("--label" "org.opencontainers.image.version=localbuild-$(date +%Y%m%d-%H:%M:%S)")
    BUILD_ARGS+=("--build-arg" "IMAGE=${image}")
    BUILD_ARGS+=("--tag" "localhost/{{ repo_image_name }}:${image}-beta")
    case "${image}" in
    "aurora"*|"bluefin"*)
        podman pull ghcr.io/ublue-os/"${image}":beta
        skopeo inspect containers-storage:ghcr.io/ublue-os/"${image}":beta > /tmp/inspect-{{ image }}.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${image}")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=beta")
        ;;
    "bazzite"*)
        podman pull ghcr.io/ublue-os/"${check}":unstable
        skopeo inspect containers-storage:ghcr.io/ublue-os/"${check}":unstable > /tmp/inspect-{{ image }}.json
        BUILD_ARGS+=("--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < /tmp/inspect-{{ image }}.json)")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${check}")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=unstable")
        ;;
    "cosmic"*)
        fedora_version="$(skopeo inspect docker://ghcr.io/ublue-os/bluefin:beta | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
        podman pull ghcr.io/ublue-os/base-main:"${fedora_version}"
        BUILD_ARGS+=("--label" "ostree.linux=$(skopeo inspect docker://ghcr.io/ublue-os/main-kernel:${fedora_version} | jq -r '.Labels["ostree.linux"]')")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=base-main")
        BUILD_ARGS+=("--build-arg" "TAG_VERSION=${fedora_version}")
        ;;
    *)
        echo "No Image Yet..."
        exit 1
        ;;
    esac
    buildah build --format docker --label "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses." ${BUILD_ARGS[@]} .
    just rechunk {{ image }}-beta

# Rechunk Image
[private]
rechunk image="bluefin":
    #!/usr/bin/bash
    set -eou pipefail
    if [[ -n "${SUDO_COMMAND:-}" ]]; then
        echo "Do not run this script with sudo..."
        exit 1
    fi
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
    ID=$(podman images --filter reference=localhost/{{ repo_image_name }}:{{ image }} --format "'{{ '{{.ID}}' }}'")
    if [[ -z "$ID" ]]; then
        just build {{ image }}
    fi
    sudoif podman image scp ${UID}@localhost::localhost/{{ repo_image_name }}:{{ image }} root@localhost::localhost/{{ repo_image_name }}:{{ image }}
    CREF=$(sudoif podman create localhost/{{ repo_image_name }}:{{ image }} bash)
    MOUNT=$(sudoif podman mount $CREF)
    OUT_NAME="{{ repo_image_name }}_{{ image }}"
    LABELS="
        org.opencontainers.image.title={{ repo_image_name }}
        org.opencontainers.image.version=localbuild-$(date +%Y%m%d-%H:%M:%S)
        ostree.linux=$(skopeo inspect containers-storage:localhost/{{ repo_image_name }}:{{ image }} | jq -r '.Labels["ostree.linux"]')
        org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses."
    sudoif podman run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/1_prune.sh
    sudoif podman run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --volume "cache_ostree:/var/ostree" \
        --env TREE=/var/tree \
        --env REPO=/var/ostree/repo \
        --env RESET_TIMESTAMP=1 \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/2_create.sh
    sudoif podman unmount "$CREF"
    sudoif podman rm "$CREF"
    sudoif podman run --rm \
        --pull=newer \
        --security-opt label=disable \
        --volume "$PWD:/workspace" \
        --volume "$PWD:/var/git" \
        --volume cache_ostree:/var/ostree \
        --env REPO=/var/ostree/repo \
        --env PREV_REF=ghcr.io/{{ repo_name }}/{{ repo_image_name }}:{{ image }} \
        --env LABELS="$LABELS" \
        --env OUT_NAME="$OUT_NAME" \
        --env VERSION_FN=/workspace/version.txt \
        --env OUT_REF="oci:$OUT_NAME" \
        --env GIT_DIR="/var/git" \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/3_chunk.sh
    sudoif find {{ repo_image_name }}_{{ image }} -type d -exec chmod 0755 {} \; || true
    sudoif find {{ repo_image_name }}_{{ image }}* -type f -exec chmod 0644 {} \; || true
    sudoif chown ${UID}:${GROUPS} -R "${PWD}"
    sudoif podman volume rm cache_ostree
    IMAGE=$(sudoif podman pull oci:${PWD}/{{ repo_image_name }}_{{ image }})
    sudoif podman tag ${IMAGE} localhost/{{ repo_image_name }}:{{ image }}
    sudoif podman image scp root@localhost::localhost/{{ repo_image_name }}:{{ image }} "${UID}"@localhost::localhost/{{ repo_image_name }}:{{ image }}
    sudoif podman rmi localhost/{{ repo_image_name }}:{{ image }}

# Build ISO
build-iso image="bluefin" ghcr="":
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
    if [[ -n "${SUDO_COMMAND:-}" ]]; then
        echo "Do not run this script with sudo..."
        exit 1
    fi
    mkdir -p {{ repo_image_name }}_build/{lorax_templates,flatpak-refs-{{ image }},output}
    echo 'append etc/anaconda/profile.d/fedora-kinoite.conf "\\n[User Interface]\\nhidden_spokes =\\n    PasswordSpoke"' \
         > {{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl
    echo 'append usr/share/anaconda/interactive-defaults.ks "\\nuser --name={{ username }} --password=password --plaintext --groups=wheel"' \
        > {{ repo_image_name }}_build/lorax_templates/set_default_user.tmpl

    # Build from GHCR or localhost
    if [[ "{{ ghcr }}" =~ true|yes|y|Yes|YES|Y|ghcr ]]; then
        IMAGE_FULL=ghcr.io/{{ repo_name }}/{{ repo_image_name }}:{{ image }}
        IMAGE_REPO=ghcr.io/{{ repo_name }}
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
            /github/workspace/{{ repo_image_name }}_build/lorax_templates/set_default_user.tmpl
        )
    fi
    # Check if ISO already exists. Remove it.
    if [[ -f "{{ repo_image_name }}_build/output/{{ image }}.iso" || -f "{{ repo_image_name }}_build/output/{{ image }}.iso-CHECKSUM" ]]; then
        rm -f {{ repo_image_name }}_build/output/{{ image }}.iso*
    fi
    # Load image into rootful podman
    sudoif podman image scp "${UID}"@localhost::"${IMAGE_FULL}" root@localhost::"${IMAGE_FULL}"
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
    podman run --rm --privileged \
    --entrypoint /bin/bash \
    -e FLATPAK_SYSTEM_DIR=/flatpak/flatpak \
    -e FLATPAK_TRIGGERS_DIR=/flatpak/triggers \
    -v ${FLATPAK_REFS_DIR_ABS}:/output \
    -v ${TEMP_FLATPAK_INSTALL_DIR}:/temp_flatpak_install_dir \
    ${IMAGE_FULL} /temp_flatpak_install_dir/install-flatpaks.sh
    # list Flatpaks
    cat ${FLATPAK_REFS_DIR}/flatpaks-with-deps
    #ISO Container Args
    iso_build_args=()
    iso_build_args+=(--volume "/run/podman/podman.sock:/var/run/docker.sock")
    iso_build_args+=(--volume "${PWD}:/github/workspace/")
    iso_build_args+=(ghcr.io/jasonn3/build-container-installer:latest)
    iso_build_args+=(ADDITIONAL_TEMPLATES="${TEMPLATES[*]}")
    iso_build_args+=(ARCH="x86_64")
    iso_build_args+=(ENROLLMENT_PASSWORD="universalblue")
    iso_build_args+=(FLATPAK_REMOTE_REFS_DIR="/github/workspace/${FLATPAK_REFS_DIR}")
    iso_build_args+=(IMAGE_NAME="{{ repo_image_name }}")
    iso_build_args+=(IMAGE_REPO="${IMAGE_REPO}")
    iso_build_args+=(IMAGE_SIGNED="true")
    iso_build_args+=(IMAGE_SRC="docker-daemon:${IMAGE_FULL}")
    iso_build_args+=(IMAGE_TAG="{{ image }}")
    iso_build_args+=(ISO_NAME="/github/workspace/{{ repo_image_name }}_build/output/{{ image }}.iso")
    iso_build_args+=(SECURE_BOOT_KEY_URL="https://github.com/ublue-os/akmods/raw/main/certs/public_key.der")
    iso_build_args+=(VARIANT="Kinoite")
    iso_build_args+=(VERSION="$(skopeo inspect containers-storage:${IMAGE_FULL} | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')")
    iso_build_args+=(WEBUI="false")
    # Build ISO
    sudoif podman run --rm --privileged --pull=newer "${iso_build_args[@]}"
    sudoif chown ${UID}:${GROUPS} -R "${PWD}"
    sudoif podman rmi "${IMAGE_FULL}"

# Run ISO
run-iso image="bluefin":
    #!/usr/bin/bash
    set -eou pipefail
    if [[ ! -f "{{ repo_image_name }}_build/output/{{ image }}.iso" ]]; then
        just build-iso {{ image }}
    fi
    port=8006;
    while grep -q ${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"
    echo "If Localhost Build Default User: {{ username }}, Password: password"
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
