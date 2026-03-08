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

# Prompt for MySQL root password (separate)
read -sp "Enter password for MySQL root: " ROOTPASS
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
echo "mysql-server mysql-server/root_password password $ROOTPASS" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $ROOTPASS" | debconf-set-selections

# Install MySQL
apt update
apt install -y mysql-server

# Configure MySQL to allow remote connections
sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

# Restart MySQL
systemctl restart mysql

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

echo "MySQL installed. Remote access enabled for mysqladmin. Root remote access disabled. Root password set."   