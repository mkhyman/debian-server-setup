#!/bin/bash
set -euo pipefail

if [ "$(id -u)" != 0 ]; then
  echo "Run as root or with sudo."
  exit 1
fi

# Detect distro
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
else
  echo "Unsupported distribution."
  exit 1
fi

if [[ ! "$DISTRO" =~ ^(ubuntu|debian)$ ]]; then
  echo "This script currently supports only Debian/Ubuntu."
  exit 1
fi

# Save current systemd defaults
echo "Saving current systemd defaults..."
CURRENT_INTERVAL=$(systemctl show --property=DefaultStartLimitIntervalSec)
CURRENT_BURST=$(systemctl show --property=DefaultStartLimitBurst)

# Disable rate limiting during installation
echo "Disabling systemd start limits to prevent restart throttling..."
systemctl set-property --runtime -- system DefaultStartLimitIntervalSec=0 DefaultStartLimitBurst=0

# Show installed versions
echo "=== Installed PHP versions ==="
dpkg -l | grep -E '^ii' | grep -o 'php[0-9]\.[0-9]' | sort -u || echo "None"

# Add Sury repo
apt update
apt install -y lsb-release ca-certificates apt-transport-https wget gnupg
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
apt update

# Show available versions
echo
echo "=== Available PHP versions ==="
apt-cache search ^php[0-9]\.[0-9]-cli | grep -o 'php[0-9.]*' | sort -u | cut -d'-' -f1 | sort -rV

# Prompt for versions
echo
read -rp "Enter PHP versions to install (e.g. 7.4 8.2): " versions

# Common modules
modules=("opcache" "gd" "mysql" "curl" "mbstring" "xml" "zip" "bcmath" "intl" "redis" "imagick")

echo
echo "Select modules to install:"
for mod in "${modules[@]}"; do
  read -rp "Install $mod? (y/n): " choice
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    MODULES_TO_INSTALL+="$mod "
  fi
done

# Install selected versions and modules
for ver in $versions; do
  echo "Installing PHP $ver..."
  # Install all packages in one command to avoid repeated restarts
  apt install -y php$ver php$ver-cli php$ver-fpm php$ver-${MODULES_TO_INSTALL// / php$ver-}
done

# Restore original systemd defaults
echo "Restoring original systemd defaults..."
systemctl set-property --runtime -- system "$CURRENT_INTERVAL" "$CURRENT_BURST"

echo "PHP installation complete."   
