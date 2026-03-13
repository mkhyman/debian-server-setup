#!/usr/bin/env bash

###############################################################################
# composer_module.sh
#
# Composer environment management.
#
# Query functions:
# - return raw data only
# - no formatting
# - fail quietly
#
# Action functions:
# - return status codes
# - no UI output
###############################################################################

composer_is_installed() {
    system_command_exists composer
}

composer_get_version() {
    local output

    composer_is_installed || return 1

    output="$(system_command_run_capture composer --version 2>/dev/null)" || return 1
    printf '%s\n' "$output" | awk '{print $3}' | sed 's/^v//'
}

composer_get_binary_path() {
    composer_is_installed || return 1
    system_command_get_path composer
}

composer_install() {
    # Return codes:
    # 0  success
    # 10 already installed
    # 20 php missing
    # 21 install failed

    if composer_is_installed; then
        return 10
    fi

    if ! system_command_exists php; then
        return 20
    fi

    system_package_install composer || return 21
    composer_is_installed || return 21

    return 0
}

composer_uninstall() {
    # Return codes:
    # 0  success
    # 11 not installed
    # 22 uninstall failed

    if ! composer_is_installed; then
        return 11
    fi

    system_package_remove composer || return 22

    if composer_is_installed; then
        return 22
    fi

    return 0
}