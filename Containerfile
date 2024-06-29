ARG IMAGE="${IMAGE:-bluefin}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-40}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-coreos}"
FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION} as akmods

FROM ghcr.io/ublue-os/${IMAGE}:stable

COPY build.sh /tmp/build.sh
COPY --from=akmods /rpms /tmp/akmods-rpms

RUN mkdir -p /var/lib/alternatives && \
    /tmp/build.sh && \
    ostree container commit
