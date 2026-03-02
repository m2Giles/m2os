#!/usr/bin/bash

set -eoux pipefail

# shellcheck disable=SC1091
. /ctx/common.sh

# Group all of SELINUX policy files together
setfattr -n user.component -v "rpm/selinux-policy" /etc/selinux
find /etc/selinux -mindepth 1 -exec setfattr -n user.component -v "rpm/selinux-policy" {} \;

# Group all of the files that are part of the "bluefin" component together
[[ -d /usr/share/backgrounds/bluefin ]] && find /usr/share/backgrounds/bluefin -exec setfattr -n user.component -v "rpm/bluefin" {} \;
find /usr/share/ublue-os -exec setfattr -n user.component -v "rpm/bluefin" {} \; || :
find /usr/bin/ublue-* -exec setfattr -n user.component -v "rpm/bluefin" {} \; || :
[[ -x /usr/bin/luks-tpm2-autounlock ]] && setfattr -n user.component -v "rpm/bluefin" /usr/bin/luks-tpm2-autounlock
[[ -x /usr/bin/ujust ]] && setfattr -n user.component -v "rpm/bluefin" /usr/bin/ujust

# Group all of the Incus UI files together
[[ -d /usr/lib/incus ]] && find /usr/lib/incus -exec setfattr -n user.component -v "rpm/incus-ui" {} \;

# Group Brew Files together
[[ -f /usr/share/homebrew.tar.zst ]] && setfattr -n user.component -v "rpm/brew" /usr/share/homebrew.tar.zst
setfattr -n user.component -v "rpm/brew" /usr/lib/systemd/system/brew-*.service || :
setfattr -n user.component -v "rpm/brew" /usr/lib/systemd/system/brew-*.timer || :

# Group rpm-ostree rpmdb with rpm rpmdb
[[ -f /usr/lib/sysimage/rpm-ostree-base-db/rpmdb.sqlite ]] && setfattr -n user.component -v "rpm/rpm" /usr/lib/sysimage/rpm-ostree-base-db/rpmdb.sqlite
for file in $(rpm -q --fileprovide rpm); do
    [[ "$file" =~ .build-id ]] && continue
    [[ -f "$file" ]] && setfattr -n user.component -v "rpm/rpm" "$file"
done
