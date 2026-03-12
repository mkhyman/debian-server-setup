#!/usr/bin/env bash

INPUT_MODE="normal"

# Prompt buffer
PROMPT_BUFFER=""
PROMPT_HANDLER=""
PROMPT_TEXT=""
PROMPT_ROW=""
PROMPT_BUFFER_LINE=""

CHOICE_HANDLER=""
CHOICE_ALLOWED=""
CHOICE_TEXT=""
CHOICE_ROW=""
CHOICE_BUFFER_LINE=""

handle_normal_key() {
    local key="$1"
    local bottom_pane=3  # index of scrollable pane

    case "$key" in
        # Bottom pane scrolling
        $'\e[A')  # Up arrow
            pane_scroll_up "$bottom_pane"
            ;;
        $'\e[B')  # Down arrow
            pane_scroll_down "$bottom_pane"
            ;;
        # Menu keys
        [1-9])
            select_menu_item "$key"
            ;;
        [Bb])
            menu_handle_back_shortcut
            ;;
        [Qq])
            menu_handle_quit_shortcut
            ;;

		w)
			start_test_workflow
			;;
    esac
}

handle_prompt_key() {
    local key="$1"
    local handler
    local value
    local final_text

    if [[ -z "$key" || "$key" == $'\r' || "$key" == $'\n' ]]; then
        handler="$PROMPT_HANDLER"
        value="$PROMPT_BUFFER"
        final_text="${PROMPT_TEXT}${PROMPT_BUFFER}"

        pane_replace_line 3 "$PROMPT_BUFFER_LINE" "$final_text"

        PROMPT_BUFFER=""
        PROMPT_HANDLER=""
        PROMPT_TEXT=""
        PROMPT_ROW=""
        PROMPT_BUFFER_LINE=""
        INPUT_MODE="normal"

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
    local final_text

    case "$key" in
        [A-Z])
            key=$(printf "%s" "$key" | tr 'A-Z' 'a-z')
            ;;
    esac

    if [[ "$CHOICE_ALLOWED" != *"$key"* ]]; then
        return
    fi

    handler="$CHOICE_HANDLER"
    final_text="${CHOICE_TEXT} -> $key"

    pane_replace_line 3 "$CHOICE_BUFFER_LINE" "$final_text"

    CHOICE_HANDLER=""
    CHOICE_ALLOWED=""
    CHOICE_TEXT=""
    CHOICE_ROW=""
    CHOICE_BUFFER_LINE=""
    INPUT_MODE="normal"

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
    PROMPT_BUFFER_LINE=$(( $(pane_line_count 3) - 1 ))
}

#usage: start_choice "Choose option: " "abc" choice_handler
start_choice() {
    local choice_text="$1"
    local choice_allowed="$2"
    local choice_handler="$3"

    INPUT_MODE="choice"
    CHOICE_ALLOWED="$choice_allowed"
    CHOICE_HANDLER="$choice_handler"
    CHOICE_TEXT="$choice_text"

    pane_append 3 "$CHOICE_TEXT"

    CHOICE_ROW=${PANE_CURSOR[3]}
    CHOICE_BUFFER_LINE=$(( $(pane_line_count 3) - 1 ))
}

read_key() {
    local key
    local rest

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