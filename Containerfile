ARG IMAGE="bluefin"
ARG FEDORA_VERSION="40"
ARG KERNEL_FLAVOR="coreos-stable"
ARG TAG_VERSION="stable"

FROM scratch AS ctx
COPY / /

FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION} AS akmods
FROM ghcr.io/ublue-os/akmods-nvidia:${KERNEL_FLAVOR}-${FEDORA_VERSION} AS akmods-nvidia
FROM ghcr.io/ublue-os/akmods-zfs:coreos-stable-${FEDORA_VERSION} AS akmods-zfs
FROM ghcr.io/ublue-os/coreos-stable-kernel:${FEDORA_VERSION} AS kernel
FROM ghcr.io/ublue-os/config:latest AS config

FROM ghcr.io/ublue-os/${IMAGE}:${TAG_VERSION}

ARG IMAGE="bluefin"
ARG FEDORA_VERSION="40"
ARG KERNEL_FLAVOR="coreos-stable"
ARG NVIDIA=""

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=bind,from=akmods,src=/rpms/kmods,dst=/tmp/akmods \
    --mount=type=bind,from=akmods-nvidia,src=/rpms,dst=/tmp/akmods-rpms \
    --mount=type=bind,from=akmods-zfs,source=/rpms/kmods/zfs,target=/tmp/akmods-zfs \
    --mount=type=bind,from=kernel,src=/tmp/rpms,dst=/tmp/kernel-rpms \
    --mount=type=bind,from=config,src=/rpms,dst=/tmp/config-rpms \
    /ctx/build.sh
