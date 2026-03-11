#!/usr/bin/env bash
# menus.sh - menu handlers with arrow navigation

# Helper to draw a menu
draw_menu() {
    local start_row=$1
    shift
    local options=("$@")
    local selected=$MENU_SELECTED_INDEX
    local i

    fill_pane $start_row $MENU_ROWS "$MENU_PANE_BG$TEXT_CLR"

    for i in "${!options[@]}"; do
        tput cup $((start_row + i)) 0
        if [[ $i -eq $selected ]]; then
            printf "%b> %s%b\n" "$MENU_PANE_BG$TEXT_CLR" "${options[$i]}" "$RESET"
        else
            printf "%b  %s%b\n" "$MENU_PANE_BG$TEXT_CLR" "${options[$i]}" "$RESET"
        fi
    done
}

# Main Menu
handle_main_menu() {
    local options=("Users" "System Apps" "Quit")
    MENU_SELECTED_INDEX=${MENU_SELECTED_INDEX:-0}

    while true; do
        draw_menu 0 "${options[@]}"
        local key
        key=$(get_navigation_key)

        case "$key" in
            UP) ((MENU_SELECTED_INDEX=(MENU_SELECTED_INDEX-1+${#options[@]})%${#options[@]})) ;;
            DOWN) ((MENU_SELECTED_INDEX=(MENU_SELECTED_INDEX+1)%${#options[@]})) ;;
            '')  # Enter key
                case $MENU_SELECTED_INDEX in
                    0) MENU_STATE="USER_MENU"; return ;;
                    1) MENU_STATE="SYSTEM_APP_MENU"; return ;;
                    2) stty sane; tput cnorm; clear; exit 0 ;;
                esac
                ;;
            q|Q)
                stty sane; tput cnorm; clear; exit 0 ;;
        esac
    done
}

# User Menu
handle_user_menu() {
    local options=("List Users" "Back")
    MENU_SELECTED_INDEX=${MENU_SELECTED_INDEX:-0}

    while true; do
        draw_menu 0 "${options[@]}"
        local key
        key=$(get_navigation_key)

        case "$key" in
            UP) ((MENU_SELECTED_INDEX=(MENU_SELECTED_INDEX-1+${#options[@]})%${#options[@]})) ;;
            DOWN) ((MENU_SELECTED_INDEX=(MENU_SELECTED_INDEX+1)%${#options[@]})) ;;
            '')  # Enter key
                case $MENU_SELECTED_INDEX in
                    0) 
                        SELECTED_INFO_TYPE="user"
                        SELECTED_INFO_ENTITY=""  # could prompt or select first user
                        MENU_STATE="USER_ACTION_MENU"
                        return
                        ;;
                    1) MENU_STATE="MAIN_MENU"; return ;;
                esac
                ;;
            q|Q) MENU_STATE="MAIN_MENU"; return ;;
        esac
    done
}

# User Action Menu (view user info)
handle_user_action_menu() {
    local options=("View Info" "Back")
    MENU_SELECTED_INDEX=${MENU_SELECTED_INDEX:-0}

    while true; do
        draw_menu 0 "${options[@]}"
        local key
        key=$(get_navigation_key)

        case "$key" in
            UP) ((MENU_SELECTED_INDEX=(MENU_SELECTED_INDEX-1+${#options[@]})%${#options[@]})) ;;
            DOWN) ((MENU_SELECTED_INDEX=(MENU_SELECTED_INDEX+1)%${#options[@]})) ;;
            '') 
                case $MENU_SELECTED_INDEX in
                    0)  # View info for selected user
                        SELECTED_INFO_TYPE="user"
                        SELECTED_INFO_ENTITY="testuser"  # placeholder
                        return
                        ;;
                    1) MENU_STATE="USER_MENU"; return ;;
                esac
                ;;
            q|Q) MENU_STATE="USER_MENU"; return ;;
        esac
    done
}

# System App Menu
handle_system_app_menu() {
    local options=("SSH" "Docker" "PHP" "Composer" "Back")
    MENU_SELECTED_INDEX=${MENU_SELECTED_INDEX:-0}

    while true; do
        draw_menu 0 "${options[@]}"
        local key
        key=$(get_navigation_key)

        case "$key" in
            UP) ((MENU_SELECTED_INDEX=(MENU_SELECTED_INDEX-1+${#options[@]})%${#options[@]})) ;;
            DOWN) ((MENU_SELECTED_INDEX=(MENU_SELECTED_INDEX+1)%${#options[@]})) ;;
            '') 
                case $MENU_SELECTED_INDEX in
                    0) SELECTED_INFO_TYPE="ssh"; SELECTED_INFO_ENTITY="ssh"; return ;;
                    1) SELECTED_INFO_TYPE="docker"; SELECTED_INFO_ENTITY="docker"; return ;;
                    2) handle_php_menu; return ;;
                    3) handle_composer_menu; return ;;
                    4) MENU_STATE="MAIN_MENU"; return ;;
                esac
                ;;
            q|Q) MENU_STATE="MAIN_MENU"; return ;;
        esac
    done
}

# Placeholder functions
handle_php_menu() {
    clear_pane 0 $MENU_ROWS
    echo "PHP menu (placeholder)"
    read -rsn1
}

handle_composer_menu() {
    clear_pane 0 $MENU_ROWS
    echo "Composer menu (placeholder)"
    read -rsn1
}