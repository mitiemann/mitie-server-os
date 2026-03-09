#!/bin/bash

set -oux pipefail

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

dnf5 install -y netbird

set -e

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y \
    cockpit \
    just \
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

### User setup

useradd -G wheel mitiemann

# Store SSH key in /etc so it survives bootc deployment (/var/home is stateful)
mkdir -p /etc/ssh/authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/uF7fR5OHvw9gY7BTKC8PEIR1vOk99B6ZyLAIAO3pB mitiemann@mitie-tueai" \
    > /etc/ssh/authorized_keys/mitiemann
chmod 700 /etc/ssh/authorized_keys
chmod 600 /etc/ssh/authorized_keys/mitiemann

