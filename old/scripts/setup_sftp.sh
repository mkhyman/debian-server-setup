#!/bin/bash
set -euo pipefail

if [ "$(id -u)" != 0 ]; then
  echo "Run as root or with sudo."
  exit 1
fi

# Ensure SSH is installed (SFTP is part of OpenSSH)
apt update
apt install -y openssh-server

# Configure SFTP-only access
cat >> /etc/ssh/sshd_config << 'EOF'

# SFTP-only group
Match Group sftpusers
    ChrootDirectory %h
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF

# Create group
groupadd -f sftpusers

# Restart SSH
systemctl restart ssh

echo "SFTP server configured. FTP is not installed."   