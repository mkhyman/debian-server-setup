#!/usr/bin/env bash

###############################################################################
# core.sh
#
# Core system-level application lifecycle helpers.
#
# PURPOSE
# -------
# Keep main entrypoint small by moving:
# - terminal initialization
# - cleanup
# - quit handling
# - signal/exit traps
#
# DESIGN
# ------
# - No direct application logic lives here.
# - This file manages terminal/session lifecycle only.
# - Cleanup is safe to call multiple times.
###############################################################################

# 1 once initialized, 0 before init / after cleanup
SYSTEM_INITIALIZED=0

# core_cleanup
# --------------
# Restore terminal state and leave alternate screen.
#
# Safe to call multiple times.
core_cleanup() {
    if [[ "${SYSTEM_INITIALIZED:-0}" != "1" ]]; then
        return 0
    fi

    stty sane 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    clear 2>/dev/null || true

    SYSTEM_INITIALIZED=0
}

# core_init
# -----------
# Enter alternate screen and configure terminal for TUI mode.
core_init() {
    tput smcup || return 1
    tput civis || return 1
    stty -echo || return 1
    tput clear || return 1

    SYSTEM_INITIALIZED=1
    return 0
}

# core_install_traps
# --------------------
# Install cleanup trap for normal exit and common termination signals.
core_install_traps() {
    trap core_cleanup EXIT INT TERM HUP
}

# quit_application
# ----------------
# Graceful application exit helper.
quit_application() {
    exit 0
}