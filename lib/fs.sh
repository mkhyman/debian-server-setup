#!/usr/bin/env bash

###############################################################################
# fs.sh
#
# Filesystem helpers.
#
# Most state-changing filesystem operations still shell out to external
# commands, so they should go through command.sh for consistency and future
# control points such as dry-run or auditing.
###############################################################################

fs_exists() {
    [ -e "$1" ]
}

fs_is_file() {
    [ -f "$1" ]
}

fs_is_dir() {
    [ -d "$1" ]
}

fs_mkdir() {
    command_run mkdir -p "$1"
}

fs_copy() {
    command_run cp "$1" "$2"
}

fs_move() {
    command_run mv "$1" "$2"
}

fs_remove() {
    command_run rm -f "$1"
}

fs_chmod() {
    command_run chmod "$1" "$2"
}

fs_chown() {
    command_run chown "$1" "$2"
}