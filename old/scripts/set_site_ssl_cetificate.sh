#!/bin/bash
set -euo pipefail

if [ "$(id -u)" != 0 ]; then
  echo "Run as root or with sudo."
  exit 1
fi

# Find all *-ssl.conf files in sites-available
SSL_CONF_FILES=($(find /etc/apache2/sites-available -name "*-ssl.conf" 2>/dev/null))

if [ ${#SSL_CONF_FILES[@]} -eq 0 ]; then
  echo "No *-ssl.conf files found."
  exit 1
fi

# Extract ServerName from each file
echo "Available SSL sites:"
for i in "${!SSL_CONF_FILES[@]}"; do
  conf_file="${SSL_CONF_FILES[$i]}"
  server_name=$(grep -oP 'ServerName \K[^ ]+' "$conf_file" | head -1)
  if [ -z "$server_name" ]; then
    server_name="unknown (check $conf_file)"
  fi
  echo "$((i+1))) $server_name"
done

# Prompt user to select
read -p "Select site number: " choice
index=$((choice-1))

if [ "$index" -lt 0 ] || [ "$index" -ge "${#SSL_CONF_FILES[@]}" ]; then
  echo "Invalid selection."
  exit 1
fi

VHOST_SSL="${SSL_CONF_FILES[$index]}"
SITE_URL=$(grep -oP 'ServerName \K[^ ]+' "$VHOST_SSL" | head -1)

# Search for cert files in /site_certs/SITE_URL
CERT_DIR="/site_certs/$SITE_URL"
CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
  echo "Certificate or key file not found in $CERT_DIR."
  echo "Expected: $CERT_FILE and $KEY_FILE"
  exit 1
fi

# Set correct permissions
chmod 644 "$CERT_FILE"
chmod 600 "$KEY_FILE"
chown root:root "$CERT_DIR"
chmod 700 "$CERT_DIR"

# Update SSL paths in virtual host
sed -i "s|SSLCertificateFile.*|SSLCertificateFile $CERT_FILE|" "$VHOST_SSL"
sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile $KEY_FILE|" "$VHOST_SSL"

systemctl reload apache2

echo "SSL updated for $SITE_URL using certificates from $CERT_DIR."   