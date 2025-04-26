ARG BASE_IMAGE="bluefin"
ARG IMAGE="bluefin"
ARG TAG_VERSION="stable-daily@sha256:7bb31fff29930e73fe52cee16779dcefcc52ae8b92c61ae0e881316b421dfd97"

FROM scratch AS ctx
COPY build_files cosign.pub cosign-backup.pub /

FROM ghcr.io/ublue-os/${BASE_IMAGE}:${TAG_VERSION}

ARG BASE_IMAGE="bluefin"
ARG IMAGE="bluefin"
ARG SET_X=""
ARG VERSION=""

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    /ctx/build.sh
