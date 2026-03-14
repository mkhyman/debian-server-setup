#!/usr/bin/env bash

###############################################################################
# core.sh
#
# Core application lifecycle helpers.
#
# PURPOSE
# -------
# Manages application startup and shutdown:
#   - terminal setup
#   - signal traps
#   - cleanup
#   - logging initialization
###############################################################################

CORE_INITIALIZED=0
CORE_STTY_STATE=""

###############################################################################
# CLEANUP
###############################################################################

core_cleanup() {
    if [[ "${CORE_INITIALIZED:-0}" != "1" ]]; then
        return 0
    fi

    log_notice core "Cleaning up terminal state"

    if [[ -n "${CORE_STTY_STATE:-}" ]]; then
        stty "$CORE_STTY_STATE" 2>/dev/null || stty sane 2>/dev/null || true
    else
        stty sane 2>/dev/null || true
    fi

    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    clear 2>/dev/null || true

    CORE_INITIALIZED=0
    CORE_STTY_STATE=""
}

###############################################################################
# TERMINAL INIT
###############################################################################

core_init_terminal() {
    core_log_tty_state "before_init"

    CORE_STTY_STATE="$(stty -g)" || return 1

    tput smcup || return 1
    tput civis || return 1
    stty -icanon -echo min 1 time 0 || return 1
    tput clear || return 1

    core_log_tty_state "after_init"

    CORE_INITIALIZED=1
    return 0
}

###############################################################################
# TRAPS
###############################################################################

core_install_traps() {
    trap 'core_cleanup' EXIT
    trap 'core_cleanup; exit 130' INT TERM HUP
}

###############################################################################
# EXIT
###############################################################################

core_exit() {
    local status="${1:-0}"
    log_notice core "Application exiting (status=${status})"
    exit "$status"
}

quit_application() {
    log_notice core "Quit requested"
    core_exit 0
}

###############################################################################
# STARTUP
###############################################################################

core_startup() {
    core_require_root || return 1
    core_require_tty || return 1

    core_install_traps

    core_init_terminal || return 1

    if ! log_init; then
        core_cleanup
        printf '%s\n' \
            'Unable to start: logging could not be initialized. Check config/log_config.sh.'
        return 1
    fi

    log_notice core "Application startup complete"

    return 0
}

core_require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        printf '%s\n' "This application must be run as root." >&2
        return 1
    fi

    return 0
}

###############################################################################
# HELPERS
###############################################################################

core_log_tty_state() {
    local label="$1"
    local tty_state

    tty_state="$(stty -a 2>/dev/null)" || tty_state="<stty failed>"
}

core_require_tty() {
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        printf '%s
' 'This application requires an interactive terminal.' >&2
        return 1
    fi

    return 0
}
