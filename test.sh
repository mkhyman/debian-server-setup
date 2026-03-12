#!/usr/bin/env bash

source config/log_config.sh
source lib/log.sh

source lib/core.sh
source lib/tui_panes.sh
source lib/tui_input.sh
source lib/tui_menu.sh
source lib/workflow.sh
source test_workflow.sh

source menu/main_menu.sh
source menu/user_menu.sh
source menu/application_menu.sh

core_install_traps
core_init || exit 1

setup_panes
pane_draw_all
menu_init "MAIN"

while true; do
    key=$(read_key) || break

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