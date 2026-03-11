#!/usr/bin/env bash

source lib/tui_panes.sh
source lib/tui_input.sh  # contains read_key
source lib/workflow.sh
source test_workflow.sh

# -----------------------------
# CLEANUP FUNCTION
# -----------------------------
cleanup() {
    # Reset terminal modes first
    stty sane           # restores echo, canonical mode, ^C, ^D
    tput cnorm          # show cursor

    # Restore alternate screen if tput smcup was used
    tput rmcup || true

    # Clear any leftover colored lines
    clear
}
trap cleanup EXIT INT TERM HUP

# -----------------------------
# TERMINAL INIT
# -----------------------------
tput smcup      # enter alternate screen
tput civis      # hide cursor
stty -echo      # disable echo
tput clear

# -----------------------------
# PANE SETUP
# -----------------------------
setup_panes
pane_draw_all

quit_application() {
    exit 0
}

# Counter for dynamic log lines
count=1

# -----------------------------
# MAIN LOOP
# -----------------------------
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