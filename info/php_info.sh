#!/usr/bin/env bash

info_render_php() {
    local installed_text
    local default_cli_version_text
    local default_cli_path_text
    local installed_versions_text
    local fpm_services_text
    local pane_text
    local versions
    local version
    local fpm_state
    local first

    if php_is_installed; then
        installed_text="$(format_boolean yes)"

        default_cli_version_text="$(php_get_default_cli_version 2>/dev/null)" || default_cli_version_text=""
        default_cli_path_text="$(php_get_default_cli_path 2>/dev/null)" || default_cli_path_text=""

        [ -n "$default_cli_version_text" ] || default_cli_version_text="N/A"
        [ -n "$default_cli_path_text" ] || default_cli_path_text="N/A"
    else
        installed_text="$(format_boolean no)"
        default_cli_version_text="N/A"
        default_cli_path_text="N/A"
    fi

    default_cli_path_text="$(format_path "$default_cli_path_text")"

    versions="$(php_get_installed_versions 2>/dev/null)" || versions=""
    installed_versions_text="$(format_newline_list "$versions")"

    if [ -n "$versions" ]; then
        fpm_services_text=""
        first=1

        while IFS= read -r version; do
            [ -n "$version" ] || continue

            fpm_state="$(php_get_fpm_state_for_version "$version" 2>/dev/null)" || fpm_state=""
            [ -n "$fpm_state" ] || fpm_state="unknown"
            fpm_state="$(format_service_state "$fpm_state")"

            if [ "$first" -eq 1 ]; then
                fpm_services_text="${version} ${fpm_state}"
                first=0
            else
                fpm_services_text="${fpm_services_text}, ${version} ${fpm_state}"
            fi
        done <<EOF
$versions
EOF

        [ -n "$fpm_services_text" ] || fpm_services_text="N/A"
    else
        fpm_services_text="N/A"
    fi

    pane_text=$(
        printf '%s\n' \
            "PHP installed: ${installed_text}" \
            "Default CLI version: ${default_cli_version_text}" \
            "Default CLI path: ${default_cli_path_text}" \
            "Installed versions: ${installed_versions_text}" \
            "FPM services: ${fpm_services_text}"
    )

    pane_set_content "$PANE_INFO_ID" "$pane_text"
}