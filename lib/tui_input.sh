#!/usr/bin/env bash
TUI_INPUT_MODE="normal"

TUI_PROMPT_BUFFER=""
TUI_PROMPT_TEXT=""
TUI_PROMPT_HANDLER=""
TUI_PROMPT_PANE_ID=""
TUI_PROMPT_BUFFER_INDEX=""

TUI_CHOICE_TEXT=""
TUI_CHOICE_ALLOWED=""
TUI_CHOICE_HANDLER=""
TUI_CHOICE_PANE_ID=""
TUI_CHOICE_BUFFER_INDEX=""

tui_handle_key() {
    local key="$1"

    case "$TUI_INPUT_MODE" in
        prompt)
            tui_handle_prompt_key "$key"
            ;;
        choice)
            tui_handle_choice_key "$key"
            ;;
        *)
            tui_handle_normal_key "$key"
            ;;
    esac
}

tui_read_key() {
    local key
    local rest=""
    local tty_state

    IFS= read -rsn1 key || return 1

    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 rest || true
        key+="$rest"
    fi

    printf '%s' "$key"
}

tui_handle_normal_key() {

    local key="$1"

    case "$key" in
        $'\e[A')
            pane_scroll_up "$PANE_ACTION_ID"
            ;;

        $'\e[B')
            pane_scroll_down "$PANE_ACTION_ID"
            ;;

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

tui_handle_prompt_key() {
    local key="$1"
    local handler=""
    local value=""
    local committed_text=""

    case "$key" in
        $'\r'|$'\n'|"")
            handler="$TUI_PROMPT_HANDLER"
            value="$TUI_PROMPT_BUFFER"
            committed_text="${TUI_PROMPT_TEXT}${value}"

            tui_commit_line_at_index \
                "$TUI_PROMPT_PANE_ID" \
                "$TUI_PROMPT_BUFFER_INDEX" \
                "$committed_text"

            TUI_PROMPT_BUFFER=""
            TUI_PROMPT_TEXT=""
            TUI_PROMPT_HANDLER=""
            TUI_PROMPT_PANE_ID=""
            TUI_PROMPT_BUFFER_INDEX=""
            TUI_INPUT_MODE="normal"

            if [[ -n "$handler" ]]; then
                "$handler" "$value"
            fi
            return
            ;;

        $'\177'|$'\010')
            TUI_PROMPT_BUFFER="${TUI_PROMPT_BUFFER%?}"
            ;;

        *)
            TUI_PROMPT_BUFFER+="$key"
            ;;
    esac

    committed_text="${TUI_PROMPT_TEXT}${TUI_PROMPT_BUFFER}"

    tui_commit_line_at_index \
        "$TUI_PROMPT_PANE_ID" \
        "$TUI_PROMPT_BUFFER_INDEX" \
        "$committed_text"
}

tui_handle_choice_key() {
    local key="$1"
    local handler=""
    local value=""
    local committed_text=""

    case "$key" in
        [A-Z])
            key="$(printf '%s' "$key" | tr 'A-Z' 'a-z')"
            ;;
    esac

    if [[ "$TUI_CHOICE_ALLOWED" != *"$key"* ]]; then
        return
    fi

    handler="$TUI_CHOICE_HANDLER"
    value="$key"
    committed_text="${TUI_CHOICE_TEXT}${value}"

    tui_commit_line_at_index \
        "$TUI_CHOICE_PANE_ID" \
        "$TUI_CHOICE_BUFFER_INDEX" \
        "$committed_text"

    TUI_CHOICE_TEXT=""
    TUI_CHOICE_ALLOWED=""
    TUI_CHOICE_HANDLER=""
    TUI_CHOICE_PANE_ID=""
    TUI_CHOICE_BUFFER_INDEX=""
    TUI_INPUT_MODE="normal"

    if [[ -n "$handler" ]]; then
        "$handler" "$value"
    fi
}

tui_prompt_start() {
    local pane_id="$1"
    local prompt_text="$2"
    local prompt_handler="$3"

    TUI_INPUT_MODE="prompt"
    TUI_PROMPT_BUFFER=""
    TUI_PROMPT_TEXT="$prompt_text"
    TUI_PROMPT_HANDLER="$prompt_handler"
    TUI_PROMPT_PANE_ID="$pane_id"

    pane_append "$pane_id" "$prompt_text"
    TUI_PROMPT_BUFFER_INDEX="$(tui_get_buffer_index_for_cursor "$pane_id")"

    log_info input "Entering prompt mode"
}

tui_choice_start() {
    local pane_id="$1"
    local choice_text="$2"
    local choice_allowed="$3"
    local choice_handler="$4"

    TUI_INPUT_MODE="choice"
    TUI_CHOICE_TEXT="$choice_text"
    TUI_CHOICE_ALLOWED="$choice_allowed"
    TUI_CHOICE_HANDLER="$choice_handler"
    TUI_CHOICE_PANE_ID="$pane_id"

    pane_append "$pane_id" "$choice_text"
    TUI_CHOICE_BUFFER_INDEX="$(tui_get_buffer_index_for_cursor "$pane_id")"

    log_info input "Entering choice mode"
}

tui_get_buffer_index_for_cursor() {
    local pane_id="$1"

    printf '%s' "$((PANE_SCROLL[$pane_id] + PANE_CURSOR[$pane_id]))"
}

tui_commit_line_at_index() {
    local pane_id="$1"
    local buffer_index="$2"
    local text="$3"

    pane_replace_line "$pane_id" "$buffer_index" "$text" || return 1
    pane_draw "$pane_id"
}