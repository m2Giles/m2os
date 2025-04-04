ARG BASE_IMAGE="bluefin"
ARG IMAGE="bluefin"
ARG TAG_VERSION="stable-daily"

FROM scratch AS ctx
COPY build_files cosign.pub cosign-backup.pub /

FROM ghcr.io/ublue-os/${BASE_IMAGE}:${TAG_VERSION}

ARG BASE_IMAGE="bluefin"
ARG IMAGE="bluefin"
ARG SET_X=""
ARG VERSION=""

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=bind,src=/usr/bin/gh,dst=/usr/local/bin/gh \
    which gh; /ctx/build.sh
