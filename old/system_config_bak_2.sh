#!/bin/bash
set -euo pipefail
shopt -s extglob

# -------------------------
# Colours and formatting
# -------------------------
SYSTEM_PANE_BG="\033[48;5;233m"
MENU_PANE_BG="\033[48;5;236m"
INFO_PANE_BG="\033[48;5;235m"
ACTION_PANE_BG="\033[48;5;234m"
TEXT_CLR="\033[97m"
RESET="\033[0m"

TICK="[ OK ]"
CROSS="[ FAIL ]"

: "${COLUMNS:=80}"
: "${LINES:=24}"

# -------------------------
# Global state
# -------------------------
MENU_STATE="MAIN_MENU"
MENU_SELECTED_OPTION=0
SELECTED_USER=""
SYSTEM_PANE_HEIGHT=6
MENU_PANE_HEIGHT=8
INFO_PANE_HEIGHT=8
ACTION_PANE_HEIGHT=$((LINES - SYSTEM_PANE_HEIGHT - MENU_PANE_HEIGHT - INFO_PANE_HEIGHT))
ACTION_CURRENT_ROW=$((SYSTEM_PANE_HEIGHT + MENU_PANE_HEIGHT + INFO_PANE_HEIGHT))

# -------------------------
# Pane headers
# -------------------------
SYSTEM_PANE_HEADER=("System Overview" "──────────────")
USER_INFO_HEADER=("User Info" "──────────")
MENU_HEADER=("Menu" "─────")

# -------------------------
# Pane utilities
# -------------------------
clear_screen(){ tput clear; }
clear_system_pane(){ for ((i=0;i<SYSTEM_PANE_HEIGHT;i++)); do tput cup $i 0; printf "%-${COLUMNS}s" " "; done }
clear_menu_pane(){ for ((i=0;i<MENU_PANE_HEIGHT;i++)); do tput cup $((SYSTEM_PANE_HEIGHT+i)) 0; printf "%-${COLUMNS}s" " "; done }
clear_info_pane(){ for ((i=0;i<INFO_PANE_HEIGHT;i++)); do tput cup $((SYSTEM_PANE_HEIGHT+MENU_PANE_HEIGHT+i)) 0; printf "%-${COLUMNS}s" " "; done }
clear_action_pane(){
    for ((i=0;i<ACTION_PANE_HEIGHT;i++)); do
        tput cup $((SYSTEM_PANE_HEIGHT+MENU_PANE_HEIGHT+INFO_PANE_HEIGHT+i)) 0
        printf "%-${COLUMNS}s" " "
    done
    ACTION_CURRENT_ROW=$((SYSTEM_PANE_HEIGHT+MENU_PANE_HEIGHT+INFO_PANE_HEIGHT))
}

draw_pane(){
    local -n lines_array=$1
    local bg=$2
    local start=$3
    local height=$4
    for ((i=0;i<height;i++)); do
        tput cup $((start+i)) 0
        [[ $i -lt ${#lines_array[@]} ]] && line="${lines_array[i]}" || line=""
        printf "%b%-${COLUMNS}s%b\n" "$bg$TEXT_CLR" "$line" "$RESET"
    done
}

draw_system_pane(){ draw_pane SYSTEM_PANE_LINES "$SYSTEM_PANE_BG" 0 "$SYSTEM_PANE_HEIGHT"; }
draw_menu_pane(){ draw_pane MENU_PANE_LINES "$MENU_PANE_BG" "$SYSTEM_PANE_HEIGHT" "$MENU_PANE_HEIGHT"; }
draw_info_pane(){ draw_pane INFO_PANE_LINES "$INFO_PANE_BG" "$((SYSTEM_PANE_HEIGHT + MENU_PANE_HEIGHT))" "$INFO_PANE_HEIGHT"; }

draw_action_message(){
    tput cup "$ACTION_CURRENT_ROW" 0
    printf "%b%-${COLUMNS}s%b\n" "$ACTION_PANE_BG$TEXT_CLR" "$1" "$RESET"
    ((ACTION_CURRENT_ROW++))
}

read_action_key(){
    tput cup "$ACTION_CURRENT_ROW" 0
    printf "%b%-${COLUMNS}s%b" "$ACTION_PANE_BG$TEXT_CLR" "$1" "$RESET"
    IFS= read -rsn1 key
    ((ACTION_CURRENT_ROW++))
    echo "$key"
}

# -------------------------
# Status helpers
# -------------------------
status_label(){
    local rc=$1
    case "$rc" in
        0) echo "$TICK" ;;
        1) echo "$CROSS" ;;
        2) echo "N/A" ;;
        *) echo "N/A" ;;
    esac
}

service_status(){
    local svc="$1"
    command -v "$svc" >/dev/null 2>&1 || { echo "Not Installed"; return; }
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active "$svc" >/dev/null 2>&1 && echo "Running" || echo "Stopped"
    else
        pgrep -f "$svc" >/dev/null 2>&1 && echo "Running" || echo "Stopped"
    fi
}

