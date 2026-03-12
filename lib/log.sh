#!/usr/bin/env bash

###############################################################################
# log.sh
#
# Simple multi-stream logger for the Bash TUI project.
#
# FEATURES
# --------
# - Global master enable switch
# - Per-stream enable switch
# - Per-stream level threshold
# - Per-stream output file
# - Single-line text logs
# - Timestamp + level + message
# - Safe failure behavior:
#     logging failure never writes to terminal and never crashes the app
#
# EXPECTED CONFIG
# ---------------
# Source log_config.sh before using this module.
#
# Required variables:
#   LOG_ENABLED
#
# Per-stream convention:
#   LOG_STREAM_<name>_ENABLED
#   LOG_STREAM_<name>_LEVEL
#   LOG_STREAM_<name>_FILE
#
# LOG LINE FORMAT
# ---------------
#   YYYY-MM-DD HH:MM:SS [LEVEL] message
#
# Example:
#   2026-03-12 21:15:03 [WARN] Missing menu handler: menu_network_on_back
###############################################################################

###############################################################################
# LEVEL HELPERS
###############################################################################

# log_level_value
# ---------------
# Convert a textual log level into a numeric severity value.
#
# Supported levels:
#   info   -> 10
#   notice -> 20
#   warn   -> 30
#   error  -> 40
#
# Higher number means higher severity.
#
# Args:
#   $1 = level name
#
# Output:
#   Prints numeric severity
#
# Return:
#   0 on success
#   1 on invalid level
log_level_value() {
    case "$1" in
        info)   printf '10' ;;
        notice) printf '20' ;;
        warn)   printf '30' ;;
        error)  printf '40' ;;
        *)      return 1 ;;
    esac
}

# log_level_upper
# ---------------
# Convert a textual log level to uppercase display form.
#
# Args:
#   $1 = level name
#
# Output:
#   Prints uppercase level
#
# Return:
#   0 on success
#   1 on invalid level
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

# log_timestamp
# -------------
# Print current timestamp in a human-readable format.
#
# Output:
#   YYYY-MM-DD HH:MM:SS
log_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

###############################################################################
# GLOBAL / STREAM LOOKUP
###############################################################################

# log_is_enabled
# --------------
# Check whether logging is globally enabled.
#
# Return:
#   0 if enabled
#   1 if disabled
log_is_enabled() {
    [[ "${LOG_ENABLED:-1}" == "1" ]]
}

# log_stream_enabled
# ------------------
# Check whether a stream is enabled.
#
# Args:
#   $1 = stream name
#
# Return:
#   0 if enabled
#   1 otherwise
log_stream_enabled() {
    local stream="$1"
    local var_name="LOG_STREAM_${stream}_ENABLED"

    [[ "${!var_name:-0}" == "1" ]]
}

# log_stream_file
# ---------------
# Print the configured destination file for a stream.
#
# Args:
#   $1 = stream name
#
# Output:
#   Prints file path, or empty string if undefined
log_stream_file() {
    local stream="$1"
    local var_name="LOG_STREAM_${stream}_FILE"

    printf '%s' "${!var_name}"
}

# log_stream_level
# ----------------
# Print the configured minimum level for a stream.
#
# Args:
#   $1 = stream name
#
# Output:
#   Prints level name, or empty string if undefined
log_stream_level() {
    local stream="$1"
    local var_name="LOG_STREAM_${stream}_LEVEL"

    printf '%s' "${!var_name}"
}

# log_stream_is_configured
# ------------------------
# Check whether a stream has at least a destination file configured.
#
# Args:
#   $1 = stream name
#
# Return:
#   0 if configured
#   1 otherwise
log_stream_is_configured() {
    local stream="$1"
    local file=""

    file="$(log_stream_file "$stream")"
    [[ -n "$file" ]]
}

###############################################################################
# FILTERING
###############################################################################

