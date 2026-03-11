#!/bin/bash
set -euo pipefail

if [ "$(id -u)" != 0 ]; then
  echo "Run as root or with sudo."
  exit 1
fi

# Install Git if missing
if ! command -v git &> /dev/null; then
  echo "Git not found. Installing..."
  apt update
  apt install -y git
  echo "Git installed."
else
  echo "Git is already installed."
fi

# Find SSL config files
SSL_CONF_FILES=($(find /etc/apache2/sites-available -name "*-ssl.conf" 2>/dev/null))
if [ ${#SSL_CONF_FILES[@]} -eq 0 ]; then
  echo "No -ssl.conf files found."
  exit 1
fi

# List sites
echo "Available sites:"
for i in "${!SSL_CONF_FILES[@]}"; do
  server_name=$(grep -oP 'ServerName \K[^ ]+' "${SSL_CONF_FILES[$i]}" | head -1)
  echo "$((i+1))) $server_name"
done

# Select site
read -p "Select site: " choice
index=$((choice - 1))
if [ "$index" -lt 0 ] || [ "$index" -ge "${#SSL_CONF_FILES[@]}" ]; then
  echo "Invalid choice."
  exit 1
fi

SITE_CONF="${SSL_CONF_FILES[$index]}"
SITE_URL=$(grep -oP 'ServerName \K[^ ]+' "$SITE_CONF" | head -1)
SITE_DIR=$(grep -oP 'DocumentRoot \K[^ ]+' "$SITE_CONF")

if [ -z "$SITE_DIR" ]; then
  echo "DocumentRoot not found in $SITE_CONF."
  exit 1
fi

# Get user and home directory
SITE_USER=$(stat -c '%U' "$SITE_DIR")
HOME_DIR=$(getent passwd "$SITE_USER" | cut -d: -f6)

if [ -z "$HOME_DIR" ]; then
  echo "Home directory not found for user $SITE_USER."
  exit 1
fi

# Ask for user info
read -p "Enter name for $SITE_USER: " user_name
read -p "Enter email for $SITE_USER: " user_email

# Prepare SSH directory and key paths
SSH_DIR="$HOME_DIR/.ssh"
KEY_NAME="${SITE_URL//./_}_git"
KEY_PRV="$SSH_DIR/$KEY_NAME.prv"
KEY_PUB="$SSH_DIR/$KEY_NAME.pub"

mkdir -p "$SSH_DIR"
chown "$SITE_USER:$SITE_USER" "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Check if key already exists
if [ -f "$KEY_PRV" ] && [ -f "$KEY_PUB" ]; then
  echo "SSH key pair already exists for $SITE_URL."
  echo "1) Replace the key"
  echo "2) Show public key"
  echo "3) Exit"
  read -p "Choose action: " key_action

  case "$key_action" in
    1)
      echo "Replacing existing SSH key pair..."
      rm -f "$KEY_PRV" "$KEY_PUB"
      ;;
    2)
      echo "Public key ($KEY_PUB):"
      cat "$KEY_PUB"
      exit 0
      ;;
    3)
      echo "Exiting."
      exit 0
      ;;
    *)
      echo "Invalid choice. Exiting."
      exit 1
      ;;
  esac
else
  echo "Creating new SSH key pair..."
fi

# Generate key using temporary base name
sudo -u "$SITE_USER" ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/temp_key" -N "" -C "$user_email" > /dev/null

# Rename to final names
mv "$SSH_DIR/temp_key" "$KEY_PRV"
mv "$SSH_DIR/temp_key.pub" "$KEY_PUB"

# Set ownership and permissions
chown "$SITE_USER:$SITE_USER" "$KEY_PRV" "$KEY_PUB"
chmod 600 "$KEY_PRV"
chmod 644 "$KEY_PUB"

# Set up Git config
GIT_CONFIG="$HOME_DIR/.gitconfig"
cat > "$GIT_CONFIG" << EOF
[user]
  name = $user_name
  email = $user_email
[core]
  sshCommand = ssh -i $KEY_PRV -o IdentitiesOnly=yes
EOF

chown "$SITE_USER:$SITE_USER" "$GIT_CONFIG"

echo "SSH key pair and Git config set up for $SITE_USER."
echo "Public key ($KEY_PUB):"
cat "$KEY_PUB"   