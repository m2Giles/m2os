#!/usr/bin/bash

set -eoux pipefail

if [[ -z "${KERNEL_FLAVOR:-}" ]]; then
    KERNEL_FLAVOR=coreos-stable
fi

KERNEL_SUFFIX=""
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"$KERNEL_SUFFIX"'-)//')"

# KVMFR KMOD
tee /etc/yum.repos.d/_copr_hikariknight-looking-glass-kvmfr.repo <<'EOF'
[copr:copr.fedorainfracloud.org:hikariknight:looking-glass-kvmfr]
name=Copr repo for looking-glass-kvmfr owned by hikariknight
baseurl=https://download.copr.fedorainfracloud.org/results/hikariknight/looking-glass-kvmfr/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/hikariknight/looking-glass-kvmfr/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

VFIO_PACKAGES=(
    edk2-ovmf
    libvirt
    qemu
)

if [[ ! "$IMAGE" =~ ucore|cosmic ]]; then
    VFIO_PACKAGES+=(virt-manager)
fi

if [[ ! "${IMAGE}" =~ bazzite ]]; then
    skopeo copy docker://ghcr.io/ublue-os/akmods:"${KERNEL_FLAVOR}"-"$(rpm -E %fedora)"-"${QUALIFIED_KERNEL}" dir:/tmp/akmods
    AKMODS_TARGZ=$(jq -r '.layers[].digest' < /tmp/akmods/manifest.json | cut -d : -f 2)
    tar -xvzf /tmp/akmods/"$AKMODS_TARGZ" -C /tmp/
    VFIO_PACKAGES+=(/tmp/rpms/kmods/*kvmfr*.rpm)
fi
    
rpm-ostree install "${VFIO_PACKAGES[@]}"

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

/usr/libexec/rpm-ostree/wrapped/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible --zstd -v --add ostree -f "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"

chmod 0600 /lib/modules/"$QUALIFIED_KERNEL"/initramfs.img

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
