#!/usr/bin/env bash

###############################################################################
# command.sh
#
# PURPOSE
# -------
# Centralized command execution helpers.
#
# WHY THIS EXISTS
# ---------------
# In a TUI, child processes inherit the application's stdin/stdout/stderr
# unless we deliberately control them.
#
# That can cause subtle bugs:
# - a command may accidentally read from the keyboard input stream
# - a command may write directly into the UI
# - the program may appear to "wait for Enter" when in fact a child process
#   is consuming terminal input
#
# DESIGN RULE
# -----------
# External commands should not inherit TUI stdin by accident.
#
# Therefore, these helpers detach stdin from the terminal by default using:
#   </dev/null
#
# WHICH HELPER TO USE
# -------------------
# command_run
#   Use for normal operational commands where side effects matter.
#   Example: package installs, service actions, file operations via commands.
#
# command_run_capture
#   Use when stdout is the data you want to consume programmatically.
#   Example: "composer --version", "php -v", "git --version".
#
# command_run_quiet
#   Use when you only care about success/failure and want no terminal output.
#   Example: probe-style checks or best-effort helper commands.
#
# IMPORTANT
# ---------
# - These helpers detach stdin from the TUI by default.
# - They do NOT format output and do NOT implement UI behavior.
# - Query-style commands should normally use command_run_capture or
#   command_run_quiet, not command_run.
###############################################################################

command_run() {
    "$@" </dev/null
}

command_run_capture() {
    "$@" </dev/null
}

command_run_quiet() {
    "$@" </dev/null >/dev/null 2>&1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

command_get_path() {
    command -v "$1" 2>/dev/null
}