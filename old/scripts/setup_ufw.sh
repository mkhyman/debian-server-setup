#!/bin/bash
set -euo pipefail

if [ "$(id -u)" != 0 ]; then
  echo "Please run as root or with sudo."
  exit 1
fi

# Install UFW if missing
if ! command -v ufw &> /dev/null; then
  apt update && apt install -y ufw
fi

# Store results
RESULTS=()

# Allow SSH by default
ufw allow ssh
RESULTS+=("✅ SSH access has been enabled.")

# Function to prompt and collect result
prompt_rule() {
  local service=$1
  local rule=$2
  read -p "Allow $service? (y/n): " choice
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    ufw allow "$rule"
    RESULTS+=("✅ $service access has been enabled.")
  else
    RESULTS+=("❌ $service access has been skipped.")
  fi
}

# Check and prompt for services
systemctl is-active --quiet apache2 && prompt_rule "Apache" "Apache"
systemctl is-active --quiet nginx && prompt_rule "Nginx" "Nginx Full"
systemctl is-active --quiet mysql && prompt_rule "MySQL" "3306"
systemctl is-active --quiet vsftpd && prompt_rule "FTP" "21/tcp"

# Disable UFW logging to console
if [ -f /etc/rsyslog.d/20-ufw.conf ]; then
  sed -i 's/^#& stop/& stop/' /etc/rsyslog.d/20-ufw.conf
  systemctl restart rsyslog
  RESULTS+=("✅ UFW console logging disabled.")
fi

# Enable UFW after rules are set
ufw --force enable
ufw reload

# Show all results at the end
echo
echo "=== Firewall Configuration Summary ==="
for result in "${RESULTS[@]}"; do
  echo "$result"
done
echo "======================================"
echo "Firewall configuration complete."   