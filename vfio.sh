#!/usr/bin/bash

set -oue pipefail

KERNEL_SUFFIX=""

tee /usr/lib/dracut/dracut.conf.d/vfio.conf <<'EOF'
add_drivers+=" vfio vfio_iommu_type1 vfio-pci "
EOF

tee /usr/lib/modprobe.d/kvmfr.conf <<'EOF'
options kvmfr static_size_mb=256
EOF

tee /usr/lib/udev/rules.d/99-kvmfr.rules <<'EOF'
SUBSYSTEM=="kvmfr", OWNER="root", GROUP="incus-admin", MODE="0660"
EOF

tee /etc/looking-glass-client.ini <<'EOF'
[app]
shmFile=/dev/kvmfr0
EOF

mkdir -p /etc/kvmfr/selinux/{mod,pp}
tee /etc/kvmfr/selinux/kvmfr.te <<'EOF'
module kvmfr 1.0;

 require {
     type device_t;
     type svirt_t;
     class chr_file { open read write map };
 }

 #============= svirt_t ==============
 allow svirt_t device_t:chr_file { open read write map };
EOF

semanage fcontext -a -t svirt_tmpfs_t /dev/kvmfr0
checkmodule -M -m -o /etc/kvmfr/selinux/mod/kvmfr.mod /etc/kvmfr/selinux/kvmfr.te
semodule_package -o /etc/kvmfr/selinux/pp/kvmfr.pp -m /etc/kvmfr/selinux/mod/kvmfr.mod
semodule -i /etc/kvmfr/selinux/pp/kvmfr.pp

QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"$KERNEL_SUFFIX"'-)//')"
/usr/libexec/rpm-ostree/wrapped/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible --zstd -v --add ostree -f "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"

chmod 0600 /lib/modules/"$QUALIFIED_KERNEL"/initramfs.img
