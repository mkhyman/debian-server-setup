#!/bin/bash
set -euo pipefail

echo THIS SCRIPT IS UNTESTED..... BEWARE!!!

if [ "$(id -u)" != 0 ]; then
  echo "Run as root or with sudo."
  exit 1
fi

# Install Nginx if not present
if ! command -v nginx &>/dev/null; then
  echo "Installing Nginx..."
  apt update && apt install -y nginx
  systemctl enable nginx && systemctl start nginx
fi

# Check for active PHP-FPM services
if systemctl is-active --quiet php*-fpm; then
  echo "PHP-FPM detected. Nginx can now use multiple PHP versions."
else
  echo "No PHP-FPM service found. Install php-fpm to enable PHP support."
  exit 0
fi

echo "Nginx is ready. Configure each site with:"
echo "  location ~ \\.php\$ {"
echo "    fastcgi_pass unix:/run/php/phpX.X-fpm.sock;"
echo "    include snippets/fastcgi-php.conf;"
echo "  }"   