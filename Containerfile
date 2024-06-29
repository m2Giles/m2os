ARG IMAGE="${IMAGE:-bluefin}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-40}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-coreos}"

FROM ghcr.io/ublue-os/${IMAGE}:stable
FROM ghcr.io/ublue-os/akmods:${FEDORA_VERSION}-${KERNEL_FLAVOR} as akmods

COPY build.sh /tmp/build.sh
COPY --from=akmods /rpms /tmp/akmods-rpms

RUN mkdir -p /var/lib/alternatives && \
    /tmp/build.sh && \
    ostree container commit
