#!/usr/bin/env bash
set -uo pipefail

# -------------------------
# Environment detection
# -------------------------

IS_WSL=0
HAS_SYSTEMD=0

grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1

if command -v systemctl >/dev/null 2>&1 && [[ $IS_WSL -eq 0 ]]; then
    HAS_SYSTEMD=1
fi

# -------------------------
# Root warning
# -------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Warning: Not running as root. Some features will not work."
    sleep 2
fi

# -------------------------
# Terminal detection
# -------------------------

COLUMNS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)

MIN_ROWS=38
(( LINES < MIN_ROWS )) && { echo "Terminal must be at least ${MIN_ROWS} rows"; exit 1; }

# -------------------------
# Colours
# -------------------------

SYSTEM_PANE_BG="\033[48;5;233m"
MENU_PANE_BG="\033[48;5;236m"
INFO_PANE_BG="\033[48;5;235m"
ACTION_PANE_BG="\033[48;5;234m"
TEXT_CLR="\033[97m"
RESET="\033[0m"

TICK="[ OK ]"
CROSS="[FAIL]"

# -------------------------
# Global state
# -------------------------

MENU_STATE="MAIN_MENU"
SELECTED_USER=""
SELECTED_SYSTEM=""

USER_DELETE_LOG_PATH="$(pwd)/user_deletion_logs"
mkdir -p "$USER_DELETE_LOG_PATH"

SYSTEM_PANE_HEIGHT=6
MENU_PANE_HEIGHT=12
INFO_PANE_HEIGHT=8
ACTION_PANE_HEIGHT=12

ACTION_CURRENT_ROW=$((SYSTEM_PANE_HEIGHT + MENU_PANE_HEIGHT + INFO_PANE_HEIGHT))

# -------------------------
# UI helpers
# -------------------------

clear_screen(){ tput clear; }

