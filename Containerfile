ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin"
ARG IMAGE="bluefin"
ARG TAG_VERSION="stable-daily@sha256:0ed22a96f2982db02eff72733ae2dc0c1054c91b847e5e58a5d9e7b5d13c8748"

FROM scratch AS ctx
COPY build_files cosign.pub cosign-backup.pub /

FROM ${BASE_IMAGE}:${TAG_VERSION}

ARG BASE_IMAGE=""
ARG IMAGE=""
ARG SET_X=""
ARG VERSION=""
ARG KERNEL_FLAVOR=""
ARG akmods_digest=""
ARG akmods_nvidia_digest=""
ARG akmods_zfs_digest=""

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
