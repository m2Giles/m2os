set unstable := true

mod? titanoboa

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
rechunker := "ghcr.io/ublue-os/legacy-rechunk:v1.0.0-x86_64@sha256:1ee0b4ad0eee9b300cca1afd8cf78b78ce77bcc0d5aa16b07a195c6c22f1c9b4"
[private]
qemu := "ghcr.io/qemus/qemu:7.29@sha256:a2a76a6b5d2304a132c7fda832670af972c1e1437d48b4bc3dea08d001b08eba"
[private]
cosign-installer := "ghcr.io/sigstore/cosign/cosign:v2.4.1"
[private]
syft-installer := "ghcr.io/anchore/syft:v1.39.0@sha256:6f13bb010923c33fb197047c8f88888e77071bd32596b3f605d62a133e493ce4"

# Base Containers

[private]
aurora := "ghcr.io/ublue-os/aurora:stable-daily@sha256:f486d59445459195ccf44d2ffe3b67596acfff2c8d1164cfd0bc1f06a3e6bb43"
[private]
aurora_nvidia := "ghcr.io/ublue-os/aurora-nvidia-open:stable-daily@sha256:4f4ed8d5abee9376a0e909d43394d986e0d66fca34eab5382663abb6737d4a5a"
[private]
bazzite := "ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable@sha256:6201854be2813bb3f2ddd32261e73a9a56816f3c87812567253764e8c4226751"
[private]
bazzite_deck := "ghcr.io/ublue-os/bazzite-deck-gnome:stable@sha256:e3d60f329b6f12709bf22278eae441ccc0bc8aa15557bbe86d6238cad7334e2e"
[private]
bluefin := "ghcr.io/ublue-os/bluefin:stable-daily@sha256:7d953597a6a62fd7a00f7eecabd5f2b5a2ae4d2f4d3eebd4fb6ee65f26787c06"
[private]
bluefin_nvidia := "ghcr.io/ublue-os/bluefin-nvidia-open:stable-daily@sha256:c4dae66e546221563ea7c353a4e391187e59b485f2114d3058ad7b5736e399c4"
[private]
ucore := "ghcr.io/ublue-os/ucore:stable-zfs@sha256:ec2bfae0a8aa84add04ee802a8b116995dc8ce609b193540655203e4abcf3937"
[private]
ucore_nvidia := "ghcr.io/ublue-os/ucore:stable-nvidia-zfs@sha256:ecda298f835a15eddd203a574428ab1358c3bf103532eb607f0f15c3006aa83b"
[private]
aurora_beta := "ghcr.io/ublue-os/aurora:latest@sha256:63b97dc1faf83becc5d4b95b9c23ff0630638a7d08b03255574dcfa4c7ac1373"
[private]
aurora_nvidia_beta := "ghcr.io/ublue-os/aurora-nvidia-open:latest@sha256:7f98f0d9025f5bb71de5b16ee4cdfd0e2fd91dcef480f65a4965e7f1bbe83c95"
[private]
bazzite_beta := "ghcr.io/ublue-os/bazzite-gnome-nvidia-open:testing@sha256:9fb283861d2e03d1db0bd3c951451b75e49ed152d195ab8f8656a4ca410376a0"
[private]
bazzite_deck_beta := "ghcr.io/ublue-os/bazzite-deck-gnome:testing@sha256:828753c60ebe60e25d49b270434cda19e4e355349c1edf8b3cbc53fcc902a71d"
[private]
bluefin_beta := "ghcr.io/ublue-os/bluefin:latest@sha256:b32dac85cdcc1fb9198bca9ec9d696da12df92de3b030ea4ff964fb00e6b56bf"
[private]
bluefin_nvidia_beta := "ghcr.io/ublue-os/bluefin-nvidia-open:latest@sha256:c2701afd99a1cb537a4f8e185fdce805dc9df6bed5e7b7fd54264f83757e21b7"
[private]
ucore_beta := "ghcr.io/ublue-os/ucore:testing-zfs@sha256:71f47c5cac34ae48714026ea1a8197730ce6bd172cf1d1c394cdb1e5626c96b2"
[private]
ucore_nvidia_beta := "ghcr.io/ublue-os/ucore:testing-nvidia-zfs@sha256:ded20788bbd11957552c950c53733fe15726c46e397306edad2533fea75dc149"

[private]
default:
    @{{ just }} --list

# Check Just Syntax
[group('Just')]
check:
    {{ just }} --unstable --fmt --check

# Fix Just Syntax
[group('Just')]
fix:
    {{ just }} --unstable --fmt

