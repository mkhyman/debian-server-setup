#!/usr/bin/env bash
# user.sh - user info (data only)

get_all_users() {
    cut -d: -f1 /etc/passwd
}

get_user_uid() {
    local user="$1"
    id -u "$user" 2>/dev/null || echo "n/a"
}

get_user_groups() {
    local user="$1"
    id -Gn "$user" 2>/dev/null || echo "n/a"
}

get_user_home() {
    local user="$1"
    eval echo "~$user" 2>/dev/null || echo "n/a"
}