#!/usr/bin/env bash
# system_config.sh - integrated menu system with safe input handling

# ----------------------------
# Global configuration / constants
# ----------------------------

MENU_PANE_BG="\e[48;5;235m"
INFO_PANE_BG="\e[48;5;236m"
ACTION_PANE_BG="\e[48;5;237m"
TEXT_CLR="\e[97m"
RESET="\e[0m"

TOTAL_ROWS=$(tput lines)
TOTAL_COLS=$(tput cols)
MENU_ROWS=10
INFO_ROWS=$((TOTAL_ROWS - MENU_ROWS - 3))  # leave 3 for action pane
ACTION_ROWS=3

# Initialize menu state
MENU_STATE="MAIN_MENU"
SELECTED_MENU_OPTION=0

# Info context
SELECTED_INFO_TYPE=""
SELECTED_INFO_ENTITY=""

# Global dictionary of headers/messages
declare -A DICTIONARY
DICTIONARY["SYSTEM_PANE_HEADER"]="System Overview|──────────────"
DICTIONARY["WELCOME_MESSAGE"]="Welcome to the System Configuration Menu"

# Sample menus
MAIN_MENU_ITEMS=("List Users" "Select User" "System Overview" "Exit")
USER_MENU_ITEMS=("View Info" "Modify" "Delete" "Back")
USER_ACTION_MENU_ITEMS=("View Info" "Modify" "Delete" "Back")
SYSTEM_APP_MENU_ITEMS=("MariaDB/MySQL" "SSH" "SFTP" "Docker" "Back")

# ----------------------------
# Terminal setup and traps
# ----------------------------

trap "stty sane; tput cnorm; clear; exit" INT TERM
tput civis

# ----------------------------
# Helper functions
# ----------------------------

clear_pane() {
    local rows=$1
    for ((i=0;i<rows;i++)); do
        printf "\e[%d;1H\e[2K" $((i+1))
    done
}

draw_header() {
    local header_key="$1"
    local IFS='|'
    local lines=(${DICTIONARY[$header_key]})
    for line in "${lines[@]}"; do
        printf "%b%-${TOTAL_COLS}s%b\n" "$MENU_PANE_BG$TEXT_CLR" "$line" "$RESET"
    done
}

draw_menu_pane() {
    local items=("$@")
    clear_pane "$MENU_ROWS"
    for i in "${!items[@]}"; do
        local prefix="  "
        if [[ $i -eq $SELECTED_MENU_OPTION ]]; then
            prefix="> "
        fi
        printf "%b%-${TOTAL_COLS}s%b\n" "$MENU_PANE_BG$TEXT_CLR" "$prefix${items[i]}" "$RESET"
    done
}

draw_info_pane() {
    clear_pane "$INFO_ROWS"
    local lines=()
    case "$SELECTED_INFO_TYPE" in
        user)
            lines=("User Info" "──────────"
                   "Username: $SELECTED_INFO_ENTITY"
                   "UID: 1001"
                   "Groups: $SELECTED_INFO_ENTITY"
                   "Home: /home/$SELECTED_INFO_ENTITY")
            ;;
        db)
            lines=("Database Info" "────────────"
                   "Name: $SELECTED_INFO_ENTITY"
                   "State: Running" "Version: 10.6")
            ;;
        user_list)
            lines=("System Users" "──────────"
                   "testuser"
                   "admin"
                   "guest")
            ;;
        system)
            lines=("System Overview" "────────────"
                   "SSH: Installed"
                   "MariaDB/MySQL: Installed"
                   "Docker: Running")
            ;;
        *)
            lines=("No info available")
            ;;
    esac
    for line in "${lines[@]}"; do
        printf "%b%-${TOTAL_COLS}s%b\n" "$INFO_PANE_BG$TEXT_CLR" "$line" "$RESET"
    done
}

draw_action_pane() {
    clear_pane "$ACTION_ROWS"
    printf "%b%-${TOTAL_COLS}s%b\n" "$ACTION_PANE_BG$TEXT_CLR" "Press Space to continue..." "$RESET"
}

set_info_context() {
    SELECTED_INFO_TYPE="$1"
    SELECTED_INFO_ENTITY="$2"
}

# ----------------------------
# Key reading functions
# ----------------------------

get_key() {
    old_stty=$(stty -g)
    stty raw -echo -icanon time 0 min 0

    key=""
    seq=""
    while IFS= read -r -n1 -s char; do
        seq+="$char"
        case "$seq" in
            $'\x1b[A') key="UP"; break ;;
            $'\x1b[B') key="DOWN"; break ;;
            $'\x1b[C') key="RIGHT"; break ;;
            $'\x1b[D') key="LEFT"; break ;;
        esac
        if [[ -z "$key" && "$seq" != $'\x1b' && ${#seq} -eq 1 ]]; then
            key="$seq"
            break
        fi
    done

    stty "$old_stty"
    echo "$key"
}

prompt_string() {
    stty sane
    tput cnorm
    local prompt="$1"
    printf "%b%-${TOTAL_COLS}s%b\n" "$ACTION_PANE_BG$TEXT_CLR" "$prompt" "$RESET"
    read -r input
    tput civis
    echo "$input"
}

# ----------------------------
# Menu handling functions
# ----------------------------

handle_main_menu() {
    draw_header "SYSTEM_PANE_HEADER"
    draw_menu_pane "${MAIN_MENU_ITEMS[@]}"
    draw_info_pane
    draw_action_pane

    key=$(get_key)
    case "$key" in
        UP)
            ((SELECTED_MENU_OPTION--))
            if ((SELECTED_MENU_OPTION<0)); then SELECTED_MENU_OPTION=$((${#MAIN_MENU_ITEMS[@]}-1)); fi
            ;;
        DOWN)
            ((SELECTED_MENU_OPTION++))
            if ((SELECTED_MENU_OPTION>=${#MAIN_MENU_ITEMS[@]})); then SELECTED_MENU_OPTION=0; fi
            ;;
        "")
            ;;
        $'\x20') ;; # space
        *)
            case "${MAIN_MENU_ITEMS[SELECTED_MENU_OPTION]}" in
                "List Users")
                    MENU_STATE="USER_MENU"
                    SELECTED_MENU_OPTION=0
                    set_info_context "user_list" ""
                    ;;
                "Select User")
                    handle_select_user
                    ;;
                "System Overview")
                    set_info_context "system" ""
                    ;;
                "Exit")
                    stty sane; tput cnorm; clear; exit
                    ;;
            esac
            ;;
    esac
}

