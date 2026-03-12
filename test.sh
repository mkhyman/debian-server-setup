#!/usr/bin/env bash

###############################################################################
# main.sh
#
# Main entrypoint for the Bash TUI application.
#
# RESPONSIBILITIES
# ----------------
# - source configuration and libraries
# - source menu and workflow definitions
# - start core runtime
# - initialize panes and menu system
# - run the main input loop
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# CONFIGURATION
###############################################################################

source "$SCRIPT_DIR/config/log_config.sh"

###############################################################################
# LIBRARIES
###############################################################################

source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/tui_panes.sh"
source "$SCRIPT_DIR/lib/tui_input.sh"
source "$SCRIPT_DIR/lib/tui_menu.sh"
source "$SCRIPT_DIR/lib/workflow.sh"

###############################################################################
# WORKFLOWS
###############################################################################

# Source workflow definitions here.
# Example:
# source workflows/user_delete.sh
# source workflows/application_manage.sh

###############################################################################
# MENUS
###############################################################################

source "$SCRIPT_DIR/menu/main_menu.sh"
source "$SCRIPT_DIR/menu/user_menu.sh"
source "$SCRIPT_DIR/menu/application_menu.sh"

###############################################################################
# STARTUP
###############################################################################

core_startup || exit 1

setup_panes
pane_draw_all
menu_init "MAIN"

###############################################################################
# MAIN LOOP
###############################################################################

log_notice core "Main loop starting"
while true; do
    key="$(read_key)" || break

    case "$INPUT_MODE" in
        normal)
            handle_normal_key "$key"
            ;;
        prompt)
            handle_prompt_key "$key"
            ;;
        choice)
            handle_choice_key "$key"
            ;;
    esac
done
log_notice core "Main loop terminated"

exit 0