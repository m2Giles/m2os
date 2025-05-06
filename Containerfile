ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin"
ARG IMAGE="bluefin"
ARG TAG_VERSION="stable-daily@sha256:0a5257eb026a6d84fc3f81a66b1adb4203799264721978b9e099ebe7ca0df88e"

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
