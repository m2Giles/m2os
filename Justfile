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
chunkah := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "chunkah")
[private]
qemu := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "qemu")

# Base Containers

[private]
brew := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "brew")
[private]
common := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "common")
[private]
aurora := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "aurora")
[private]
aurora_nvidia := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "aurora-nvidia")
[private]
bazzite := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "bazzite")
[private]
bazzite_deck := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "bazzite-deck")
[private]
bluefin := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "bluefin")
[private]
bluefin_nvidia := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "bluefin-nvidia")
[private]
ucore := "ghcr.io/ublue-os/ucore:stable-zfs@sha256:ec2bfae0a8aa84add04ee802a8b116995dc8ce609b193540655203e4abcf3937"
[private]
ucore_nvidia := "ghcr.io/ublue-os/ucore:stable-nvidia-zfs@sha256:ecda298f835a15eddd203a574428ab1358c3bf103532eb607f0f15c3006aa83b"
[private]
aurora_beta := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "aurora-beta")
[private]
aurora_nvidia_beta := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "aurora-nvidia-beta")
[private]
bazzite_beta := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "bazzite-beta")
[private]
bazzite_deck_beta := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "bazzite-deck-beta")
[private]
bluefin_beta := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "bluefin-beta")
[private]
bluefin_nvidia_beta := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "bluefin-nvidia-beta")
[private]
ucore_beta := "ghcr.io/ublue-os/ucore:testing-zfs@sha256:71f47c5cac34ae48714026ea1a8197730ce6bd172cf1d1c394cdb1e5626c96b2"
[private]
ucore_nvidia_beta := "ghcr.io/ublue-os/ucore:testing-nvidia-zfs@sha256:ded20788bbd11957552c950c53733fe15726c46e397306edad2533fea75dc149"
[private]
akmods_stable := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "akmods-stable")
[private]
akmods_testing := shell('yq -r ".images[] | select(.name == \"$2\") | \"\\(.image):\\(.tag)@\\(.digest)\"" $1', image-file, "akmods-testing")

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
build image="bluefin": (build-image image) (secureboot "localhost" / repo_image_name + ":" + image) (rechunk image)

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
    mkdir -p {{ GIT_ROOT / BUILD_DIR }}
    BUILDTMP="$(mktemp -d -p {{ GIT_ROOT / BUILD_DIR }})"
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
        verify-container "{{ replace_regex(brew, "^.+/", "") }}"
        verify-container "{{ replace_regex(common, "^.+/", "") }}" "ghcr.io/projectbluefin" "https://raw.githubusercontent.com/projectbluefin/common/refs/heads/main/cosign.pub"
        BUILD_ARGS+=("--cpp-flag=-DBREW={{ brew }}" "--cpp-flag=-DCOMMON={{ common }}")
        ;;
    "ucore"*) BUILD_ARGS+=("--cpp-flag=-DSERVER") ;;
    esac

    # Check Base Container
    verify-container "${check#*-os/}"

    # AKMODS
    {{ if image =~ 'beta' { 'akmods_version=testing' } else if image =~ 'aurora|bluefin|cosmic' { 'akmods_version=stable' } else { '' } }}

    # TODO: should instead take advantage of the kernel version tags on the akmods images to avoid skew between nvidia/zfs and akmods.

    # akmods
    {{ if image =~ 'aurora|bluefin|cosmic' { 'akmods="$(yq -r ".images[] | select(.name == \"akmods-${akmods_version}\")" ' + image-file + ' | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"' } else { '' } }}
    {{ if image =~ 'aurora|bluefin|cosmic' { 'verify-container "${akmods#*-os/}"; BUILD_ARGS+=("--cpp-flag=-DAKMODS=$akmods")' } else { '' } }}

    # zfs
    {{ if image =~ 'cosmic|(aurora.*|bluefin.*)-beta' { 'akmods_zfs="$(yq -r ".images[] | select(.name == \"akmods-zfs-${akmods_version}\")" ' + image-file + ' | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"' } else { '' } }}
    {{ if image =~ 'cosmic|(aurora.*|bluefin.*)-beta' { 'verify-container "${akmods_zfs#*-os/}"; BUILD_ARGS+=("--cpp-flag=-DZFS=$akmods_zfs")' } else { '' } }}

    # nvidia
    {{ if image =~ 'cosmic-nv.*|(aurora-nv.*|bluefin-nv.*)-beta' { 'akmods_nvidia="$(yq -r ".images[] | select(.name == \"akmods-nvidia-open-${akmods_version}\")" ' + image-file + ' | yq -r "\"\(.image):\(.tag)@\(.digest)\"")"' } else { '' } }}
    {{ if image =~ 'cosmic-nv.*|(aurora-nv.*|bluefin-nv.*)-beta' { 'verify-container "${akmods_nvidia#*-os/}"; BUILD_ARGS+=("--cpp-flag=-DNVIDIA=$akmods_nvidia")' } else { '' } }}

    skopeo inspect docker://{{ if image =~ 'cosmic|(aurora.*|bluefin.*)-beta' { '"${akmods/:*@/@}"' } else { '"${check/:*@/@}"' } }} > "$BUILDTMP/inspect-{{ image }}.json"

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
    {{ if image =~ 'cosmic' { PODMAN + ' pull ' + common } else { '' } }}
    {{ if image =~ 'cosmic' { PODMAN + ' pull ' + brew } else { '' } }}

    # Labels
    BUILD_ARGS+=(
        "--label" "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses."
        "--label" "org.opencontainers.image.source=https://github.com/{{ repo_name }}/{{ repo_image_name }}"
        "--label" "org.opencontainers.image.title={{ repo_image_name }}"
        "--label" "org.opencontainers.image.version=$VERSION"
        "--label" "ostree.kernel_flavor={{ if image =~ 'bazzite' { 'bazzite' } else if image =~ 'beta' { 'coreos-testing' } else { 'coreos-stable' } }}"
        "--label" "ostree.linux=$(jq -r '.Labels["ostree.linux"]' < "$BUILDTMP"/inspect-{{ image }}.json)"
        "--unsetlabel=dev.hdd.rechunk.info"
        "--unsetlabel=io.artifacthub.package.deprecated"
        "--unsetlabel=io.artifacthub.package.keywords"
        "--unsetlabel=io.artifacthub.package.logo-url"
        "--unsetlabel=io.artifacthub.package.maintainers"
        "--unsetlabel=io.artifacthub.package.readme-url"
    )

    #Build Args
    BUILD_ARGS+=(
        "--build-arg" "IMAGE={{ image }}"
        "--build-arg" "BASE_IMAGE=${check%%:*}"
        "--build-arg" "TAG_VERSION=${check#*:}"
        "--build-arg" "VERSION=$VERSION"
    )

    # Additional Args
    BUILD_ARGS+=(
        "--security-opt" "label=disable"
        "--file" "Containerfile.in"
        "--tag" "{{ repo_image_name + ":" + image }}"
    )

    {{ PODMAN }} build "${BUILD_ARGS[@]}" {{ GIT_ROOT }}

    {{ if CI != '' { PODMAN + ' rmi -f "${check%@*}"' } else { '' } }}