# Cleanup
[group('Utility')]
clean:
    find {{ repo_image_name }}_* -maxdepth 0 -exec rm -rf {} \; 2>/dev/null || true
    rm -f output*.env changelog*.md version.txt previous.manifest.json
    rm -f ./*.sbom.*

# Build
[group('Image')]
build image="bluefin": install-cosign (build-image image) (secureboot "localhost" / repo_image_name + ":" + image) (rechunk image) (load-image image)

# Build Image
[group('Image')]
build-image image="bluefin":
    #!/usr/bin/bash
    {{ ci_grouping }}
    {{ verify-container }}
    echo "################################################################################"
    echo "image  := {{ image }}"
    echo "PODMAN := {{ PODMAN }}"
    echo "CI     := {{ CI }}"
    echo "################################################################################"

    declare -A images={{ images }}
    check=${images[{{ image }}]-}
    if [[ -z "$check" ]]; then
        exit 1
    fi

    BUILD_ARGS=({{ if CI != '' { '--cpp-flag=-DGHCI' } else { '' } }})
    mkdir -p {{ BUILD_DIR }}
    BUILDTMP="$(mktemp -d -p {{ BUILD_DIR }})"
    trap 'rm -rf $BUILDTMP' EXIT SIGINT

    set -eoux pipefail

    case "{{ image }}" in
    "aurora"*|"bluefin"*) BUILD_ARGS+=("--cpp-flag=-DDESKTOP") ;;
    "bazzite"*) BUILD_ARGS+=("--cpp-flag=-DBAZZITE") ;;
    "cosmic"*)
        {{ if image =~ 'beta' { 'bluefin=${images[bluefin-beta]}' } else { 'bluefin="${images[bluefin]}"' } }}
        verify-container "${bluefin#*-os/}"
        fedora_version="$(skopeo inspect docker://"${bluefin/:*@/@}" | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')"
        check="$(yq -r ".images[] | select(.name == \"base-${fedora_version}\")" {{ image-file }} | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"
        BUILD_ARGS+=("--cpp-flag=-DCOSMIC")
        ;;
    "ucore"*) BUILD_ARGS+=("--cpp-flag=-DSERVER") ;;
    esac

    # Check Base Container
    verify-container "${check#*-os/}"

    # AKMODS
    {{ if image =~ 'beta' { 'akmods_version=testing' } else if image =~ 'aurora|bluefin|cosmic' { 'akmods_version=stable' } else { '' } }}

    # akmods
    {{ if image =~ 'aurora|bluefin|cosmic' { 'akmods="$(yq -r ".images[] | select(.name == \"akmods-${akmods_version}\")" ' + image-file + ' | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"' } else { '' } }}
    {{ if image =~ 'aurora|bluefin|cosmic' { 'verify-container "${akmods#*-os/}"; BUILD_ARGS+=("--cpp-flag=-DAKMODS=$akmods")' } else { '' } }}

    # zfs
    {{ if image =~ 'cosmic|(aurora.*|bluefin.*)-beta' { 'akmods_zfs="$(yq -r ".images[] | select(.name == \"akmods-zfs-${akmods_version}\")" ' + image-file + ' | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"' } else { '' } }}
    {{ if image =~ 'cosmic|(aurora.*|bluefin.*)-beta' { 'verify-container "${akmods_zfs#*-os/}"; BUILD_ARGS+=("--cpp-flag=-DZFS=$akmods_zfs")' } else { '' } }}

    # nvidia
    {{ if image =~ 'cosmic-nv.*|(aurora-nv.*|bluefin-nv.*)-beta' { 'akmods_nvidia="$(yq -r ".images[] | select(.name == \"akmods-nvidia-open-${akmods_version}\")" ' + image-file + ' | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"' } else { '' } }}
    {{ if image =~ 'cosmic-nv.*|(aurora-nv.*|bluefin-nv.*)-beta' { 'verify-container "${akmods_nvidia#*-os/}"; BUILD_ARGS+=("--cpp-flag=-DNVIDIA=$akmods_nvidia")' } else { '' } }}

    skopeo inspect docker://{{ if image =~ 'cosmic|(aurora.*|bluefin.*)-beta' { '${akmods/:*@/@}' } else { '${check/:*@/@}' } }} > "$BUILDTMP/inspect-{{ image }}.json"

    # Get The Version
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

    # Pull the images
    {{ PODMAN }} pull "$check"
    {{ if image =~ 'cosmic|aurora|bluefin' { PODMAN + ' pull "$akmods"' } else { '' } }}
    {{ if image =~ 'cosmic|(aurora.*|bluefin.*)-beta' { PODMAN + ' pull "$akmods_zfs"' } else { '' } }}
    {{ if image =~ 'cosmic-nv.*|(aurora-nv.*|bluefin-nv.*)-beta' { PODMAN + ' pull "$akmods_nvidia"' } else { '' } }}

    # Labels
    BUILD_ARGS+=(
        "--label" "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses."
        "--label" "org.opencontainers.image.source=https://github.com/{{ repo_name }}/{{ repo_image_name }}"
        "--label" "org.opencontainers.image.title={{ repo_image_name }}"
        "--label" "org.opencontainers.image.version=$VERSION"
        "--label" "ostree.kernel_flavor={{ if image =~ 'bazzite' { 'bazzite' } else if image =~ 'beta' { 'coreos-testing' } else { 'coreos-stable' } }}"
        "--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < "$BUILDTMP"/inspect-{{ image }}.json)"
    )

    #Build Args
    BUILD_ARGS+=(
        "--build-arg" "IMAGE={{ image }}"
        "--build-arg" "BASE_IMAGE=${check%%:*}"
        "--build-arg" "TAG_VERSION=${check#*:}"
        "--build-arg" "VERSION=$VERSION"
    )

    {{ PODMAN }} build "${BUILD_ARGS[@]}" --security-opt label=disable --file Containerfile.in --tag localhost/{{ repo_image_name + ':' + image }} {{ justfile_dir() }}

    {{ if CI != '' { PODMAN + ' rmi -f "${check%@*}"' } else { '' } }}

# Rechunk Image
[group('Image')]
rechunk image="bluefin":
    #!/usr/bin/bash
    {{ PODMAN }} image exists localhost/{{ repo_image_name + ":" + image }} || { exit 1 ; }

    if [[ "${UID}" -gt "0" && "{{ PODMAN }}" =~ podman$ ]]; then
       # Use Podman Unshare, and then exit
       {{ PODMAN }} unshare -- {{ just }} rechunk {{ image }}
       # Exit with previous exit code
       exit "$?"
    fi

    {{ ci_grouping }}
    echo "################################################################################"
    echo "image  := {{ image }}"
    echo "PODMAN := {{ PODMAN }}"
    echo "CI     := {{ CI }}"
    echo "################################################################################"
    set -eoux pipefail

    CREF=$({{ PODMAN }} create localhost/{{ repo_image_name }}:{{ image }} bash)
    OUT_NAME="{{ repo_image_name }}_{{ image }}.tar"
    VERSION="$({{ PODMAN }} inspect "$CREF" | jq -r '.[].Config.Labels["org.opencontainers.image.version"]')"
    LABELS="
    org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses.
    org.opencontainers.image.revision=$(git rev-parse HEAD)
    org.opencontainers.image.source=https://github.com/{{ repo_name }}/{{ repo_image_name }}
    org.opencontainers.image.title={{ repo_image_name }}:{{ image }}
    ostree.kernel_flavor={{ if image =~ 'bazzite' { 'bazzite' } else if image =~ 'beta' { 'coreos-testing' } else { 'coreos-stable' } }}
    ostree.linux=$({{ PODMAN }} inspect "$CREF" | jq -r '.[].Config.Labels["ostree.linux"]')
    "
    if [[ ! "{{ PODMAN }}" =~ remote ]]; then
        MOUNT=$({{ PODMAN }} mount "$CREF")
    else
        MOUNTFS="{{ BUILD_DIR }}/{{ image }}_rootfs"
        {{ SUDOIF }} rm -rf "$MOUNTFS"
        mkdir -p "$MOUNTFS"
        {{ PODMAN }} export "$CREF" | tar --xattrs-include='*' -p -xf - -C "$MOUNTFS"
        MOUNT="{{ GIT_ROOT }}/$MOUNTFS"
        {{ PODMAN }} rm "$CREF"
        {{ PODMAN }} rmi -f localhost/{{ repo_image_name }}:{{ image }}
    fi
    # Workaround ublue-os/legacy-rechunk not being signed at this time
    echo '{"default": [{"type": "insecureAcceptAnything"}]}' > /tmp/policy.json
    {{ PODMAN }} pull --signature-policy=/tmp/policy.json {{ rechunker }}
    {{ PODMAN }} run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        {{ rechunker }} \
        /sources/rechunk/1_prune.sh
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
    {{ PODMAN }} run --rm \
        --security-opt label=disable \
        --volume "{{ GIT_ROOT }}:/workspace" \
        --volume "{{ GIT_ROOT }}:/var/git" \
        --volume cache_ostree:/var/ostree \
        --env REPO=/var/ostree/repo \
        --env PREV_REF={{ FQ_IMAGE_NAME + ":" + image }} \
        --env LABELS="$LABELS" \
        --env OUT_NAME="$OUT_NAME" \
        --env VERSION="$VERSION" \
        --env VERSION_FN=/workspace/version.txt \
        --env OUT_REF="oci-archive:$OUT_NAME" \
        --env GIT_DIR="/var/git" \
        --user 0:0 \
        {{ rechunker }} \
        /sources/rechunk/3_chunk.sh
    {{ PODMAN }} volume rm cache_ostree

# Load Image into Podman and Tag
[group('Image')]
load-image image="bluefin":
    #!/usr/bin/bash
    {{ if CI == '' { '' } else { 'exit 0' } }}
    {{ PODMAN }} tag "$({{ PODMAN + " pull oci-archive:" + repo_image_name + "_" + image + ".tar" }})" localhost/{{ repo_image_name + ":" + image }}
    {{ PODMAN }} tag localhost/{{ repo_image_name + ":" + image }} localhost/{{ repo_image_name }}:"$(skopeo inspect oci-archive:{{ repo_image_name + '_' + image + '.tar' }} | jq -r '.Labels["org.opencontainers.image.version"]')"
    {{ PODMAN }} images

# Build ISO
[group('ISO')]
build-iso image="bluefin":
    {{ shell("mkdir -p $1/output", BUILD_DIR) }}
    {{ SUDOIF }} \
        HOOK_post_rootfs={{ GIT_ROOT / "iso_files/configure_iso.sh" }} \
        CI="{{ CI }}" \
        {{ just }} titanoboa::build \
        {{ FQ_IMAGE_NAME + ":" + image }} \
        "1" \
        {{ if image =~ "aurora" { GIT_ROOT / "iso_files/kde-flatpaks.txt" } else { GIT_ROOT / "iso_files/gnome-flatpaks.txt" } }} \
        "squashfs" \
        "NONE" \
        {{ FQ_IMAGE_NAME + ":" + image }} \
        "1"
    {{ SUDOIF }} chown "$(id -u):$(id -g)" output.iso
    sha256sum output.iso | tee {{ BUILD_DIR / "output" / repo_image_name + "-" + image + ".iso-CHECKSUM" }}
    mv output.iso {{ BUILD_DIR / "output" / repo_image_name + "-" + image + ".iso" }}
    {{ SUDOIF }} {{ just }} titanoboa::clean

# Run ISO
[group('ISO')]
run-iso image="bluefin":
    {{ if path_exists(GIT_ROOT / BUILD_DIR / "output" / repo_image_name + "-" + image + ".iso") == "true" { '' } else { just + " build-iso " + image } }}
    {{ just }} titanoboa::container-run-vm {{ GIT_ROOT / BUILD_DIR / "output" / repo_image_name + "-" + image + ".iso" }}

# Test Changelogs
[group('Changelogs')]
changelogs target="Desktop" urlmd="" handwritten="":
    python3 changelogs.py {{ target }} ./output-{{ target }}.env ./changelog-{{ target }}.md --workdir . --handwritten "{{ handwritten }}" --urlmd "{{ urlmd }}"

# Verify Container with Cosign
[group('Utility')]
verify-container container registry="ghcr.io/ublue-os" key="": install-cosign
    if ! cosign verify --key "{{ if key == '' { 'https://raw.githubusercontent.com/ublue-os/main/main/cosign.pub' } else { key } }}" "{{ if registry != '' { registry / container } else { container } }}" >/dev/null; then \
        echo "NOTICE: Verification failed. Please ensure your public key is correct." && exit 1 \
    ; fi

# Secureboot Check
[group('Image')]
secureboot image="bluefin":
    #!/usr/bin/bash
    {{ ci_grouping }}
    set -eoux pipefail
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
merge-changelog type="stable":
    #!/usr/bin/bash
    set -eoux pipefail
    rm -f changelog.md
    cat {{ if type =~ 'beta' { 'changelog-Beta-Desktop.md changelog-Beta-Bazzite.md' } else { 'changelog-Desktop.md changelog-Bazzite.md' } }} > changelog.md
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
        "title": "$tag{{ if type =~ 'beta' { '-beta' } else { '' } }} (#$(git rev-parse --short HEAD))",
        "tag": "$tag{{ if type =~ 'beta' { '-beta' } else { '' } }}"
    }
    EOF

# Lint Files
[group('Utility')]
lint:
    # shell
    /usr/bin/find . -iname "*.sh" -type f -not -path "./titanoboa/*" -exec shellcheck "{}" ';'
    # yaml
    yamllint -s {{ justfile_dir() }}
    # just
    {{ just }} check
    # just recipes
    {{ just }} lint-recipes

# Format Files
[group('Utility')]
format:
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
        build-image
        build-iso
        changelogs
        cosign-sign
        gen-sbom
        rechunk
        run-iso
        sbom-sign
        secureboot
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
    {{ ci_grouping }}
    set -euox pipefail

    # Get Cosign from Chainguard
    if ! command -v cosign >/dev/null; then
        # TMPDIR
        TMPDIR="$(mktemp -d)"
        trap 'rm -rf $TMPDIR' EXIT SIGINT

        # Get Binary
        COSIGN_CONTAINER_ID="$({{ PODMAN }} create {{ cosign-installer }} bash)"
        {{ PODMAN }} cp "${COSIGN_CONTAINER_ID}":/ko-app/cosign "$TMPDIR"/cosign
        {{ PODMAN }} rm -f "${COSIGN_CONTAINER_ID}"
        {{ PODMAN }} rmi -f {{ cosign-installer }}

        # Install
        {{ SUDOIF }} install -c -m 0755 "$TMPDIR"/cosign /usr/local/bin/cosign

        # Verify Cosign Image Signatures if needed
        # if ! cosign verify --certificate-oidc-issuer=https://token.actions.githubusercontent.com --certificate-identity=https://github.com/chainguard-images/images/.github/workflows/release.yaml@refs/heads/main cgr.dev/chainguard/cosign >/dev/null; then
        #     echo "NOTICE: Failed to verify cosign image signatures."
        #     exit 1
        # fi
    fi

# Login to GHCR
[group('CI')]
login-to-ghcr $user $token:
    echo "$token" | podman login ghcr.io -u "$user" --password-stdin
    {{ if `command -v docker || true` != '' { 'echo "$token" | docker login ghcr.io -u "$user" --password-stdin' } else { 'cat "${XDG_RUNTIME_DIR}/containers/auth.json" > ~/.docker/config.json' } }}

# Push Images to Registry
[group('CI')]
push-to-registry image dryrun="true" $destination="":
    for tag in {{ image }} {{ shell("skopeo inspect oci-archive:$1_$2.tar | jq -r '.Labels[\"org.opencontainers.image.version\"]'", repo_image_name, image) }}; do \
        {{ if dryrun == "false" { 'skopeo copy oci-archive:' + repo_image_name + "_" + image + ".tar ${destination:-docker://" + IMAGE_REGISTRY + "}/" + repo_image_name + ":$tag >&2" } else { 'echo "$tag" >&2' } }} \
    ; done

# Sign Images with Cosign
[group('CI')]
cosign-sign digest $destination="": install-cosign
    cosign sign -y --key env://COSIGN_PRIVATE_KEY "${destination:-{{ IMAGE_REGISTRY }}}/{{ repo_image_name + "@" + digest }}"

# Push and Sign
[group('CI')]
push-and-sign image: (login-to-ghcr env('ACTOR') env('TOKEN')) (push-to-registry image 'false' '') (cosign-sign shell('skopeo inspect oci-archive:$1_$2.tar --format "{{ .Digest }}"', repo_image_name, image))

# Generate SBOM
[group('CI')]
gen-sbom $input $output="": install-syft
    #!/usr/bin/bash
    set -eoux pipefail

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
    {{ ci_grouping }}
    set -eoux pipefail

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
    set -eoux pipefail

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
    set -eoux pipefail

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
just := just_executable() + " -f " + justfile()
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

# Podman By Default

[private]
export PODMAN := env("PODMAN", "") || which("podman") || require("podman-remote")

# Utilities

verify-container := '''
function verify-container() {
    local container="$1"
    local registry="${2:-ghcr.io/ublue-os}"
    local key="${3:-https://raw.githubusercontent.com/ublue-os/main/main/cosign.pub}"
    local target="$registry/$container"
    if ! cosign verify --key "$key" "$target" &>/dev/null; then
        echo "NOTICE: Verification failed. Please ensure your public key is correct." && exit 1
    fi
}
'''
ci_grouping := '
if [[ -n "${CI:-}" ]]; then
    echo "::group::' + style('warning') + '${BASH_SOURCE[0]##*/} step' + NORMAL + '"
    trap "echo ::endgroup::" EXIT
fi'
[private]
CI := env('CI', '')
