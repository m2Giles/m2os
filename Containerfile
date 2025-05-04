ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin"
ARG IMAGE="bluefin"
ARG TAG_VERSION="stable-daily@sha256:ae9ac59f4331883f18299c1a3e60a13a7b27f1d5dc7966d95c2a74ade4955288"

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
