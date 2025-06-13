#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

KERNEL_VERSION="$(rpm -q --queryformat="%{EVR}.%{ARCH}" kernel-core)"

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
semodule -i /etc/kvmfr/selinux/pp/kvmfr.pp # Seems broken with Docker

export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/lib/modules/$KERNEL_VERSION/initramfs.img"

chmod 0600 /lib/modules/"$KERNEL_VERSION"/initramfs.img

# VFIO Kargs
tee /usr/libexec/vfio-kargs.sh <<'EOF'
#!/usr/bin/bash
CPU_VENDOR=$(grep "vendor_id" "/proc/cpuinfo" | uniq | awk -F": " '{ print $2 }')
if [[ "${CPU_VENDOR}" == "GenuineIntel" ]]; then
    VENDOR_KARG="intel_iommu=on"
elif [[ "${CPU_VENDOR}" == "AuthenticAMD" ]]; then
    VENDOR_KARG="amd_iommu=on"
fi
rpm-ostree kargs \
    --append-if-missing="${VENDOR_KARG}" \
    --append-if-missing="iommu=pt" \
    --append-if-missing="rd.driver.pre=vfio_pci" \
    --append-if-missing="vfio_pci.disable_vga=1"
EOF

chmod +x /usr/libexec/vfio-kargs.sh
