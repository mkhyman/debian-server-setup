#!/usr/bin/env bash

###############################################################################
# platform.sh
#
# Platform/environment detection helpers.
#
# Keep this file focused on answering platform questions only.
# Command discovery and command execution belong in command.sh / system.sh.
###############################################################################

platform_is_wsl() {
    if [ -n "${WSL_INTEROP:-}" ] || [ -n "${WSL_DISTRO_NAME:-}" ]; then
        return 0
    fi

    if [ -r /proc/version ] && grep -qi 'microsoft' /proc/version 2>/dev/null; then
        return 0
    fi

    return 1
}

platform_has_systemd() {
    [ -d /run/systemd/system ] || return 1
    command_exists systemctl || return 1
    return 0
}
