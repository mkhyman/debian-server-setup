#!/usr/bin/env bash

###############################################################################
# service.sh
#
# Service helpers.
#
# Runtime service control is routed through command.sh so child processes do not
# accidentally inherit TUI stdin.
#
# NOTE:
# Boot-time enable/disable is intentionally not implemented yet.
# Runtime service control (`start`, `stop`, `restart`, `reload`) is handled
# through `service`, but startup-policy control is a separate concern.
#
# On Debian-family systems this may eventually use tools such as `update-rc.d`
# (or an equivalent abstraction through the system layer), but we are deferring
# implementation until the project needs consistent boot-time service policy.
###############################################################################

service_start() {
    command_run service "$1" start
}

service_stop() {
    command_run service "$1" stop
}

service_restart() {
    command_run service "$1" restart
}

service_reload() {
    command_run service "$1" reload
}

service_enable() {
    # Deferred:
    # Enabling a service at boot is not the same as starting it now.
    # This will likely need Debian-family startup-policy handling
    # (for example `update-rc.d`) once implemented.
    return 1
}

service_disable() {
    # Deferred:
    # Disabling a service at boot is not the same as stopping it now.
    # This will likely need Debian-family startup-policy handling
    # (for example `update-rc.d`) once implemented.
    return 1
}
