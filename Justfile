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


_default:
    @just --list


# Build m2os Image
build image="bluefin":
    #!/usr/bin/bash
    set -eou pipefail
    declare -A images={{ images }}
    image={{image}}
    check=${images[$image]-}
    if [[ -z "$check" ]]; then
        exit 1
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
build-beta image="bluefin":
    #!/usr/bin/bash
    set -eou pipefail
    declare -A images={{ images }}
    image={{image}}
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
    declare -A images={{images}}
    image={{image}}
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
    sudoif podman image scp ${UID}@localhost::localhost/m2os:{{image}} root@localhost::localhost/m2os:{{image}}
    CREF=$(sudoif podman create localhost/m2os:{{image}} bash)
    MOUNT=$(sudoif podman mount $CREF)
    OUT_NAME="m2os_{{image}}"
    LABELS="
        org.opencontainers.image.title=m2os
        org.opencontainers.image.version=localbuild-$(date +%Y%m%d-%H:%M:%S)
        ostree.linux=$(skopeo inspect containers-storage:localhost/m2os:{{image}} | jq -r '.Labels["ostree.linux"]')
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
        --security-opt label=disable \
        -v "$PWD:/workspace" \
        -v "$PWD:/var/git" \
        -v cache_ostree:/var/ostree \
        -e REPO=/var/ostree/repo \
        -e PREV_REF=ghcr.io/m2giles/m2os:{{image}} \
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
    IMAGE=$(sudoif podman pull oci:${PWD}/m2os_{{image}})
    sudoif podman tag ${IMAGE} localhost/m2os:{{image}}
    sudoif podman image scp root@localhost::localhost/m2os:{{image}} ${UID}@localhost::localhost/m2os:{{image}}
    sudoif podman rmi localhost/m2os:{{image}}
    sudoif podman rmi ghcr.io/hhd-dev/rechunk:latest
    sudoif chown ${UID}:${GROUPS} -R "${PWD}"/"${OUT_NAME}"

# Build and Rechunk
build-rechunk image="bluefin": (build image) (rechunk image)

# Cleanup
clean:
    find ${PWD}/m2os_* -maxdepth 0 -exec rm -rf {} \; || true
    rm -rf previous.manifest.json 