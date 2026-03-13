#!/usr/bin/env bash

###############################################################################
# package.sh
#
# Package manager helpers.
#
# These route external commands through command.sh so package operations do not
# accidentally inherit TUI stdin.
###############################################################################

package_install() {
    command_run apt-get install -y "$1"
}

package_remove() {
    command_run apt-get remove -y "$1"
}

package_is_installed() {
    command_run_quiet dpkg -s "$1"
}