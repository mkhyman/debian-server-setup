#!/bin/bash
set -euo pipefail

read -p "Enter username: " username

if ! id "$username" &>/dev/null; then
    echo "User '$username' does not exist."
    exit 1
fi

# Disable password authentication
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# SSH key setup
read -p "Do you want to (1) enter a public key or (2) generate a new key pair? " choice

if [ "$choice" = "2" ]; then
    # Generate key pair
    sudo -u "$username" ssh-keygen -t rsa -b 4096 -f "/home/$username/.ssh/id_rsa" -N "" -C "$username@localhost"
    echo "Private key:"
    cat "/home/$username/.ssh/id_rsa"
    # Move public key to authorized_keys
    sudo mv "/home/$username/.ssh/id_rsa.pub" "/home/$username/.ssh/authorized_keys"
else
    read -p "Enter public key: " pubkey
    # Append only if key does not already exist
    grep -q -F "$pubkey" "/home/$username/.ssh/authorized_keys" 2>/dev/null || echo "$pubkey" | sudo tee -a "/home/$username/.ssh/authorized_keys" > /dev/null
fi

# Set permissions
sudo chown -R "$username:$username" "/home/$username/.ssh"
sudo chmod 700 "/home/$username/.ssh"
sudo chmod 600 "/home/$username/.ssh/authorized_keys"

# Restart SSH
sudo systemctl restart ssh

echo "SSH key configured and password authentication disabled."   