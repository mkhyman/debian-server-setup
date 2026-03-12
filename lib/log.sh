#!/usr/bin/env bash

###############################################################################
# log.sh
#
# Multi-stream logging module.
#
# FEATURES
# --------
# - Global enable switch
# - Per-stream enable switch
# - Per-stream severity threshold
# - Per-stream output file
# - Timestamped single-line log entries
# - Startup validation via log_init
# - Explicit stream registry via LOG_STREAM_NAMES
#
# COMPATIBILITY
# -------------
# Written to stay friendly with older Bash versions, including Bash 3.
# Avoids dynamic variable discovery via compgen/grep.
#
# CONFIGURATION
# -------------
# config/log_config.sh must be sourced before this module.
#
# LOG FORMAT
# ----------
#   YYYY-MM-DD HH:MM:SS [LEVEL] message
###############################################################################

###############################################################################
# LEVEL HELPERS
###############################################################################

log_level_value() {
    case "$1" in
        info)   printf '10' ;;
        notice) printf '20' ;;
        warn)   printf '30' ;;
        error)  printf '40' ;;
        *)      return 1 ;;
    esac
}

log_level_upper() {
    case "$1" in
        info)   printf 'INFO' ;;
        notice) printf 'NOTICE' ;;
        warn)   printf 'WARN' ;;
        error)  printf 'ERROR' ;;
        *)      return 1 ;;
    esac
}

###############################################################################
# TIMESTAMP
###############################################################################

log_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

###############################################################################
# GLOBAL / STREAM LOOKUP
###############################################################################

log_is_enabled() {
    [[ "${LOG_ENABLED:-1}" == "1" ]]
}

log_stream_enabled() {
    local stream="$1"
    local var="LOG_STREAM_${stream}_ENABLED"

    [[ "${!var:-0}" == "1" ]]
}

log_stream_file() {
    local stream="$1"
    local var="LOG_STREAM_${stream}_FILE"

    printf '%s' "${!var}"
}

log_stream_level() {
    local stream="$1"
    local var="LOG_STREAM_${stream}_LEVEL"

    printf '%s' "${!var}"
}

log_stream_is_configured() {
    local stream="$1"
    local file

    file="$(log_stream_file "$stream")"
    [[ -n "$file" ]]
}

log_stream_known() {
    local stream="$1"
    local known

    for known in "${LOG_STREAM_NAMES[@]}"; do
        [[ "$known" == "$stream" ]] && return 0
    done

    return 1
}

###############################################################################
# PATH VALIDATION
###############################################################################

log_parent_dir() {
    local file="$1"
    local dir

    dir="${file%/*}"
    [[ "$dir" != "$file" ]] || dir="."

    printf '%s' "$dir"
}

log_ensure_parent_dir() {
    local file="$1"
    local dir

    dir="$(log_parent_dir "$file")"

    mkdir -p "$dir" 2>/dev/null || return 1
}

log_validate_stream_file() {
    local stream="$1"
    local file
    local dir

    file="$(log_stream_file "$stream")"
    [[ -n "$file" ]] || return 1

    log_ensure_parent_dir "$file" || return 1

    dir="$(log_parent_dir "$file")"

    [[ -d "$dir" ]] || return 1
    [[ -w "$dir" ]] || return 1

    if [[ -e "$file" ]]; then
        [[ -f "$file" ]] || return 1
        [[ -w "$file" ]] || return 1
    fi

    return 0
}

###############################################################################
# STARTUP VALIDATION
###############################################################################

log_init() {
    local stream

    log_is_enabled || return 0

    for stream in "${LOG_STREAM_NAMES[@]}"; do
        log_stream_enabled "$stream" || continue
        log_stream_is_configured "$stream" || return 1
        log_validate_stream_file "$stream" || return 1
    done

    return 0
}

###############################################################################
# FILTERING
###############################################################################

log_should_write() {
    local stream="$1"
    local level="$2"

    local configured
    local msg_value
    local cfg_value

    log_is_enabled || return 1
    log_stream_known "$stream" || return 1
    log_stream_enabled "$stream" || return 1
    log_stream_is_configured "$stream" || return 1

    configured="$(log_stream_level "$stream")"
    [[ -n "$configured" ]] || return 1

    msg_value="$(log_level_value "$level")" || return 1
    cfg_value="$(log_level_value "$configured")" || return 1

    (( msg_value >= cfg_value ))
}

###############################################################################
# FILE APPEND
###############################################################################

log_append_line() {
    local file="$1"
    local line="$2"

    printf '%s\n' "$line" >> "$file" 2>/dev/null || return 1
}

###############################################################################
# CORE LOGGER
###############################################################################

log_write() {
    local stream="$1"
    local level="$2"
    local message="$3"

    local file
    local ts
    local level_upper
    local line

    log_level_value "$level" >/dev/null || return 1
    log_stream_known "$stream" || return 1

    log_should_write "$stream" "$level" || return 0

    file="$(log_stream_file "$stream")"
    [[ -n "$file" ]] || return 1

    level_upper="$(log_level_upper "$level")" || return 1
    ts="$(log_timestamp)"

    line="${ts} [${level_upper}] ${message}"

    log_append_line "$file" "$line"
}

###############################################################################
# CONVENIENCE WRAPPERS
###############################################################################

log_error() {
    log_write "$1" error "$2"
}

log_warn() {
    log_write "$1" warn "$2"
}

log_notice() {
    log_write "$1" notice "$2"
}

log_info() {
    log_write "$1" info "$2"
}