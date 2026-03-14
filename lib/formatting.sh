#!/usr/bin/env bash
###############################################################################
# formatting.sh
#
# Shared formatting helpers for panes (info, action, system overview)
###############################################################################

format_boolean() {
    local val="$1"
    case "$val" in
        1|true|yes|enabled) printf 'yes' ;;
        0|false|no|disabled) printf 'no' ;;
        *) printf '%s' "$val" ;;
    esac
}

format_service_state() {
    local state="$1"
    case "$state" in
        running) printf 'running' ;;
        stopped) printf 'stopped' ;;
        not-installed) printf 'not installed' ;;
        unknown) printf 'unknown' ;;
        *) printf '%s' "$state" ;;
    esac
}

format_version_list() {
    local list="$1"
    [ -z "$list" ] && return
    printf '%s\n' "$list" | tr ' ' ', '
}

format_path() {
    local path="$1"
    printf '%s' "$path"
}

format_newline_list() {
    local list="$1"

    [ -n "$list" ] || {
        printf 'N/A'
        return 0
    }

    printf '%s\n' "$list" | paste -sd ', ' -
}