# Rechunk Image
[group('Image')]
rechunk image="bluefin":
    #!/usr/bin/bash
    if [[ "$(id -u)" -ne 0 ]]; then
        {{ PODMAN + " unshare -- " + just + " rechunk " + image }}
        exit $?
    fi
    {{ ci_grouping }}
    echo "################################################################################"
    echo "image  := {{ image }}"
    echo "PODMAN := {{ PODMAN }}"
    echo "CI     := {{ CI }}"
    echo "whoami := {{ shell("whoami") }}"
    echo "################################################################################"
    set -eoux pipefail
    IMG="localhost/{{ repo_image_name + ":" + image }}"
    {{ PODMAN }} image exists "$IMG" || { echo "Image $IMG not found. Please build the image first." >&2; exit 1; }
    /usr/libexec/bootc-base-imagectl rechunk --max-layers=128 \
        localhost/{{ repo_image_name + ":" + image }} \
        {{ FQ_IMAGE_NAME + ":" + image }}

    {{ PODMAN }} images
    {{ PODMAN }} rmi -f "$IMG"
    {{ skopeo }} copy containers-storage:{{ FQ_IMAGE_NAME + ":" + image }} oci-archive:{{ repo_image_name + "_" + image + ".tar" }}

# Build ISO
[group('ISO')]
build-iso image="bluefin":
    {{ shell("mkdir -p $1/output", GIT_ROOT / BUILD_DIR) }}
    {{ SUDOIF }} \
        HOOK_pre_initramfs="{{ if image =~ 'bazzite' { GIT_ROOT / 'iso_files/preinitramfs.sh' } else { '' } }}" \
        HOOK_post_rootfs="{{ GIT_ROOT / 'iso_files/configure_iso.sh' }}" \
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
    sha256sum output.iso | tee {{ GIT_ROOT / BUILD_DIR / "output" / repo_image_name + "-" + image + ".iso-CHECKSUM" }}
    mv output.iso {{ GIT_ROOT / BUILD_DIR / "output" / repo_image_name + "-" + image + ".iso" }}
    {{ SUDOIF }} {{ just }} titanoboa::clean

