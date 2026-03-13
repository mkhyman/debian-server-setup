#!/usr/bin/env bash

info_render_composer() {
    local installed_text
    local version_text
    local path_text
    local pane_text

    if composer_is_installed; then
        installed_text="Installed"

        version_text="$(composer_get_version 2>/dev/null)" || version_text=""
        path_text="$(composer_get_binary_path 2>/dev/null)" || path_text=""

        [ -n "$version_text" ] || version_text="N/A"
        [ -n "$path_text" ] || path_text="N/A"
    else
        installed_text="Not Installed"
        version_text="N/A"
        path_text="N/A"
    fi

    pane_text=$(
        printf '%s\n' \
            "Composer: ${installed_text}" \
            "Composer version: ${version_text}" \
            "Composer executable path: ${path_text}"
    )

    pane_set_content "$PANE_INFO_ID" "$pane_text"
}