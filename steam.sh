#!/usr/bin/bash

set -eoux pipefail

sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-nonfree-steam.repo
rpm-ostree install steam
sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree-steam.repo
