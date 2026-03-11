#!/usr/bin/env bash
# system_config.sh - main entry point

# Load libraries
source ./libs/constants.sh
source ./libs/panes.sh
source ./libs/input.sh
source ./libs/menus.sh
source ./libs/info_renderer.sh
source ./libs/system.sh
source ./libs/ssh.sh
source ./libs/php.sh
source ./libs/docker.sh
source ./libs/composer.sh
source ./libs/db.sh
source ./libs/users.sh

# Terminal setup
#trap "stty sane; tput cnorm; clear; exit" INT TERM
trap "stty sane; tput cnorm; exit" INT TERM
tput civis

# Initialize state
MENU_STATE="MAIN_MENU"
SELECTED_MENU_OPTION=0
SELECTED_INFO_TYPE=""
SELECTED_INFO_ENTITY=""

# Main loop
while true; do
    case "$MENU_STATE" in
        MAIN_MENU) handle_main_menu ;;
        USER_MENU) handle_user_menu ;;
        USER_ACTION_MENU) handle_user_action_menu ;;
        SYSTEM_APP_MENU) handle_system_app_menu ;;
        *) MENU_STATE="MAIN_MENU" ;;
    esac

    # Always draw info pane
    draw_info_pane
done