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

# List Images
images:
    #!/usr/bin/bash
    declare -A images={{ images }}
    echo "${!images[@]}"


# Build m2os
build image="bluefin":
    #!/usr/bin/bash
    set -eoux pipefail
    declare -A images={{ images }}
    image={{image}}
    check=${images[$image]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    case "${image}" in
    "aurora"*|"bluefin"*)
        buildah build --build-arg BASE_IMAGE=${image} --build-arg IMAGE=${image} --build-arg TAG_VERSION=stable-daily --tag localhost/m2os:${image}
        ;;
    "bazzite"*)
        buildah build --build-arg BASE_IMAGE=${check} --build-arg IMAGE=${image} --build-arg TAG_VERSION=stable --tag localhost/m2os:${image}
        ;;
    "cosmic"*)
        STABLE=$(skopeo inspect docker://ghcr.io/ublue-os/bluefin:stable-daily | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')
        buildah build --build-arg BASE_IMAGE=base-main --build-arg IMAGE=${image} --build-arg TAG_VERSION=${STABLE} --tag localhost/m2os:${image}
        ;;
    "ucore"*)
        buildah build --build-arg BASE_IMAGE=ucore-hci --build-arg IMAGE=${image} --build-arg TAG_VERSION=${check} --tag localhost/m2os:${image}
        ;;
    esac

# Build Beta Image
build-beta image="bluefin":
    #!/usr/bin/bash
    set -eoux pipefail
    declare -A images={{ images }}
    image={{image}}
    check=${images[$image]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    case "${image}" in
    "aurora"*|"bluefin"*)
        buildah build --build-arg BASE_IMAGE=${image} --build-arg IMAGE=${image}-beta --build-arg TAG_VERSION=beta --tag localhost/m2os:${image}-beta
        ;;
    "bazzite"*)
        buildah build --build-arg BASE_IMAGE=${check} --build-arg IMAGE=${image}-beta --build-arg TAG_VERSION=unstable --tag localhost/m2os:${image}-beta
        ;;
    "cosmic"*)
        BETA=$(skopeo inspect docker://ghcr.io/ublue-os/bluefin:beta | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')
        buildah build --build-arg BASE_IMAGE=base-main --build-arg IMAGE=${image}-beta --build-arg TAG_VERSION=${BETA} --tag localhost/m2os:${image}-beta
        ;;
    *)
        echo "no image yet..."
        ;;
    esac

# Clean Image
clean image="":
    #!/usr/bin/bash
    set -eoux pipefail
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

# Clean All Images
cleanall:
    #!/usr/bin/bash
    declare -A images={{ images }}
    for image in ${!images[@]}
    do
        podman rmi localhost/"$image"
        podman rmi localhost/"$image"-beta
    done
