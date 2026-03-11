#!/usr/bin/env bash
# db.sh - Database info (data only, placeholder)

get_db_status() {
    # Just a placeholder, could be MySQL/MariaDB detection
    if command -v mysql >/dev/null 2>&1; then
        echo "installed"
    else
        echo "not installed"
    fi
}

get_db_running() {
    if systemctl is-active --quiet mysql 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

get_db_version() {
    if command -v mysql >/dev/null 2>&1; then
        mysql --version | awk '{print $5}' | sed 's/,//'
    else
        echo "n/a"
    fi
}