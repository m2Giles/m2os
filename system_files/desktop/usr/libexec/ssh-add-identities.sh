#!/usr/bin/bash

shopt -s nullglob

for IDENTITY in ~/.ssh/*.pub; do
    if [[ -f "${IDENTITY:0:-4}" ]]; then
        if [[ "${IDENTITY}" =~ -sign.pub$ ]]; then
            ssh-add -c "${IDENTITY:0:-4}"
        else
            ssh-add "${IDENTITY:0:-4}"
        fi
    fi
done
