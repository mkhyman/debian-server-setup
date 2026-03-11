#!/usr/bin/env bash
# php.sh - PHP info (data only)

get_php_versions() {
    # List all installed PHP binaries
    command -v php >/dev/null 2>&1 && php -v | head -n1 | awk '{print $2}' || echo "none"
}

get_php_fpm_status() {
    if systemctl is-active --quiet php-fpm 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

get_php_cli_status() {
    if command -v php >/dev/null 2>&1; then
        echo "installed"
    else
        echo "not installed"
    fi
}