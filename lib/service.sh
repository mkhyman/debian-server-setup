#!/usr/bin/env bash

###############################################################################
# service.sh
#
# Service manager helpers.
#
# These route external commands through command.sh so service operations do not
# accidentally inherit TUI stdin.
###############################################################################

service_start() {
    command_run systemctl start "$1"
}

service_stop() {
    command_run systemctl stop "$1"
}

service_restart() {
    command_run systemctl restart "$1"
}

service_reload() {
    command_run systemctl reload "$1"
}

service_enable() {
    command_run systemctl enable "$1"
}

service_disable() {
    command_run systemctl disable "$1"
}