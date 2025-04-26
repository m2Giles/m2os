ARG BASE_IMAGE="bluefin"
ARG IMAGE="bluefin"
ARG TAG_VERSION="stable-daily@sha256:18c6bb746f07ed7014584abd29ed56d09f05e43439bb844ae64991e8a996cb8d"

FROM scratch AS ctx
COPY build_files cosign.pub cosign-backup.pub /

FROM ghcr.io/ublue-os/${BASE_IMAGE}:${TAG_VERSION}

ARG BASE_IMAGE="bluefin"
ARG IMAGE="bluefin"
ARG SET_X=""
ARG VERSION=""

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    /ctx/build.sh
