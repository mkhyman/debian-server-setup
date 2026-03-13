#!/usr/bin/env bash

###############################################################################
# php_module.sh
#
# PHP environment helpers.
#
# Keep query functions small and data-only.
# Rendering/formatting belongs elsewhere.
###############################################################################

php_is_installed() {
    system_command_exists php
}

php_get_version() {
    local output

    php_is_installed || return 1

    output="$(system_command_run_capture php -v 2>/dev/null)" || return 1
    printf '%s\n' "$output" | awk 'NR==1 {print $2}'
}

php_set_ini_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local txn

    txn="$(system_config_begin "$file" "PROFILE_PHP_INI")" || return 1

    system_config_set_kv "$txn" "$key" "$value" || {
        system_config_abort "$txn"
        return 1
    }

    system_config_commit "$txn"
}

php_disable_ini_key() {
    local file="$1"
    local key="$2"
    local txn

    txn="$(system_config_begin "$file" "PROFILE_PHP_INI")" || return 1

    system_config_comment_kv "$txn" "$key" || {
        system_config_abort "$txn"
        return 1
    }

    system_config_commit "$txn"
}