# -------------------------
# User helpers
# -------------------------
user_exists(){ id "$1" &>/dev/null; }
user_has_password(){ local pw=$(getent shadow "$1" | cut -d: -f2); [[ -z "$pw" || "$pw" == '!'* || "$pw" == '*'* ]] && return 1 || return 0; }
user_password_login_enabled(){ local pw=$(getent shadow "$1" | cut -d: -f2); [[ "$pw" == '!'* || "$pw" == '*'* ]] && return 1 || return 0; }
user_ssh_access_enabled(){ command -v sshd >/dev/null 2>&1 || return 2; grep -q "^AllowUsers.*$1" /etc/ssh/sshd_config && return 0; return 1; }
user_sftp_access_enabled(){ command -v sshd >/dev/null 2>&1 || return 2; grep -q "^Subsystem sftp" /etc/ssh/sshd_config && return 0; return 1; }
user_has_mailbox(){ [[ -d "/var/mail/$1" || -f "/var/mail/$1" ]] && return 0 || return 1; }

toggle_password_login(){
    local state=$(getent shadow "$SELECTED_USER" | cut -d: -f2)
    if [[ "$state" == '!'* || "$state" == '*'* ]]; then
        passwd -u "$SELECTED_USER" >/dev/null
        draw_action_message "Password login enabled."
    else
        passwd -l "$SELECTED_USER" >/dev/null
        draw_action_message "Password login disabled."
    fi
}

# -------------------------
# User info display
# -------------------------
display_user_info(){
    INFO_PANE_LINES=("${USER_INFO_HEADER[@]}")
    local user="$1"
    if user_exists "$user"; then
        user_has_password "$user"; local pw_state=$?
        user_password_login_enabled "$user"; local login_state=$?
        user_ssh_access_enabled "$user"; local ssh_state=$?
        user_sftp_access_enabled "$user"; local sftp_state=$?
        user_has_mailbox "$user"; local mail_state=$?

        INFO_PANE_LINES+=("Username: $user")
        INFO_PANE_LINES+=("UID: $(id -u "$user")")
        INFO_PANE_LINES+=("Groups: $(id -Gn "$user")")
        INFO_PANE_LINES+=("Home: $(eval echo ~$user)")
        INFO_PANE_LINES+=("Password: $(status_label $pw_state)")
        INFO_PANE_LINES+=("Can login: $(status_label $login_state)")
        INFO_PANE_LINES+=("SSH access: $(status_label $ssh_state)")
        INFO_PANE_LINES+=("SFTP access: $(status_label $sftp_state)")
        INFO_PANE_LINES+=("Mailbox: $(status_label $mail_state)")
    else
        INFO_PANE_LINES+=("User does not exist")
    fi
    draw_info_pane
}

# -------------------------
# System overview
# -------------------------
display_system_overview(){
    SYSTEM_PANE_LINES=("${SYSTEM_PANE_HEADER[@]}")

    ssh_client=$(command -v ssh >/dev/null 2>&1 && echo "Installed" || echo "Not Installed")
    ssh_server=$(command -v sshd >/dev/null 2>&1 && echo "Installed" || echo "Not Installed")
    ssh_server_status="N/A"; [[ "$ssh_server" == "Installed" ]] && ssh_server_status=$(service_status sshd)
    sftp_status="N/A"; [[ "$ssh_server" == "Installed" ]] && grep -q "^Subsystem sftp" /etc/ssh/sshd_config && sftp_status="Enabled" || sftp_status="Disabled"

    php_cli=$(command -v php >/dev/null 2>&1 && echo "Installed" || echo "Not Installed")
    php_fpm_status="Missing"; [[ -x "$(command -v php-fpm)" ]] && php_fpm_status="Running"

    apache_status="Missing"; [[ -x "$(command -v apache2)" ]] && apache_status=$(service_status apache2)
    docker_status="Missing"; [[ -x "$(command -v docker)" ]] && docker_status=$(service_status dockerd)

    mariadb_status="Missing"
    if command -v mariadbd >/dev/null 2>&1; then mariadb_status=$(service_status mariadbd)
    elif command -v mysqld >/dev/null 2>&1; then mariadb_status=$(service_status mysqld); fi

    composer_status=$(command -v composer >/dev/null 2>&1 && echo "Installed" || echo "Not Installed")
    node_status=$(command -v node >/dev/null 2>&1 && echo "Installed" || echo "Not Installed")
    git_status=$(command -v git >/dev/null 2>&1 && echo "Installed" || echo "Not Installed")

    SYSTEM_PANE_LINES+=("SSH: Client $ssh_client | Server $ssh_server_status | SFTP $sftp_status")
    SYSTEM_PANE_LINES+=("PHP: CLI $php_cli | FPM $php_fpm_status")
    SYSTEM_PANE_LINES+=("Apache: $apache_status | Docker: $docker_status")
    SYSTEM_PANE_LINES+=("MariaDB/MySQL: $mariadb_status")
    SYSTEM_PANE_LINES+=("Composer: $composer_status | Node/NPM: $node_status | Git: $git_status")
    SYSTEM_PANE_LINES+=("Date: $(date +'%Y-%m-%d %H:%M:%S')")

    draw_system_pane
}

