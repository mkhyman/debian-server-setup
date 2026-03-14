#!/usr/bin/env bash

###############################################################################
# php_module.sh
#
# PHP environment management.
#
# DESIGN
# ------
# - Support multiple concurrently installed PHP versions.
# - Keep query functions data-only.
# - Keep UI rendering/formatting out of this module.
# - Route all external interaction through system.sh.
#
# EXPECTED APP CONFIG
# -------------------
# app_config.sh should define:
#
#   PHP_DEFAULT_MODULES=(cli common fpm curl mbstring xml zip)
#
# Notes:
# - Modules are package suffixes, not full package names.
# - Packages are built as php<version>-<module>, for example:
#     php8.2-cli
#     php8.2-fpm
#     php8.2-curl
#
# RETURN CODES
# ------------
# php_install_version():
#   0  success
#   10 invalid version
#   11 already installed
#   12 no package list
#   13 install failed
#
# php_uninstall_version():
#   0  success
#   10 invalid version
#   21 not installed
#   22 uninstall failed
###############################################################################

php_is_installed() {
    system_command_exists php
}

php_get_version() {
    php_get_default_cli_version
}

php_normalize_version() {
    local version="$1"

    if [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        printf '%s' "$version"
        return 0
    fi

    return 1
}

php_get_binary_name_for_version() {
    local version="$1"

    version="$(php_normalize_version "$version")" || return 1
    printf 'php%s' "$version"
}

php_get_binary_path_for_version() {
    local version="$1"
    local binary_name

    binary_name="$(php_get_binary_name_for_version "$version")" || return 1
    system_command_get_path "$binary_name"
}

php_get_cli_version_for_version() {
    local version="$1"
    local binary_path

    binary_path="$(php_get_binary_path_for_version "$version")" || return 1
    system_command_run_capture "$binary_path" -r 'echo PHP_VERSION;'
}

php_is_version_installed() {
    local version="$1"
    local package_name

    version="$(php_normalize_version "$version")" || return 1
    package_name="php${version}-cli"

    system_package_is_installed "$package_name"
}

php_get_installed_versions() {
    local output
    local versions

    output="$(system_command_run_capture dpkg -l 2>/dev/null)" || return 1

    versions="$(
        printf '%s\n' "$output" \
        | awk '
            $1 == "ii" && $2 ~ /^php[0-9]+\.[0-9]+-cli$/ {
                pkg = $2
                sub(/^php/, "", pkg)
                sub(/-cli$/, "", pkg)
                print pkg
            }
        ' \
        | sort -u
    )"

    [ -n "$versions" ] || return 1

    printf '%s\n' "$versions"
}

php_get_default_cli_path() {
    php_is_installed || return 1
    system_command_get_path php
}

php_get_default_cli_version() {
    php_is_installed || return 1
    system_command_run_capture php -r 'echo PHP_VERSION;'
}

php_get_default_cli_major_minor() {
    local version

    version="$(php_get_default_cli_version)" || return 1
    printf '%s' "$version" | awk -F. '{print $1 "." $2}'
}

php_default_cli_matches_version() {
    local version="$1"
    local default_version
    local default_major_minor

    version="$(php_normalize_version "$version")" || return 1
    default_version="$(php_get_default_cli_version)" || return 1

    default_major_minor="$(printf '%s' "$default_version" | awk -F. '{print $1 "." $2}')"

    [ "$default_major_minor" = "$version" ]
}

php_get_fpm_service_name_for_version() {
    local version="$1"

    version="$(php_normalize_version "$version")" || return 1
    printf 'php%s-fpm' "$version"
}

php_is_fpm_installed_for_version() {
    local version="$1"
    local package_name

    version="$(php_normalize_version "$version")" || return 1
    package_name="php${version}-fpm"

    system_package_is_installed "$package_name"
}

php_is_fpm_running_for_version() {
    local version="$1"
    local service_name

    php_is_fpm_installed_for_version "$version" || return 1

    if platform_is_wsl; then
        system_command_run_quiet pgrep -f "php${version}-fpm"
        return $?
    fi

    service_name="$(php_get_fpm_service_name_for_version "$version")" || return 1
    system_service_is_active "$service_name"
}

php_get_fpm_state_for_version() {
    local version="$1"
    local service_name

    if ! php_is_fpm_installed_for_version "$version"; then
        printf 'not-installed'
        return 0
    fi

    if php_is_fpm_running_for_version "$version"; then
        printf 'running'
        return 0
    fi

    if platform_is_wsl; then
        printf 'stopped'
        return 0
    fi

    service_name="$(php_get_fpm_service_name_for_version "$version")" || return 1

    if system_has_service "$service_name"; then
        printf 'stopped'
        return 0
    fi

    printf 'not-installed'
    return 0
}

_php_get_default_modules() {
    local modules=()

    if [ -n "${PHP_DEFAULT_MODULES+set}" ]; then
        modules=( "${PHP_DEFAULT_MODULES[@]}" )
    else
        modules=( cli )
    fi

    printf '%s\n' "${modules[@]}"
}

_php_build_package_list_for_version() {
    local version="$1"
    local module
    local packages=()
    local have_cli=0

    version="$(php_normalize_version "$version")" || return 1

    while IFS= read -r module; do
        [ -n "$module" ] || continue

        packages+=( "php${version}-${module}" )

        if [ "$module" = "cli" ]; then
            have_cli=1
        fi
    done <<EOF
$(_php_get_default_modules)
EOF

    if [ "$have_cli" -eq 0 ]; then
        packages+=( "php${version}-cli" )
    fi

    [ "${#packages[@]}" -gt 0 ] || return 1

    printf '%s\n' "${packages[@]}"
}

php_install_version() {
    local version="$1"
    local package_name
    local installed_any=0

    version="$(php_normalize_version "$version")" || return 10

    if php_is_version_installed "$version"; then
        return 11
    fi

    while IFS= read -r package_name; do
        [ -n "$package_name" ] || continue
        installed_any=1

        system_package_install "$package_name" || return 13
    done <<EOF
$(_php_build_package_list_for_version "$version")
EOF

    [ "$installed_any" -eq 1 ] || return 12
    php_is_version_installed "$version" || return 13

    return 0
}

php_uninstall_version() {
    local version="$1"
    local package_name
    local removed_any=0

    version="$(php_normalize_version "$version")" || return 10

    if ! php_is_version_installed "$version"; then
        return 21
    fi

    while IFS= read -r package_name; do
        [ -n "$package_name" ] || continue

        if system_package_is_installed "$package_name"; then
            removed_any=1
            system_package_remove "$package_name" || return 22
        fi
    done <<EOF
$(_php_build_package_list_for_version "$version")
EOF

    package_name="php${version}-cli"
    if system_package_is_installed "$package_name"; then
        removed_any=1
        system_package_remove "$package_name" || return 22
    fi

    [ "$removed_any" -eq 1 ] || return 22

    if php_is_version_installed "$version"; then
        return 22
    fi

    return 0
}