# log_should_write
# ----------------
# Decide whether a message should be written to a given stream.
#
# Rules:
# - Global logging must be enabled
# - Stream must be configured
# - Stream must be enabled
# - Message level must be >= stream threshold
#
# Args:
#   $1 = stream name
#   $2 = message level
#
# Return:
#   0 if message should be written
#   1 otherwise
log_should_write() {
    local stream="$1"
    local message_level="$2"
    local configured_level=""
    local message_value=0
    local configured_value=0

    log_is_enabled || return 1
    log_stream_is_configured "$stream" || return 1
    log_stream_enabled "$stream" || return 1

    configured_level="$(log_stream_level "$stream")"
    [[ -n "$configured_level" ]] || return 1

    message_value="$(log_level_value "$message_level")" || return 1
    configured_value="$(log_level_value "$configured_level")" || return 1

    (( message_value >= configured_value ))
}

###############################################################################
# FILE APPEND
###############################################################################

# log_ensure_parent_dir
# ---------------------
# Ensure the parent directory for a log file exists.
#
# Args:
#   $1 = log file path
#
# Return:
#   0 on success
#   1 on failure
log_ensure_parent_dir() {
    local file="$1"
    local dir=""

    dir="${file%/*}"

    # If no slash is present, treat as current directory.
    [[ "$dir" != "$file" ]] || dir="."

    mkdir -p "$dir" 2>/dev/null || return 1
}

# log_append_line
# ---------------
# Append one already-formatted line to a log file.
#
# Args:
#   $1 = file path
#   $2 = full line
#
# Return:
#   0 on success
#   1 on failure
log_append_line() {
    local file="$1"
    local line="$2"

    log_ensure_parent_dir "$file" || return 1
    printf '%s\n' "$line" >> "$file" 2>/dev/null || return 1
}

###############################################################################
# CORE LOGGER
###############################################################################

# log_write
# ---------
# Write a log message to a named stream.
#
# Usage:
#   log_write <stream> <level> <message>
#
# Example:
#   log_write menu warn "Missing ON_BACK handler for NETWORK"
#
# Behavior:
# - If the stream is disabled or below threshold, returns success without write
# - If config is missing or write fails, returns non-zero
# - Never writes to terminal
#
# Args:
#   $1 = stream name
#   $2 = level
#   $3 = message
#
# Return:
#   0 if message was written or intentionally skipped
#   1 if there was a logger/config/write failure
log_write() {
    local stream="$1"
    local level="$2"
    local message="$3"
    local file=""
    local timestamp=""
    local level_upper=""
    local line=""

    # Validate level early.
    log_level_value "$level" >/dev/null || return 1
    level_upper="$(log_level_upper "$level")" || return 1

    # Skipped logging is not an error.
    log_should_write "$stream" "$level" || return 0

    file="$(log_stream_file "$stream")"
    [[ -n "$file" ]] || return 1

    timestamp="$(log_timestamp)"
    line="${timestamp} [${level_upper}] ${message}"

    log_append_line "$file" "$line"
}

###############################################################################
# CONVENIENCE WRAPPERS
###############################################################################

# log_error
# ---------
# Write an error-level message to a stream.
#
# Args:
#   $1 = stream name
#   $2 = message
log_error() {
    local stream="$1"
    local message="$2"

    log_write "$stream" error "$message"
}

# log_warn
# --------
# Write a warn-level message to a stream.
#
# Args:
#   $1 = stream name
#   $2 = message
log_warn() {
    local stream="$1"
    local message="$2"

    log_write "$stream" warn "$message"
}

# log_notice
# ----------
# Write a notice-level message to a stream.
#
# Args:
#   $1 = stream name
#   $2 = message
log_notice() {
    local stream="$1"
    local message="$2"

    log_write "$stream" notice "$message"
}

# log_info
# --------
# Write an info-level message to a stream.
#
# Args:
#   $1 = stream name
#   $2 = message
log_info() {
    local stream="$1"
    local message="$2"

    log_write "$stream" info "$message"
}