draw_pane(){
    local text="$1" bg="$2" start="$3" height="$4"

    IFS=$'\n' read -rd '' -a lines <<<"$text" || true

    for ((i=0;i<height;i++)); do
        tput cup $((start+i)) 0
        local line=""
        [[ $i -lt ${#lines[@]} ]] && line="${lines[i]}"
        printf "%b%-${COLUMNS}s%b\n" "$bg$TEXT_CLR" "$line" "$RESET"
    done
}

draw_system_pane(){ draw_pane "$1" "$SYSTEM_PANE_BG" 0 "$SYSTEM_PANE_HEIGHT"; }
draw_menu_pane(){ draw_pane "$1" "$MENU_PANE_BG" "$SYSTEM_PANE_HEIGHT" "$MENU_PANE_HEIGHT"; }
draw_info_pane(){ draw_pane "$1" "$INFO_PANE_BG" "$((SYSTEM_PANE_HEIGHT + MENU_PANE_HEIGHT))" "$INFO_PANE_HEIGHT"; }

clear_action_pane(){
    for ((i=0;i<ACTION_PANE_HEIGHT;i++)); do
        tput cup $((SYSTEM_PANE_HEIGHT + MENU_PANE_HEIGHT + INFO_PANE_HEIGHT + i)) 0
        printf "%-${COLUMNS}s" " "
    done
    ACTION_CURRENT_ROW=$((SYSTEM_PANE_HEIGHT + MENU_PANE_HEIGHT + INFO_PANE_HEIGHT))
}

draw_action_message(){

    (( ACTION_CURRENT_ROW >= SYSTEM_PANE_HEIGHT + MENU_PANE_HEIGHT + INFO_PANE_HEIGHT + ACTION_PANE_HEIGHT )) && return

    tput cup "$ACTION_CURRENT_ROW" 0
    printf "%b%-${COLUMNS}s%b\n" "$ACTION_PANE_BG$TEXT_CLR" "$1" "$RESET"
    ((ACTION_CURRENT_ROW++))
}

read_action_input(){
    tput cup "$ACTION_CURRENT_ROW" 0
    printf "%b" "${ACTION_PANE_BG}${TEXT_CLR}$1${RESET}"
    IFS= read -r REPLY
    ((ACTION_CURRENT_ROW++))
}

# -------------------------
# Service helpers
# -------------------------

service_status(){

    local svc="$1"

    if [[ $HAS_SYSTEMD -eq 1 ]]; then
        systemctl is-active "$svc" >/dev/null 2>&1 && echo "OK" || echo "FAIL"
        return
    fi

    pgrep -x "$svc" >/dev/null && echo "OK" || echo "FAIL"
}

# -------------------------
# User helpers
# -------------------------

user_exists(){ id "$1" &>/dev/null; }

create_user(){

    local u="$1"

    if user_exists "$u"; then
        draw_action_message "User already exists"
        return
    fi

    useradd -m "$u"
    clear_screen
    passwd "$u"
}

delete_user_safe(){

    local u="$1"
    local backup="$USER_DELETE_LOG_PATH/${u}_home_$(date +%s).tar.gz"

    if [[ -d /home/$u ]]; then
        tar -czf "$backup" "/home/$u"
    fi

    userdel -r "$u"

    echo "$u deleted $(date)" >> "$USER_DELETE_LOG_PATH/deletions.log"

    draw_action_message "User deleted (backup saved)"
}

# -------------------------
# Docker helper
# -------------------------

docker_list(){

    if ! command -v docker >/dev/null; then
        draw_info_pane "Docker not installed"
        return
    fi

    local list
    list=$(docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null)

    draw_info_pane "Docker Containers:\n$list"
}

# -------------------------
# System overview
# -------------------------

display_system_overview(){

    local ssh_client=$(command -v ssh >/dev/null && echo "Installed" || echo "Missing")

    local ssh_server="Missing"
    local sftp="Missing"

    if command -v sshd >/dev/null; then
        ssh_server="Installed"
        [[ -f /etc/ssh/sshd_config ]] && grep -q "^Subsystem.*sftp" /etc/ssh/sshd_config && sftp="Installed"
    fi

    local php_cli=$(command -v php >/dev/null && echo "Installed" || echo "Missing")

    local php_fpm="Missing"
    compgen -G "/usr/sbin/php*-fpm" >/dev/null && php_fpm="Installed"

    local apache_status="Missing"
    command -v apache2 >/dev/null && apache_status="Installed/$(service_status apache2)"

    local docker_status="Missing"
    command -v docker >/dev/null && docker_status="Installed"

    local mariadb_status="Missing"
    command -v mariadbd >/dev/null && mariadb_status="Installed/$(service_status mariadb)"
    command -v mysqld >/dev/null && mariadb_status="Installed/$(service_status mysql)"

    local composer=$(command -v composer >/dev/null && echo "Installed" || echo "Missing")
    local node=$(command -v node >/dev/null && echo "Installed" || echo "Missing")
    local git=$(command -v git >/dev/null && echo "Installed" || echo "Missing")

    local info="System Overview - $(date +'%Y-%m-%d %H:%M:%S')\n"
    info+="SSH Client: $ssh_client  SSH Server: $ssh_server  SFTP: $sftp\n"
    info+="PHP CLI: $php_cli  PHP FPM: $php_fpm\n"
    info+="Apache: $apache_status  Docker: $docker_status  MariaDB: $mariadb_status\n"
    info+="Composer: $composer  Node: $node  Git: $git"

    draw_system_pane "$info"
}

# -------------------------
# Arrow key menu
# -------------------------

menu_select(){

    local title="$1"
    shift
    local options=("$@")

    local selected=0

    while true; do

        local text="$title\n\n"

        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                text+=" > ${options[$i]}\n"
            else
                text+="   ${options[$i]}\n"
            fi
        done

        draw_menu_pane "$text"

        read -rsn1 key

        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            case "$key" in
                "[A") ((selected--)) ;;
                "[B") ((selected++)) ;;
            esac
        elif [[ $key == "" ]]; then
            return $selected
        fi

        ((selected < 0)) && selected=$((${#options[@]}-1))
        ((selected >= ${#options[@]})) && selected=0
    done
}

# -------------------------
# Main loop
# -------------------------

while true; do

    clear_screen
    display_system_overview
    clear_action_pane

    menu_select "Main Menu" \
        "Manage Users" \
        "Manage System" \
        "Docker Containers" \
        "Exit"

    case $? in

    0)

        read_action_input "Enter username: "

        if user_exists "$REPLY"; then
            SELECTED_USER="$REPLY"

            menu_select "User Actions ($SELECTED_USER)" \
                "Set Password" \
                "Delete User" \
                "Back"

            case $? in
                0) clear_screen; passwd "$SELECTED_USER" ;;
                1) delete_user_safe "$SELECTED_USER" ;;
            esac

        else
            draw_action_message "User not found"
            sleep 1
        fi

    ;;

    1)

        menu_select "System Management" \
            "Restart Apache" \
            "Restart SSH" \
            "Back"

        case $? in
            0) systemctl restart apache2 2>/dev/null ;;
            1) systemctl restart ssh 2>/dev/null ;;
        esac

    ;;

    2)
        docker_list
        sleep 3
    ;;

    3)
        break
    ;;

    esac

done

clear_screen
echo "Goodbye."