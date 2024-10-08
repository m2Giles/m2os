#!/usr/bin/bash

set -eoux pipefail

# Autoload SSH Identities on Aurora
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

tee /tmp/ssh-add-identities-autorun.sh <<'EOF'
#!/usr/bin/sh
/usr/libexec/ssh-add-identities
EOF

if [[ ${IMAGE} =~ aurora ]]; then
    cp /tmp/ssh-add-identities /usr/libexec/
    chmod +x /usr/libexec/ssh-add-identities
    cp /tmp/ssh-add-identities-autorun.sh /etc/profile.d/
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
