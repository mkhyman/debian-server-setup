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
    local handler
    local value

    if [[ -z "$key" || "$key" == $'\r' || "$key" == $'\n' ]]; then
        handler="$PROMPT_HANDLER"
        value="$PROMPT_BUFFER"

        # Leave prompt mode first
        PROMPT_BUFFER=""
        PROMPT_HANDLER=""
        PROMPT_TEXT=""
        INPUT_MODE="normal"

        # Now run callback in normal mode
        if [[ -n "$handler" ]]; then
            "$handler" "$value"
        fi
        return
    fi

    if [[ "$key" == $'\177' || "$key" == $'\010' ]]; then
        PROMPT_BUFFER="${PROMPT_BUFFER%?}"
    else
        PROMPT_BUFFER+="$key"
    fi

    pane_print_line 3 "$PROMPT_ROW" "${PROMPT_TEXT}${PROMPT_BUFFER}"
}

handle_choice_key() {
    local key="$1"
    local handler

    case "$key" in
        [A-Z])
            key=$(printf "%s" "$key" | tr 'A-Z' 'a-z')
            ;;
    esac

    if [[ "$CHOICE_ALLOWED" != *"$key"* ]]; then
        return
    fi

    # Save handler before clearing state
    handler="$CHOICE_HANDLER"

    # Leave choice mode first
    CHOICE_HANDLER=""
    CHOICE_ALLOWED=""
    INPUT_MODE="normal"

    # Now call handler in normal mode
    if [[ -n "$handler" ]]; then
        "$handler" "$key"
    fi
}

#usage: start_prompt "Enter name: " prompt_handler
start_prompt() {
    local prompt_text="$1"
    local prompt_handler="$2"

    INPUT_MODE="prompt"
    PROMPT_BUFFER=""
    PROMPT_HANDLER="$prompt_handler"
    PROMPT_TEXT="$prompt_text"

    pane_append 3 "$PROMPT_TEXT"
    PROMPT_ROW=${PANE_CURSOR[3]}
}

#usage: start_choice "Choose option: " "abc" choice_handler
start_choice() {
    local choice_text="$1"
    local choice_allowed="$2"
    local choice_handler="$3"

    INPUT_MODE="choice"
    CHOICE_ALLOWED="$choice_allowed"
    CHOICE_HANDLER="$choice_handler"

    pane_append 3 "$choice_text"
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