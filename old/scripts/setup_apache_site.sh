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

read -p "Enter site URL (e.g. example.com): " SITE_URL
read -p "Enter site username: " SITE_USER

# Check if user exists
if ! id "$SITE_USER" &>/dev/null; then
  echo "User $SITE_USER does not exist."
  exit 1
fi

# Get home directory and check if it exists
HOME_DIR=$(getent passwd "$SITE_USER" | cut -d: -f6)
if [ ! -d "$HOME_DIR" ]; then
  echo "Home directory $HOME_DIR does not exist."
  exit 1
fi

echo "User $SITE_USER and home directory verified."

# Create site directory only if it doesn't exist
SITE_DIR="$HOME_DIR/site"
if [ ! -d "$SITE_DIR" ]; then
  mkdir "$SITE_DIR"
  chown "$SITE_USER:$SITE_USER" "$SITE_DIR"
  echo "Site directory created at $SITE_DIR."
else
  echo "Site directory $SITE_DIR already exists."
fi

# Check available PHP versions
echo "Available PHP versions:"
PHP_VERSIONS=($(ls /run/php/php*-fpm.sock 2>/dev/null | grep -o 'php[0-9.]*' | sort -u | cut -d'-' -f1))
if [ ${#PHP_VERSIONS[@]} -eq 0 ]; then
  echo "No PHP-FPM versions found."
  exit 1
fi
for ver in "${PHP_VERSIONS[@]}"; do
  echo "  - ${ver#php}"
done

read -p "Select PHP version: " PHP_VER
if ! [[ " ${PHP_VERSIONS[@]} " =~ " php$PHP_VER " ]]; then
  echo "Invalid PHP version."
  exit 1
fi

# Create HTTP virtual host (redirect)
VHOST_HTTP="/etc/apache2/sites-available/${SITE_URL}.conf"
cat > "$VHOST_HTTP" << EOF
<VirtualHost *:80>
    ServerName $SITE_URL
    Redirect permanent / https://$SITE_URL/
</VirtualHost>
EOF

# Create HTTPS virtual host
VHOST_HTTPS="/etc/apache2/sites-available/${SITE_URL}-ssl.conf"
cat > "$VHOST_HTTPS" << EOF
<VirtualHost *:443>
    ServerName $SITE_URL
    DocumentRoot $SITE_DIR

    <Directory $SITE_DIR>
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key

    <FilesMatch \\\.php$>
        SetHandler "proxy:unix:/run/php/php$PHP_VER-fpm.sock|fcgi://localhost/"
    </FilesMatch>
</VirtualHost>
EOF

# Enable sites
a2ensite "${SITE_URL}.conf"
a2ensite "${SITE_URL}-ssl.conf"
systemctl reload apache2

echo "Site $SITE_URL created with HTTP to HTTPS redirect and PHP $PHP_VER."   