handle_user_menu() {
    draw_menu_pane "${USER_MENU_ITEMS[@]}"
    draw_info_pane
    draw_action_pane

    key=$(get_key)
    case "$key" in
        UP)
            ((SELECTED_MENU_OPTION--))
            if ((SELECTED_MENU_OPTION<0)); then SELECTED_MENU_OPTION=$((${#USER_MENU_ITEMS[@]}-1)); fi
            ;;
        DOWN)
            ((SELECTED_MENU_OPTION++))
            if ((SELECTED_MENU_OPTION>=${#USER_MENU_ITEMS[@]})); then SELECTED_MENU_OPTION=0; fi
            ;;
        "")
            ;;
        $'\x20') ;;
        *)
            case "${USER_MENU_ITEMS[SELECTED_MENU_OPTION]}" in
                "Back")
                    MENU_STATE="MAIN_MENU"
                    SELECTED_MENU_OPTION=0
                    set_info_context "" ""
                    ;;
                *)
                    MENU_STATE="USER_ACTION_MENU"
                    SELECTED_MENU_OPTION=0
                    ;;
            esac
            ;;
    esac
}

handle_user_action_menu() {
    draw_menu_pane "${USER_ACTION_MENU_ITEMS[@]}"
    draw_info_pane
    draw_action_pane

    key=$(get_key)
    case "$key" in
        UP)
            ((SELECTED_MENU_OPTION--))
            if ((SELECTED_MENU_OPTION<0)); then SELECTED_MENU_OPTION=$((${#USER_ACTION_MENU_ITEMS[@]}-1)); fi
            ;;
        DOWN)
            ((SELECTED_MENU_OPTION++))
            if ((SELECTED_MENU_OPTION>=${#USER_ACTION_MENU_ITEMS[@]})); then SELECTED_MENU_OPTION=0; fi
            ;;
        "")
            ;;
        $'\x20') ;;
        *)
            case "${USER_ACTION_MENU_ITEMS[SELECTED_MENU_OPTION]}" in
                "Back")
                    MENU_STATE="USER_MENU"
                    SELECTED_MENU_OPTION=0
                    set_info_context "user" "$SELECTED_INFO_ENTITY"
                    ;;
                *)
                    printf "%b%-${TOTAL_COLS}s%b\n" "$ACTION_PANE_BG$TEXT_CLR" \
                        "Action: ${USER_ACTION_MENU_ITEMS[SELECTED_MENU_OPTION]}" "$RESET"
                    ;;
            esac
            ;;
    esac
}

handle_select_user() {
    local username
    username=$(prompt_string "Enter username to select:")
    if [[ "$username" == "testuser" ]]; then
        set_info_context "user" "$username"
        draw_info_pane
        MENU_STATE="USER_MENU"
        SELECTED_MENU_OPTION=0
    else
        printf "%b%-${TOTAL_COLS}s%b\n" "$ACTION_PANE_BG$TEXT_CLR" "User not found" "$RESET"
    fi
}

handle_system_app_menu() {
    draw_menu_pane "${SYSTEM_APP_MENU_ITEMS[@]}"
    draw_info_pane
    draw_action_pane

    key=$(get_key)
    case "$key" in
        UP)
            ((SELECTED_MENU_OPTION--))
            if ((SELECTED_MENU_OPTION<0)); then SELECTED_MENU_OPTION=$((${#SYSTEM_APP_MENU_ITEMS[@]}-1)); fi
            ;;
        DOWN)
            ((SELECTED_MENU_OPTION++))
            if ((SELECTED_MENU_OPTION>=${#SYSTEM_APP_MENU_ITEMS[@]})); then SELECTED_MENU_OPTION=0; fi
            ;;
        "")
            ;;
        $'\x20') ;;
        *)
            case "${SYSTEM_APP_MENU_ITEMS[SELECTED_MENU_OPTION]}" in
                "Back")
                    MENU_STATE="MAIN_MENU"
                    SELECTED_MENU_OPTION=0
                    set_info_context "" ""
                    ;;
                *)
                    set_info_context "db" "${SYSTEM_APP_MENU_ITEMS[SELECTED_MENU_OPTION]}"
                    draw_info_pane
                    ;;
            esac
            ;;
    esac
}

# ----------------------------
# Main loop
# ----------------------------

while true; do
    case "$MENU_STATE" in
        MAIN_MENU)
            handle_main_menu
            ;;
        USER_MENU)
            handle_user_menu
            ;;
        USER_ACTION_MENU)
            handle_user_action_menu
            ;;
        SYSTEM_APP_MENU)
            handle_system_app_menu
            ;;
        *)
            MENU_STATE="MAIN_MENU"
            ;;
    esac
done