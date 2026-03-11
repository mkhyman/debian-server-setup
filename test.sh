#!/usr/bin/env bash

source lib/tui_panes.sh
source lib/tui_input.sh  # contains read_key
source lib/workflow.sh

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

pane_append 0 "SYSTEM PANE (static)"
pane_append 1 "MENU PANE (static)"
pane_append 2 "INFO PANE (static)"
pane_append 3 "BOTTOM PANE (scrollable) 1"
pane_append 3 "BOTTOM PANE (scrollable) 2"
pane_append 3 "BOTTOM PANE (scrollable) 3"
pane_append 3 "BOTTOM PANE (scrollable) 4"
pane_append 3 "BOTTOM PANE (scrollable) 5"
pane_append 3 $'Multi line test\nLine two\nLine three'
pane_append 3 "BOTTOM PANE (scrollable) 6"
pane_append 3 "BOTTOM PANE (scrollable) 7"

#for i in $(seq 1 200); do
 #   pane_append 3 "stress line $i"
#done



prompt_done() {
    pane_append 3 "Name entered: $1"
    INPUT_MODE="normal"
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