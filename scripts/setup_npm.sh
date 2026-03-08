#!/bin/bash
set -euo pipefail

if [ "$(id -u)" != 0 ]; then
  echo "Run as root or with sudo."
  exit 1
fi

# Install nvm if not present
if ! command -v nvm &> /dev/null; then
  echo "nvm not found. Installing nvm..."
  export NVM_DIR="$HOME/.nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  echo "nvm installed."
fi

# Ensure nvm is available in current session
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Show installed Node.js versions
echo "Installed Node.js versions:"
nvm ls
echo

echo "Choose action:"
echo "1. Install Node.js version"
echo "2. Set site Node.js version"
echo "x. Exit"
read -p "Enter choice: " action

case "$action" in
  1)
    read -p "Enter Node.js version to install (e.g. 18): " version
    nvm install "$version"
    echo "Node.js $version installed."
    ;;
  2)
    # List sites from *-ssl.conf files
    SSL_CONF_FILES=($(find /etc/apache2/sites-available -name "*-ssl.conf" 2>/dev/null))
    if [ ${#SSL_CONF_FILES[@]} -eq 0 ]; then
      echo "No sites found."
      exit 1
    fi

    echo "Available sites:"
    for i in "${!SSL_CONF_FILES[@]}"; do
      server_name=$(grep -oP 'ServerName \K[^ ]+' "${SSL_CONF_FILES[$i]}" | head -1)
      echo "$((i+1))) $server_name"
    done

    read -p "Select site: " choice
    index=$((choice-1))
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

    SITE_USER=$(stat -c '%U' "$SITE_DIR")
    HOME_DIR=$(getent passwd "$SITE_USER" | cut -d: -f6)
    NVMRC="$HOME_DIR/.nvmrc"

    read -p "Enter Node.js version for $SITE_URL: " version

    # Write .nvmrc
    echo "$version" > "$NVMRC"
    chown "$SITE_USER:$SITE_USER" "$NVMRC"

    # Add auto-use to .bashrc only if not already present
    BASHRC="$HOME_DIR/.bashrc"
    if ! grep -q "_nvmrc_auto_use" "$BASHRC"; then
      cat >> "$BASHRC" << 'EOF'

# Auto-switch Node.js version via .nvmrc
_nvmrc_auto_use() {
  local nvmrc_path=$(nvm_find_up .nvmrc)
  if [ -n "$nvmrc_path" ]; then
    nvm use
  elif [ "$(nvm current)" != "$(nvm version default)" ]; then
    nvm use default
  fi
}
PROMPT_COMMAND="_nvmrc_auto_use${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
EOF
      chown "$SITE_USER:$SITE_USER" "$BASHRC"
      echo "Auto-use configured in $BASHRC."
    else
      echo "Auto-use already configured in $BASHRC."
    fi

    echo "Site $SITE_URL set to Node.js $version."
    ;;
  x)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid choice."
    ;;
esac   