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

###############################################################################
# CLEANUP
###############################################################################

core_cleanup() {
    if [[ "${CORE_INITIALIZED:-0}" != "1" ]]; then
        return 0
    fi

    log_notice core "Cleaning up terminal state"

    stty sane 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    clear 2>/dev/null || true

    CORE_INITIALIZED=0
}

###############################################################################
# TERMINAL INIT
###############################################################################

core_init_terminal() {
    tput smcup || return 1
    tput civis || return 1
    stty -echo || return 1
    tput clear || return 1

    CORE_INITIALIZED=1
    return 0
}

###############################################################################
# TRAPS
###############################################################################

core_install_traps() {
    trap core_cleanup EXIT INT TERM HUP
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