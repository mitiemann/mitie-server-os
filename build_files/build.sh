#!/bin/bash

set -eoux pipefail

# Not sure whether this is the right approach: but it works!
# Netbird
# sudo tee /etc/yum.repos.d/netbird.repo <<EOF
# [netbird]
# name=netbird
# baseurl=https://pkgs.netbird.io/yum/
# enabled=1
# gpgcheck=0
# gpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key
# repo_gpgcheck=1
# EOF

# Post-install scripts attempt to start the netbird service, which fails in a
# container build environment (no systemd). The install itself succeeds.
dnf5 install -y netbird || echo "WARNING: netbird post-install failed (service start expected to fail in container)"

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y \
    cockpit \
    firewalld \
    just \
    policycoreutils-python-utils \
    tmux

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable cockpit.socket
systemctl enable netbird.service
systemctl enable podman.socket

# ostree cannot deploy image layers that contain files with non-ASCII filenames
# when the installer runs with a non-UTF-8 locale (e.g. Anaconda live env).
# Remove any such files from the image at build time and log them.
python3 - <<'EOF'
import os
log = []
for top in ('/usr', '/etc'):
    for root, dirs, files in os.walk(top, topdown=False):
        for name in files:
            try:
                name.encode('ascii')
            except UnicodeEncodeError:
                path = os.path.join(root, name)
                try:
                    os.remove(path)
                    log.append(path)
                except OSError as e:
                    log.append(f"{path} (removal failed: {e})")
os.makedirs('/usr/share/mitie-server-os', exist_ok=True)
with open('/usr/share/mitie-server-os/removed-non-ascii-files.log', 'w') as f:
    f.write('\n'.join(log) + ('\n' if log else ''))
if log:
    print(f"Removed {len(log)} non-ASCII filename(s); see /usr/share/mitie-server-os/removed-non-ascii-files.log")
else:
    print("No non-ASCII filenames found.")
EOF

# Clean up DNF state left in /var during the build.
# On bootc images /var is a separate writable layer; baking in build-time
# state triggers bootc lint warnings and needlessly grows the image.
rm -rf /var/lib/dnf /var/lib/PackageKit

# Restore correct SELinux contexts for files copied from system_files/.
# Without this, COPY sets container_file_t which sshd cannot read.
restorecon -rv /etc/ssh/

# Set ssh_home_t on authorized_keys.d so sshd_t can read it as an
# AuthorizedKeysFile path. restorecon alone assigns etc_t, which sshd
# silently skips on SELinux enforcing systems (Fedora CoreOS default).
# semanage persists the mapping so future restorecon calls don't revert it.
semanage fcontext -a -t ssh_home_t '/etc/ssh/authorized_keys.d(/.*)?'
restorecon -rv /etc/ssh/authorized_keys.d/
