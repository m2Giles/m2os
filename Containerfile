ARG IMAGE="bluefin"
ARG FEDORA_VERSION="40"
ARG KERNEL_FLAVOR="coreos-stable"
ARG TAG_VERSION="stable"
ARG TAG="bluefin"

FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION} AS akmods

FROM scratch AS ctx
COPY / /

FROM ghcr.io/ublue-os/${IMAGE}:${TAG_VERSION} AS stage1

ARG IMAGE="bluefin"
ARG FEDORA_VERSION="40"
ARG KERNEL_FLAVOR="coreos-stable"
ARG NVIDIA=""

RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=ctx,src=/,dst=/ctx \
    /ctx/build.sh

FROM ghcr.io/m2giles/m2os:${TAG} AS cosmic

ARG IMAGE="cosmic-bluefin"

RUN --mount=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=ctx,src=/,dst=/ctx \
    /ctx/build.sh
