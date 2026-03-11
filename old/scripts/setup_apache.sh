#!/bin/bash
set -euo pipefail

if [ "$(id -u)" != 0 ]; then
  echo "Run as root or with sudo."
  exit 1
fi

# Ensure ssl-cert is installed
if ! dpkg -l | grep -q ssl-cert; then
  echo "Installing ssl-cert... (snakeoil signing certificates)"
  apt install -y ssl-cert
fi

# Create /site_certs with correct permissions if it doesn't exist
SITE_CERTS="/site_certs"
if [ ! -d "$SITE_CERTS" ]; then
  mkdir "$SITE_CERTS"
  chown root:root "$SITE_CERTS"
  chmod 700 "$SITE_CERTS"
  echo "Created $SITE_CERTS with restricted permissions."
fi

# Install Apache if not present
if ! command -v apache2 &>/dev/null; then
  echo "Installing Apache..."
  apt update && apt install -y apache2
  systemctl enable apache2 && systemctl start apache2
fi

# Enable required modules for PHP-FPM
echo "Enabling Apache modules for PHP-FPM..."
a2enmod proxy_fcgi setenvif actions alias

# Restart Apache
systemctl restart apache2

echo "Apache is now configured to support multiple PHP versions via PHP-FPM."
echo "Configure each virtual host with:"
echo "  <FilesMatch \\.php$>"
echo "    SetHandler \"proxy:unix:/run/php/phpX.X-fpm.sock|fcgi://localhost/\""
echo "  </FilesMatch>"   