#!/usr/bin/bash

set -eou pipefail

# shellcheck disable=SC1091
. /ctx/common.sh

# Group all of SELINUX policy files together
find /etc/selinux | while read -r file; do
    setfattr -n user.component -v "selinux-policy" "$file"
done

# Group all of the files that are part of the "bluefin" component together
if [[ -d /usr/share/bluefin ]]; then
    find /usr/share/bluefin | while read -r file; do
        setfattr -n user.component -v "bluefin" "$file"
    done
fi
if [[ -d /usr/share/backgrounds/bluefin ]]; then
    find /usr/share/backgrounds/bluefin | while read -r file; do
        setfattr -n user.component -v "bluefin" "$file"
    done
fi
if [[ -d /usr/share/ublue-os ]]; then
    find /usr/share/ublue-os | while read -r file; do
        setfattr -n user.component -v "bluefin" "$file"
    done
fi
find /usr/bin/ | while read -r file; do
    if [[ "$file" =~ ublue-* ]]; then
        setfattr -n user.component -v "bluefin" "$file"
    fi
done
if [[ -x /usr/bin/luks-tpm2-autounlock ]]; then
    setfattr -n user.component -v "bluefin" /usr/bin/luks-tpm2-autounlock
fi
if [[ -x /usr/bin/ujust ]]; then
    setfattr -n user.component -v "bluefin" /usr/bin/ujust
fi

# Group all of the Incus UI files together
if [[ -d /usr/lib/incus ]]; then
    find /usr/lib/incus | while read -r file; do
        if [[ -f "$file" ]]; then
            setfattr -n user.component -v "incus-ui" "$file"
        fi
    done
fi

# Group Brew Files together
find /usr -regex "\(.*homebrew.*\|.*brew-.*\.\(service\|timer\)\)" | while read -r file; do
    setfattr -n user.component -v "brew" "$file"
done

# Tag RPM-Ostree sqlite db
if [[ -f /usr/lib/sysimage/rpm-ostree-base-db/rpmdb.sqlite ]]; then
    setfattr -n user.component -v "rpm" /usr/lib/sysimage/rpm-ostree-base-db/rpmdb.sqlite
fi
# for file in $(rpm -q --fileprovide rpm); do
#     [[ "$file" =~ .build-id ]] && continue
#     [[ -e "$file" ]] && setfattr -n user.component -v "rpm" "$file"
# done

# rawdata="$(rpm -qa --queryformat '%{SOURCERPM}|%{NAME}\n' | grep -v "(none)")"
# json_srpms="$(echo "$rawdata" | jq -R 'split("|") | {srpm: .[0], rpm: .[1]}')"
# json_data="$(echo "$json_srpms" | jq -s 'group_by(.srpm) | map({(.[0].srpm): map(.rpm)}) | add')"

# total_rpms=0
# srpm_count=0
# for srpm in $(echo "$json_data" | jq -r 'keys[]'); do
#     file_count=0
#     rpms="$(echo "$json_data" | jq -r --arg srpm "$srpm" '.[$srpm][]')"
#     for rpm in $rpms; do
#         if [[ "$rpm" =~ kernel-core ]]; then
#             setfattr -n user.component -v "$srpm" "$(find /usr/lib/modules -type f -name initramfs.img)" 2>/dev/null || :
#             ((file_count+=1))
#         fi
#         for file in $(rpm -q --queryformat '%{FILENAMES}\n' "$rpm"); do
#             if [[ "$file" =~ .build-id ]]; then
#                 continue
#             fi
#             if getfattr -n user.component "$file" &> /dev/null; then
#                 continue
#             fi
#             if [[ -f "$file" || -d "$file" ]]; then
#                 setfattr -n user.component -v "$srpm" "$file" 2>/dev/null || :
#                 ((file_count+=1))
#             fi
#         done
#     ((total_rpms+=1))
#     done
#     echo "Processed $file_count files for $srpm"
#     ((srpm_count+=1))
# done
# echo "Processed $total_rpms RPMs across $srpm_count SRPMs"

find /usr /etc -type f -size +1M 2>/dev/null | while read -r file; do
    if ! rpm -qf "$file" &>/dev/null; then
        if ! getfattr -n user.component "$file" &>/dev/null; then
            echo "$file: unpackaged"
        fi
    fi
done
