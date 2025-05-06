ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin"
ARG IMAGE="bluefin"
ARG TAG_VERSION="stable-daily@sha256:5fef5197184d7d542d425a4ab96b2d1f2cf5cad84f47235e78b16a6df6b2aab2"

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
