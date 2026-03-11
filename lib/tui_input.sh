#!/usr/bin/env bash

handle_normal_key() {
    local key="$1"
    local bottom_pane=3  # index of scrollable pane

    case "$key" in
        # Bottom pane scrolling
        $'\e[A')  # Up arrow
            if (( PANE_SCROLL[bottom_pane] > 0 )); then
                ((PANE_SCROLL[bottom_pane]--))
                pane_draw "$bottom_pane"
            fi
            ;;
        $'\e[B')  # Down arrow
            local total=0 tmp
            local IFS=$'\n'
            while read -r tmp; do ((total++)); done <<< "${PANE_BUFFER[bottom_pane]}"
            local max_scroll=$(( total - PANE_HEIGHT[bottom_pane] ))
            if (( PANE_SCROLL[bottom_pane] < max_scroll )); then
                ((PANE_SCROLL[bottom_pane]++))
                pane_draw "$bottom_pane"
            fi
            ;;
        # Menu keys
        [1-9])
            select_menu_item "$key"
            ;;
        [Bb])
            go_back_in_menu
            ;;
        [Qq])
            quit_application
            ;;
    esac
}

handle_prompt_key() {
    local key="$1"

    if [[ $key == $'\r' ]]; then  # Enter key
        if [[ -n "$PROMPT_HANDLER" ]]; then
            "$PROMPT_HANDLER" "$PROMPT_BUFFER"
        fi
        PROMPT_BUFFER=""
        PROMPT_HANDLER=""
        INPUT_MODE="normal"
        return
    fi

    # Append typed character to buffer
    PROMPT_BUFFER+="$key"

    # Append to bottom pane, auto-scroll if needed
    pane_append 3 "$PROMPT_BUFFER"
}

handle_choice_key() {
    local key="$1"

    # Only accept input if in allowed set
    if [[ "$CHOICE_ALLOWED" == *"$key"* ]]; then
        if [[ -n "$CHOICE_HANDLER" ]]; then
            workflow_choice_handler "$key" "$CHOICE_ALLOWED"
        fi
        # Reset handler and return to normal mode
        CHOICE_HANDLER=""
        CHOICE_ALLOWED=""
        INPUT_MODE="normal"
    fi
}

read_key() {
    local key

    # read one character silently
    read -s -n 1 key
    local status=$?

    # If read failed (Ctrl+C or signal), propagate failure
    if [ $status -ne 0 ]; then
        return 1
    fi

    # Handle escape sequences (arrow keys)
    if [ "$key" = $'\033' ]; then
        read -s -n 2 rest
        key="$key$rest"
    fi

    printf "%s" "$key"
    return 0
}