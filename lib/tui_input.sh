#!/usr/bin/env bash

INPUT_MODE="normal"

read_key() {

    local key
    local rest=""

    IFS= read -rsn1 key || return 1

    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 rest || true
        key+="$rest"
    fi

    printf '%s' "$key"
}

handle_normal_key() {

    local key="$1"

    case "$key" in

        [1-9])
            select_menu_item "$key"
            ;;

        [Bb])
            menu_handle_back_shortcut
            ;;

        [Qq])
            menu_handle_quit_shortcut
            ;;

    esac
}

enter_prompt_mode() {

    INPUT_MODE="prompt"

    log_info input "Entering prompt mode"
}

enter_choice_mode() {

    INPUT_MODE="choice"

    log_info input "Entering choice mode"
}

handle_prompt_key() {

    local key="$1"

    if [[ "$key" == $'\n' ]]; then
        log_info input "Prompt submitted"
        INPUT_MODE="normal"
    fi
}

handle_choice_key() {

    local key="$1"

    if [[ "$key" =~ ^[1-9]$ ]]; then
        log_info input "Choice selected"
        INPUT_MODE="normal"
    fi
}