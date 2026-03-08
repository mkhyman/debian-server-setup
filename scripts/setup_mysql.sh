#!/bin/bash
set -euo pipefail

# Must run as root
if [ "$(id -u)" != 0 ]; then
  echo "Please run as root or with sudo."
  exit 1
fi

# Prompt for mysqladmin password
read -sp "Enter password for mysqladmin: " ADMINPASS
echo
read -sp "Confirm password: " ADMINPASS_CONFIRM
echo

# Validate mysqladmin password
if [ "$ADMINPASS" != "$ADMINPASS_CONFIRM" ]; then
  echo "Passwords do not match."
  exit 1
fi

# Prompt for MariaDB root password (separate)
read -sp "Enter password for MariaDB root: " ROOTPASS
echo
read -sp "Confirm root password: " ROOTPASS_CONFIRM
echo

# Validate root password
if [ "$ROOTPASS" != "$ROOTPASS_CONFIRM" ]; then
  echo "Root passwords do not match."
  exit 1
fi

# Set noninteractive mode
export DEBIAN_FRONTEND=noninteractive

# Pre-seed root password for installation
echo "mariadb-server mariadb/root_password password $ROOTPASS" | debconf-set-selections
echo "mariadb-server mariadb/root_password_again password $ROOTPASS" | debconf-set-selections

# Install MariaDB
apt update
apt install -y mariadb-server

# Configure MariaDB to allow remote connections
sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf

# Restart MariaDB
systemctl restart mariadb

# Create mysqladmin user with remote access
mysql -u root -p"$ROOTPASS" <<MYSQL_SCRIPT
CREATE USER 'mysqladmin'@'%' IDENTIFIED BY '$ADMINPASS';
GRANT ALL PRIVILEGES ON *.* TO 'mysqladmin'@'%' WITH GRANT OPTION;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOTPASS';
UPDATE mysql.user SET host='localhost' WHERE user='root' AND host='%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Allow port 3306 in firewall
ufw allow 3306 2>/dev/null || echo "UFW not installed, skipping firewall setup."

echo "MariaDB installed. Remote access enabled for mysqladmin. Root remote access disabled. Root password set."   