# -------------------------
# List users with pagination
# -------------------------
list_users(){
    clear_action_pane
    local users=($(cut -d: -f1 /etc/passwd))
    local total=${#users[@]}
    local page_size=$((ACTION_PANE_HEIGHT - 1))
    local i=0
    local page=1
    local total_pages=$(( (total + page_size - 1)/page_size ))

    while (( i < total )); do
        clear_action_pane
        draw_action_message "System Users (Page $page/$total_pages)"
        local count=0
        while (( count < page_size && i < total )); do
            draw_action_message "${users[i]}"
            ((i++))
            ((count++))
        done

        if (( i < total )); then
            key=$(read_action_key "Press Space for next page or Q to quit...")
            [[ "$key" == "q" || "$key" == "Q" ]] && break
        else
            read_action_key "End of list — press Space to return..."
        fi
        ((page++))
    done
}

# -------------------------
# Menu handling
# -------------------------
get_menu_options(){
    case "$MENU_STATE" in
        MAIN_MENU)
            MENU_PANE_LINES=("${MENU_HEADER[@]}" "> Manage Users" "  Manage System" "  Exit")
            ;;
        USER_MENU)
            MENU_PANE_LINES=("${MENU_HEADER[@]}" "> Select User" "  Create User" "  List Users" "  Back")
            ;;
        USER_ACTION_MENU)
            MENU_PANE_LINES=("${MENU_HEADER[@]}" "> Set user password" "  Toggle password login" "  Configure SSH access" "  Configure SFTP access" "  Delete user" "  Back")
            ;;
        SYSTEM_MENU)
            MENU_PANE_LINES=("${MENU_HEADER[@]}" "> Manage SSH" "  Manage SFTP" "  Manage MariaDB" "  Manage PHP" "  Manage Apache" "  Manage Docker" "  Manage Composer" "  Manage NPM" "  Back")
            ;;
    esac
}

reset_menu_selected_option(){ MENU_SELECTED_OPTION=0; }

# -------------------------
# Main loop
# -------------------------
clear_screen
while true; do
    display_system_overview
    get_menu_options
    draw_menu_pane
    draw_info_pane
    clear_action_pane
    key=$(read_action_key "Use arrow keys to navigate and Enter to select:")

    case "$MENU_STATE" in
        MAIN_MENU)
            case "$MENU_SELECTED_OPTION" in
                0) MENU_STATE="USER_MENU"; reset_menu_selected_option ;;
                1) MENU_STATE="SYSTEM_MENU"; reset_menu_selected_option ;;
                2) break ;;
            esac
            ;;
        USER_MENU)
            case "$MENU_SELECTED_OPTION" in
                0)
                    read -p "Enter username to select: " SELECTED_USER
                    if user_exists "$SELECTED_USER"; then
                        draw_action_message "User $SELECTED_USER selected."
                        display_user_info "$SELECTED_USER"
                        MENU_STATE="USER_ACTION_MENU"; reset_menu_selected_option
                    else
                        draw_action_message "User $SELECTED_USER not found."
                        SELECTED_USER=""
                    fi
                    ;;
                1)
                    read -p "Enter new username: " newuser
                    draw_action_message "Creating user $newuser..."
                    # user creation logic here
                    ;;
                2)
                    list_users
                    reset_menu_selected_option
                    ;;
                3)
                    MENU_STATE="MAIN_MENU"; reset_menu_selected_option
                    SELECTED_USER=""
                    ;;
            esac
            ;;
        USER_ACTION_MENU)
            case "$MENU_SELECTED_OPTION" in
                0) draw_action_message "Set user password (not implemented)";;
                1) toggle_password_login;;
                2) draw_action_message "Configure SSH access (not implemented)";;
                3) draw_action_message "Configure SFTP access (not implemented)";;
                4) draw_action_message "Delete user (not implemented)";;
                5) MENU_STATE="USER_MENU"; reset_menu_selected_option; SELECTED_USER=""; clear_action_pane;;
            esac
            ;;
        SYSTEM_MENU)
            case "$MENU_SELECTED_OPTION" in
                0) draw_action_message "Manage SSH (not implemented)";;
                1) draw_action_message "Manage SFTP (not implemented)";;
                2) draw_action_message "Manage MariaDB (not implemented)";;
                3) draw_action_message "Manage PHP (not implemented)";;
                4) draw_action_message "Manage Apache (not implemented)";;
                5) draw_action_message "Manage Docker (not implemented)";;
                6) draw_action_message "Manage Composer (not implemented)";;
                7) draw_action_message "Manage NPM (not implemented)";;
                8) MENU_STATE="MAIN_MENU"; reset_menu_selected_option;;
            esac
            ;;
    esac
done

clear_screen
echo "Goodbye."