#!/usr/bin/bash

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

tee /tmp/ssh-add-identities.desktop<<'EOF'
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

mkdir -p /usr/share/user-tmpfiles.d
tee /usr/share/user-tmpfiles.d/editor.conf <<EOF
C %h/.config/environment.d/editor.conf - - - - /usr/share/ublue-os/etc/environment.d/default-editor.conf
EOF

mkdir -p /usr/share/ublue-os/etc/environment.d
tee /usr/share/ublue-os/etc/environment.d/default-editor.conf <<EOF
EDITOR=/usr/bin/vim
VISUAL=/usr/bin/emacs
EOF

if [[ "${IMAGE}" =~ bazzite|bluefin ]]; then
    tee /usr/share/glib-2.0/schemas/zz1-m2os-modifications.gschema.override << 'EOF'
[org.gnome.desktop.interface]
color-scheme='prefer-dark'
gtk-theme='adw-gtk3'
EOF
fi
