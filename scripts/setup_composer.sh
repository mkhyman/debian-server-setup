#!/bin/bash
set -euo pipefail

# Check if PHP is installed
if ! dpkg -l | grep -q '^ii.*php'; then
  echo "PHP is not installed. Composer requires PHP."
  exit 1
fi

# Get installed PHP versions
PHP_VERSIONS=($(dpkg -l | grep -o 'php[0-9]\.[0-9]' | sort -u))
if [ ${#PHP_VERSIONS[@]} -eq 0 ]; then
  echo "No PHP versions found."
  exit 1
fi

# Required extensions
EXTENSIONS=("curl" "mbstring" "xml")

# Array to track installed packages
INSTALLED_PKGS=()

# Install missing extensions for each PHP version
for ver in "${PHP_VERSIONS[@]}"; do
  for ext in "${EXTENSIONS[@]}"; do
    pkg="php${ver/./-}-$ext"
    if ! dpkg -l | grep -q "^ii.*$pkg"; then
      echo "Installing $pkg..."
      apt install -y "$pkg"
      INSTALLED_PKGS+=("$pkg")
    fi
  done
done

# Install Composer
apt install -y composer

# Improved output message
if [ ${#INSTALLED_PKGS[@]} -eq 0 ]; then
  echo "Composer installed. No additional PHP extensions were required."
else
  echo "Composer installed with the following PHP extension packages:"
  printf '  - %s\n' "${INSTALLED_PKGS[@]}"
fi   