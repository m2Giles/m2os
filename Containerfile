ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin"
ARG IMAGE="bluefin"
ARG TAG_VERSION="stable-daily@sha256:f8381856053044c03f6d7370e3d8b76f24f6efc6f41d25b7c01a663d035874d6"

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
