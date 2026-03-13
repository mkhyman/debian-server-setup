#!/usr/bin/env bash

###############################################################################
# user_module.sh
#
# User management helpers.
#
# Note:
# This module is still thin. If user management grows, it will likely justify
# dedicated system_user_* helpers in system.sh later.
###############################################################################

user_exists() {
    system_command_run_quiet id "$1"
}

user_get_home_directory() {
    local username="$1"
    local output

    user_exists "$username" || return 1

    output="$(system_command_run_capture getent passwd "$username" 2>/dev/null)" || return 1
    printf '%s\n' "$output" | awk -F: '{print $6}'
}

user_delete() {
    local username="$1"

    if ! user_exists "$username"; then
        return 10
    fi

    system_command_run userdel "$username" || return 20
}