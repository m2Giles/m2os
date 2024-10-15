ARG IMAGE="bluefin"
ARG FEDORA_VERSION="40"
ARG TAG_VERSION="stable-daily"

FROM scratch AS ctx
COPY / /

FROM ghcr.io/ublue-os/${IMAGE}:${TAG_VERSION} AS stage1

ARG IMAGE="bluefin"
ARG FEDORA_VERSION="40"

RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=ctx,src=/,dst=/ctx \
    /ctx/build.sh

FROM ghcr.io/ublue-os/base-main:${FEDORA_VERSION} AS cosmic

ARG IMAGE="cosmic"
ARG FEDORA_VERSION="40"
ARG CLEAN_CACHE="0"

RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=ctx,src=/,dst=/ctx \
    /ctx/build.sh
