#!/usr/bin/env bash
###############################################################################
# php_workflow.sh
#
# PHP workflows, linked from php_menu.sh
# Mirrors the structure of composer_workflow.sh
###############################################################################

# Workflow: install PHP version
wf_php_install() {
    local version
    local result

    # Prompt user for version
    version="$(prompt_input "Enter PHP version to install (e.g., 8.2):")" || return 1
    version="$(php_normalize_version "$version")" || {
        echo "Invalid version entered"
        return 1
    }

    # Check if version is already installed
    if php_is_version_installed "$version"; then
        echo "PHP version $version is already installed."
        return 0
    fi

    # Build package list (uses default modules from app_config.sh)
    local packages
    packages="$(_php_build_package_list_for_version "$version")" || {
        echo "Failed to build package list for PHP $version"
        return 1
    }

    echo "Installing PHP $version and default modules: $packages..."
    result=0
    while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        system_package_install "$pkg" || result=1
    done <<EOF
$packages
EOF

    if [ "$result" -eq 0 ]; then
        echo "PHP $version installed successfully."
    else
        echo "Errors occurred during installation of PHP $version."
    fi

    info_render_php
    return $result
}

# Workflow: uninstall PHP version
wf_php_uninstall() {
    local version
    local result

    version="$(prompt_input "Enter PHP version to uninstall (e.g., 8.2):")" || return 1
    version="$(php_normalize_version "$version")" || {
        echo "Invalid version entered"
        return 1
    }

    if ! php_is_version_installed "$version"; then
        echo "PHP version $version is not installed."
        return 0
    fi

    local packages
    packages="$(_php_build_package_list_for_version "$version")"

    echo "Uninstalling PHP $version and default modules: $packages..."
    result=0
    while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        system_package_remove "$pkg" || result=1
    done <<EOF
$packages
EOF

    # Always remove versioned CLI package to be sure
    local cli_pkg="php${version}-cli"
    if system_package_is_installed "$cli_pkg"; then
        system_package_remove "$cli_pkg" || result=1
    fi

    if [ "$result" -eq 0 ]; then
        echo "PHP $version uninstalled successfully."
    else
        echo "Errors occurred during uninstallation of PHP $version."
    fi

    info_render_php
    return $result
}

# Workflow: select default CLI version
wf_php_select_default_cli() {
    local version
    local path
    local versions
    local valid=0

    versions="$(php_get_installed_versions 2>/dev/null | tr '\n' ' ')" || {
        echo "No PHP versions installed."
        return 1
    }

    echo "Installed PHP versions: $versions"
    version="$(prompt_input "Enter PHP version to set as default CLI:")" || return 1
    version="$(php_normalize_version "$version")" || {
        echo "Invalid version entered"
        return 1
    }

    if ! php_is_version_installed "$version"; then
        echo "PHP version $version is not installed."
        return 1
    fi

    # Use update-alternatives to set default CLI
    path="$(php_get_binary_path_for_version "$version")" || {
        echo "Failed to determine binary path for PHP $version"
        return 1
    }

    echo "Setting PHP $version as default CLI..."
    system_run "update-alternatives --install /usr/bin/php php $path 100"
    system_run "update-alternatives --set php $path"

    echo "PHP $version set as default CLI."
    info_render_php
    return 0
}