# Run ISO
[group('ISO')]
run-iso image="bluefin":
    {{ if path_exists(GIT_ROOT / BUILD_DIR / "output" / repo_image_name + "-" + image + ".iso") == "true" { '' } else { just + " build-iso " + image } }}
    {{ just }} titanoboa::container-run-vm {{ GIT_ROOT / BUILD_DIR / "output" / repo_image_name + "-" + image + ".iso" }}

# Verify Container with Cosign
[group('Utility')]
verify-container container registry="ghcr.io/ublue-os" key="":
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
        cosign-sign
        gen-sbom
        rechunk
        run-iso
        sbom-sign
        sbom-attach
        secureboot
    )
    for recipe in "${recipes[@]}"; do
        {{ just }} _lint-recipe "shellcheck" "$recipe" bluefin
    done
    recipes=(
        clean
        lint-recipes
    )
    for recipe in "${recipes[@]}"; do
        {{ just }} _lint-recipe "shellcheck" "$recipe"
    done

# Login to GHCR
[group('CI')]
login-to-ghcr $user $token:
    echo "$token" | podman login ghcr.io -u "$user" --password-stdin
    {{ if `command -v docker || true` != '' { 'echo "$token" | docker login ghcr.io -u "$user" --password-stdin' } else { 'cat "${XDG_RUNTIME_DIR}/containers/auth.json" > ~/.docker/config.json' } }}

# Push Images to Registry
[group('CI')]
push-to-registry image dryrun="true" $destination="":
    for tag in {{ image }} {{ shell("skopeo inspect containers-storage:$1:$2 | jq -r '.Labels[\"org.opencontainers.image.version\"]'", FQ_IMAGE_NAME, image) }}; do \
        {{ if dryrun == "false" { 'skopeo copy containers-storage:' + FQ_IMAGE_NAME + ":" + image + " ${destination:-docker://" + IMAGE_REGISTRY + "}/" + repo_image_name + ":$tag >&2" } else { 'echo "$tag" >&2' } }} \
    ; done

# Sign Images with Cosign
[group('CI')]
cosign-sign digest $destination="":
    cosign sign -y --key env://COSIGN_PRIVATE_KEY "${destination:-{{ IMAGE_REGISTRY }}}/{{ repo_image_name + "@" + digest }}"

# Push and Sign
[group('CI')]
push-and-sign image: (login-to-ghcr env('ACTOR') env('TOKEN')) (push-to-registry image 'false' '') (cosign-sign shell('skopeo inspect oci-archive:$1_$2.tar --format "{{ .Digest }}"', repo_image_name, image))

# Generate SBOM
[group('CI')]
gen-sbom $input $output="":
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

# Add SBOM Signing
[group('CI')]
sbom-sign input $sbom="":
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
    {{ cosign }} verify-blob "${SBOM_VERIFY_ARGS[@]}"

# SBOM Attach (ORAS attach + cosign sign)
[group('CI')]
sbom-attach input $sbom="" $destination="":
    #!/usr/bin/bash
    set -eoux pipefail

    # set SBOM
    if [[ ! -f "$sbom" ]]; then
        sbom="$({{ just }} gen-sbom {{ input }})"
    fi

    : "${destination:={{ IMAGE_REGISTRY }}}"
    TMPDIR="$(mktemp -d -p .)"
    trap 'rm -rf "$TMPDIR"' EXIT SIGINT
    {{ skopeo }} inspect "{{ input }}" > "$TMPDIR/info.json"
    digest="$({{ jq }} -r '.Digest' < "$TMPDIR/info.json")"
    version="$({{ jq }} -r '.Labels["org.opencontainers.image.version"]' < "$TMPDIR/info.json")"

    pushd "$(dirname "$sbom")" > /dev/null
    {{ oras }} attach "$destination/{{ repo_image_name }}@${digest}" "$(basename "$sbom")" --artifact-type application/vnd.spdx+json -a "filename=$(basename "$sbom")" -a "org.opencontainers.image.version=$version"
    sbom_digest="$({{ oras }} discover "$destination/{{ repo_image_name }}@${digest}" --artifact-type application/vnd.spdx+json --format json | {{ jq }} -r '.manifests[0].digest')"
    {{ cosign }} sign -y --key env://COSIGN_PRIVATE_KEY "$destination/{{ repo_image_name }}@${sbom_digest}"
    popd > /dev/null

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
yq := which("yq")
[private]
jq := which("jq")
[private]
skopeo := which("skopeo")
[private]
oras := which("oras")
[private]
cosign := which("cosign")
[private]
syft := which("syft")

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
