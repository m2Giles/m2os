images := '(
    [aurora]="aurora"
    [aurora-nvidia]="aurora-nvidia"
    [bazzite-deck-gnome]="bazzite-deck-gnome"
    [bazzite-gnome-nvidia]="bazzite-gnome-nvidia"
    [bluefin]="bluefin"
    [bluefin-nvidia]="bluefin-nvidia"
    [cosmic]="cosmic"
    [cosmic-nvidia]="cosmic-nvidia"
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
    if [[ ! "{{ image }}" =~ cosmic ]]; then
        buildah build --build-arg IMAGE={{ image }} --target stage1 --tag localhost/m2os:{{ image }}
    else
        buildah build --build-arg IMAGE={{ image }} --target cosmic --tag localhost/m2os:{{ image }}
    fi

# Clean Image
clean image="":
    podman rmi localhost/m2os:{{ image }}

# Clean All Images
cleanall:
    #!/usr/bin/bash
    declare -A images={{ images }}; for image in ${!images[@]}; do just clean $image; done
