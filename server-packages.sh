#!/usr/bin/bash

set -eoux pipefail

# Docker Repo
tee /etc/yum.repos.d/docker-ce.repo <<'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF

# Get Incus Client
curl -Lo /usr/bin/incus \
    "https://github.com/lxc/incus/releases/latest/download/bin.linux.incus.$(uname -m)"

chmod +x /usr/bin/incus

mkdir -p /var/roothome/
incus completion bash | tee /usr/share/bash-completion/completions/incus

rpm-ostree install \
    bootc \
    rclone \
    sbsigntools \
    socat \
    swtpm

if [[ ! ${IMAGE} =~ ucore ]]; then
    rpm-ostree install \
        containerd.io \
        docker-buildx-plugin \
        docker-ce \
        docker-ce-cli \
        docker-compose-plugin
else
    rpm-ostree override remove \
        containerd \
        moby-engine \
        runc \
        --install=containerd.io \
        --install=docker-buildx-plugin \
        --install=docker-ce \
        --install=docker-ce-cli \
        --install=docker-compose-plugin
fi

# Docker sysctl.d
mkdir -p /usr/lib/sysctl.d
echo "net.ipv4.ip_forward = 1" >/usr/lib/sysctl.d/docker-ce.conf

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
