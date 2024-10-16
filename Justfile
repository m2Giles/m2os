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
    if [[ "${image}" =~ ucore ]]; then
        buildah build --build-arg IMAGE=ucore-hci --build-arg TAG_VERSION=${check} --target stage1 --tag localhost/m2os:${image}
    elif [[ "${image}" =~ bazzite ]]; then
        buildah build --build-arg IMAGE=${check} --build-arg TAG_VERSION=stable --target stage1 --tag localhost/m2os:${image}
    elif [[ ! "${image}" =~ cosmic ]]; then
        buildah build --build-arg IMAGE=${check} --target stage1 --tag localhost/m2os:${image}
    else
        buildah build --build-arg IMAGE=${check} --target cosmic --tag localhost/m2os:${image}
    fi

# Clean Image
clean image="":
    #!/usr/bin/bash
    set -eoux pipefail
    declare -A images={{ images }}
    image={{image}}
    check=${images[$image]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi
    podman rmi localhost/m2os:${image}

# Clean All Images
cleanall:
    #!/usr/bin/bash
    declare -A images={{ images }}; for image in ${!images[@]}; do just clean $image; done
