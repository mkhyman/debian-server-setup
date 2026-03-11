#!/bin/bash
set -euo pipefail

read -p "Enter username: " username

if id "$username" &>/dev/null; then
    echo "User '$username' already exists."
    exit 1
fi

# Prompt and confirm password
while true; do
    read -sp "Enter password: " password
    echo
    read -sp "Confirm password: " password_confirm
    echo
    if [ "$password" = "$password_confirm" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

# Create user with home directory and bash shell
sudo useradd -m -s /bin/bash "$username"

# Set the password
echo "$username:$password" | sudo chpasswd

# Add to sudo group
sudo usermod -aG sudo "$username"

echo "User $username created and added to sudo group."   