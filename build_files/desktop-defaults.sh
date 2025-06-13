#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/common.sh

set -eoux pipefail

mkdir -p /etc/xdg/autostart
mkdir -p /etc/environment.d

# Zed SSD
tee /tmp/zed.conf <<EOF
ZED_WINDOW_DECORATIONS=server
EOF

# Autoload SSH Identities
tee /tmp/ssh-add-identities <<'EOF'
#!/usr/bin/bash
for IDENTITY in $(find ~/.ssh/*.pub -type f); do
    if [[ -f "${IDENTITY}" ]]; then
        if [[ "${IDENTITY}" =~ sign ]]; then
            ssh-add -c "${IDENTITY:0:-4}"
        else
            ssh-add "${IDENTITY:0:-4}"
        fi
    fi
done
EOF
chmod +x /tmp/ssh-add-identities

tee /tmp/ssh-add-identities.desktop <<'EOF'
[Desktop Entry]
Exec=/usr/libexec/ssh-add-identities
Icon=application-x-shellscript
Name=ssh-add-identities
Type=Application
X-KDE-AutostartScript=true
OnlyShowIn=KDE
EOF

# Copy for AURORA
if [[ ${IMAGE} =~ aurora ]]; then
    cp /tmp/ssh-add-identities /usr/libexec/
    cp /tmp/zed.conf /etc/environment.d/
    cp /tmp/ssh-add-identities.desktop /etc/xdg/autostart/
fi

if [[ "${IMAGE}" =~ bazzite|bluefin ]]; then
    tee /usr/share/glib-2.0/schemas/zz1-m2os-modifications.gschema.override <<'EOF'
[org.gnome.desktop.interface]
font-name='Inter 10'
document-font-name='Inter 10'
monospace-font-name='Cascadia Code NF 14'
color-scheme='prefer-dark'
gtk-theme='adw-gtk3-dark'
EOF
fi

if [[ "${IMAGE}" =~ bluefin ]]; then
    tee -a /usr/share/glib-2.0/schemas/zz1-m2os-modifications.gschema.override <<'EOF'
[org.gnome.shell]
enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com', 'blur-my-shell@aunetx', 'gsconnect@andyholmes.github.io', 'logomenu@aryan_k', 'search-light@icedman.github.com', 'hotedge@jonathan.jdoda.ca', 'just-perfection-desktop@just-perfection', 'caffeine@patapon.info', 'compiz-windows-effect@hermes83.github.com']

[org.gnome.shell.extensions.blur-my-shell.overview]
style-components=3

[org.gnome.shell.extensions.just-perfection]
workspace-switcher-size=15
EOF
fi

if [[ "${IMAGE}" =~ bluefin|bazzite ]]; then
    mkdir -p /tmp/ublue-schema-test
    find /usr/share/glib-2.0/schemas/ -type f ! -name "*.gschema.override" -exec cp {} /tmp/ublue-schema-test/ \;
    cp /usr/share/glib-2.0/schemas/*-m2os-modifications.gschema.override /tmp/ublue-schema-test/
    echo "Running error test for m2os gschema override. Aborting if failed."
    glib-compile-schemas --strict /tmp/ublue-schema-test || exit 1
    echo "Compiling gschema to include bos setting overrides"
    glib-compile-schemas /usr/share/glib-2.0/schemas &>/dev/null
fi
