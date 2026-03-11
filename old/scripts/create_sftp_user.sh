#!/bin/bash
set -euo pipefail

if [ "$(id -u)" != 0 ]; then
  echo "Run as root or with sudo."
  exit 1
fi

read -p "Enter existing username: " username

# Validate user exists
if ! id "$username" &>/dev/null; then
  echo "User $username does not exist."
  exit 1
fi

# Check for SSH authorized_keys
home_dir=$(getent passwd "$username" | cut -d: -f6)
ssh_dir="$home_dir/.ssh"
auth_keys="$ssh_dir/authorized_keys"

if [ ! -f "$auth_keys" ] || [ ! -s "$auth_keys" ]; then
  echo "Error: No SSH authorized_keys file found for $username."
  echo "SFTP setup requires SSH key authentication to be configured first."
  exit 1
fi

# Add user to sftpusers group
groupadd -f sftpusers
usermod -aG sftpusers "$username"

# Set user's home to /$username (inside chroot)
usermod -d "/$username" "$username"

# Ensure /home is root-owned
chown root:root /home
chmod 755 /home

echo "User $username can now access their home directory via SFTP, using their private key."   