#!/usr/bin/env bash
# ssh.sh - SSH service info (data only, no display)

get_ssh_status() {
    if systemctl is-active --quiet ssh 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

get_ssh_client_installed() {
    if command -v ssh >/dev/null 2>&1; then
        echo "installed"
    else
        echo "not installed"
    fi
}

get_sftp_status() {
    local client
    client=$(get_ssh_client_installed)
    if [[ "$client" == "installed" ]]; then
        if grep -q "^Subsystem\s\+sftp" /etc/ssh/sshd_config 2>/dev/null; then
            echo "enabled"
        else
            echo "disabled"
        fi
    else
        echo "n/a"
    fi
}