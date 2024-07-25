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

FROM ghcr.io/ublue-os/${IMAGE}:${TAG_VERSION}

ARG IMAGE="${IMAGE:-bluefin}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-40}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-coreos-stable}"

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=bind,from=akmods,src=/rpms/kmods,dst=/tmp/akmods \
    --mount=type=bind,from=akmods-nvidia,src=/rpms/kmods,dst=/tmp/akmods-rpms \
    --mount=type=bind,from=akmods-zfs,source=/rpms/kmods/zfs,target=/tmp/akmods-zfs \
    --mount=type=bind,from=kernel,src=/tmp/rpms,dst=/tmp/kernel-rpms \
    mkdir -p /var/lib/alternatives && \
    /ctx/build.sh && \
    mv /var/lib/alternatives/ /staged-alternatives && \
    rm -rf /tmp/ || true && \
    rm -rf /var/ || true && \
    mkdir -p /var/lib/ && mv /staged-alternatives /var/lib/alternatives && \
    ostree container commit
