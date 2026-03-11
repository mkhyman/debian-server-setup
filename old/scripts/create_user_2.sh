#!/bin/bash
set -euo pipefail

# Check if the script is run as root
if [ "$(id -u)" != 0 ]; then
  echo "Run as root or with sudo."
  exit 1
fi

echo "=== User Creation Script ==="
echo

# Prompt for username
read -p "Enter username: " USERNAME

# Validate username is not empty
if [[ -z "$USERNAME" ]]; then
    echo "Username cannot be empty."
    exit 1
fi

# Check if user already exists
if id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' already exists."
    exit 1
fi

# Prompt for password (hidden input)
read -s -p "Enter password: " PASSWORD
echo

# Validate password is not empty
if [[ -z "$PASSWORD" ]]; then
    echo "Password cannot be empty."
    exit 1
fi

# Prompt for password confirmation
read -s -p "Confirm password: " PASSWORD_CONFIRM
echo

# Check if passwords match
if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
    echo "Passwords do not match."
    exit 1
fi

# Prompt for default shell
echo
echo "Select default shell:"
echo "1) bash"
echo "2) zsh"
read -p "Enter choice (1 or 2) [default: 1]: " SHELL_CHOICE
SHELL_CHOICE=${SHELL_CHOICE:-1}

case $SHELL_CHOICE in
    1) DEFAULT_SHELL="/bin/bash" ;;
    2) DEFAULT_SHELL="/bin/zsh" ;;
    *) echo "Invalid choice. Using bash as default."; DEFAULT_SHELL="/bin/bash" ;;
esac

# Prompt for password login
echo
read -p "Allow password login? (y/n) [default: y]: " PASSWORD_LOGIN
PASSWORD_LOGIN=${PASSWORD_LOGIN:-y}

# Prompt for SSH access
echo
read -p "Setup SSH access? (y/n) [default: n]: " SSH_ACCESS
SSH_ACCESS=${SSH_ACCESS:-n}

if [[ $SSH_ACCESS == "y" ]]; then
	
fi

# Prompt for SFTP access
echo
read -p "Setup SFTP access? (y/n) [default: n]: " SFTP_ACCESS
SFTP_ACCESS=${SFTP_ACCESS:-n}

# Display summary
echo
echo "=== Summary ==="
echo "Username: $USERNAME"
echo "Default Shell: $DEFAULT_SHELL"
echo "Password Login: $PASSWORD_LOGIN"
echo "SSH Access: $SSH_ACCESS"
echo "SFTP Access: $SFTP_ACCESS"
echo

# Confirm before creating
read -p "Proceed with user creation? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "User creation cancelled."
    exit 0
fi

# Create the user with specified shell
useradd -m -s "$DEFAULT_SHELL" "$USERNAME"

if [[ $? -ne 0 ]]; then
    echo "Failed to create user '$USERNAME'."
    exit 1
fi

# Set the password
echo "$USERNAME:$PASSWORD" | chpasswd

# Handle password login setting
if [[ "$PASSWORD_LOGIN" == "n" || "$PASSWORD_LOGIN" == "N" ]]; then
    # Disable password login by locking the account
    passwd -l "$USERNAME" &>/dev/null
    echo "Password login disabled for '$USERNAME'."
fi

# Handle SSH access setup
if [[ "$SSH_ACCESS" == "y" || "$SSH_ACCESS" == "Y" ]]; then
    mkdir -p /home/"$USERNAME"/.ssh
    chmod 700 /home/"$USERNAME"/.ssh
    touch /home/"$USERNAME"/.ssh/authorized_keys
    chmod 600 /home/"$USERNAME"/.ssh/authorized_keys
    chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.ssh
    echo "SSH access configured for '$USERNAME'. Add public keys to ~/.ssh/authorized_keys"
fi

# Handle SFTP access setup
if [[ "$SFTP_ACCESS" == "y" || "$SFTP_ACCESS" == "Y" ]]; then
    # Create an SFTP-only user group if it doesn't exist
    groupadd sftponly 2>/dev/null
    usermod -a -G sftponly "$USERNAME"
    echo "SFTP access configured for '$USERNAME'."
    echo "Note: Configure sshd_config to restrict this user to SFTP only if needed."
fi

echo
echo "User '$USERNAME' created successfully!"