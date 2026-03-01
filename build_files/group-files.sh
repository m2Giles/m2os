#!/usr/bin/bash

set -eoux pipefail

# Group all of SELINUX policy files together
setfattr -n user.component -v "rpm/selinux-policy" /etc/selinux
find /etc/selinux -mindepth 1 -exec setfattr -n user.component -v "rpm/selinux-policy" {} \;

# Group all of the files that are part of the "bluefin" component together
find /usr/share/backgrounds/bluefin -exec setfattr -n user.component -v "rpm/bluefin" {} \;
find /usr/share/ublue-os -exec setfattr -n user.component -v "rpm/bluefin" {} \;
find /usr/bin/ublue-* -exec setfattr -n user.component -v "rpm/bluefin" {} \;
setfattr -n user.component -v "rpm/bluefin" /usr/bin/luks-tpm2-autounlock
setfattr -n user.component -v "rpm/bluefin" /usr/bin/ujust

# Group all of the Incus UI files together
find /usr/lib/incus -exec setfattr -n user.component -v "rpm/incus-ui" {} \;

# Group Brew Files together
setfattr -n user.component -v "rpm/brew" /usr/share/homebrew.tar.zst
setfattr -n user.component -v "rpm/brew" /usr/lib/systemd/system/brew-*.service
setfattr -n user.component -v "rpm/brew" /usr/lib/systemd/system/brew-*.timer
