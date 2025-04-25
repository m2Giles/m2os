ARG BASE_IMAGE="bluefin"
ARG IMAGE="bluefin"
ARG TAG_VERSION="stable-daily@sha256:753c4a0a9232a9e1b69c690923fb38f6ab305a96e5911089d43a6211dbd302c0"

FROM scratch AS ctx
COPY build_files cosign.pub cosign-backup.pub /

FROM ghcr.io/ublue-os/${BASE_IMAGE}:${TAG_VERSION}

ARG BASE_IMAGE="bluefin"
ARG IMAGE="bluefin"
ARG SET_X=""
ARG VERSION=""

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    /ctx/build.sh
