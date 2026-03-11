#!/bin/bash

set -uo pipefail

# --------------------------------
# Colours
# --------------------------------
SYSTEM_PANE_BG="\033[48;5;233m"
USER_PANE_BG="\033[48;5;235m"
MENU_PANE_BG="\033[48;5;236m"
ACTION_PANE_BG="\033[48;5;234m"
TEXT_CLR="\033[97m"
RESET="\033[0m"

TICK="[ OK ]"
CROSS="[ FAIL ]"

: "${COLUMNS:=80}"

# --------------------------------
# Globals
# --------------------------------
SELECTED_USER=""
MENU_STATE="USER_SELECT_MENU"
USER_DELETE_LOG_PATH="$(pwd)/user_deletion_logs"

SYSTEM_PANE_HEIGHT=4
USER_PANE_HEIGHT=8
MENU_PANE_HEIGHT=8
ACTION_PANE_HEIGHT=12

ACTION_CURRENT_ROW=$((SYSTEM_PANE_HEIGHT + USER_PANE_HEIGHT + MENU_PANE_HEIGHT))

# --------------------------------
# Utility: clear screen and draw panes
# --------------------------------
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
draw_user_pane(){ draw_pane "$1" "$USER_PANE_BG" "$SYSTEM_PANE_HEIGHT" "$USER_PANE_HEIGHT"; }
draw_menu_pane(){ draw_pane "$1" "$MENU_PANE_BG" "$((SYSTEM_PANE_HEIGHT + USER_PANE_HEIGHT))" "$MENU_PANE_HEIGHT"; }

clear_action_pane(){
    for ((i=0;i<ACTION_PANE_HEIGHT;i++)); do
        tput cup $((SYSTEM_PANE_HEIGHT + USER_PANE_HEIGHT + MENU_PANE_HEIGHT + i)) 0
        printf "%-${COLUMNS}s" " "
    done
    ACTION_CURRENT_ROW=$((SYSTEM_PANE_HEIGHT + USER_PANE_HEIGHT + MENU_PANE_HEIGHT))
}

draw_action_message(){
    tput cup "$ACTION_CURRENT_ROW" 0
    printf "%b%-${COLUMNS}s%b\n" "$ACTION_PANE_BG$TEXT_CLR" "$1" "$RESET"
    ((ACTION_CURRENT_ROW++))
}

read_action_input(){
    tput cup "$ACTION_CURRENT_ROW" 0
    printf "%b" "${ACTION_PANE_BG}${TEXT_CLR}$1${RESET}"
    read -r REPLY
    ((ACTION_CURRENT_ROW++))
}

# --------------------------------
# Status label helper
# --------------------------------
status_label(){
    local rc=$1
    case "$rc" in
        0) echo "$TICK" ;;
        1) echo "$CROSS" ;;
        2) echo "N/A" ;;
        *) echo "N/A" ;;
    esac
}

# --------------------------------
# Capability detection
# --------------------------------
ssh_server_installed(){
    command -v sshd >/dev/null 2>&1 || return 1
    [[ -f /etc/ssh/sshd_config ]] || return 1
    return 0
}

# --------------------------------
# User checks
# --------------------------------
user_exists(){ id "$1" &>/dev/null; }

user_has_password(){
    local pw=$(getent shadow "$1" | cut -d: -f2)
    [[ -z "$pw" ]] && return 1
    [[ "$pw" == '!'* ]] && return 1
    [[ "$pw" == '*'* ]] && return 1
    return 0
}

user_password_login_enabled(){
    local pw=$(getent shadow "$1" | cut -d: -f2)
    [[ "$pw" == '!'* ]] && return 1
    [[ "$pw" == '*'* ]] && return 1
    return 0
}

user_ssh_access_enabled(){
    ssh_server_installed || return 2
    grep -q "^AllowUsers.*$1" /etc/ssh/sshd_config && return 0
    return 1
}

user_sftp_access_enabled(){
    ssh_server_installed || return 2
    grep -q "^Subsystem sftp" /etc/ssh/sshd_config && return 0
    return 1
}

# --------------------------------
# Toggle password login
# --------------------------------
toggle_password_login(){
    local state=$(getent shadow "$SELECTED_USER" | cut -d: -f2)
    if [[ "$state" == '!'* ]] || [[ "$state" == '*'* ]]; then
        passwd -u "$SELECTED_USER" >/dev/null
        draw_action_message "Password login enabled."
    else
        passwd -l "$SELECTED_USER" >/dev/null
        draw_action_message "Password login disabled."
    fi
    display_user_info "$SELECTED_USER"
}

# --------------------------------
# SSH/SFTP configuration
# --------------------------------
configure_ssh(){
    if ! ssh_server_installed; then
        clear_action_pane
        draw_action_message "SSH configuration unavailable."
        draw_action_message "OpenSSH server not installed."
        draw_action_message "Install with: sudo apt install openssh-server"
        return
    fi
    clear_action_pane
    draw_action_message "SSH configuration placeholder."
    display_user_info "$SELECTED_USER"
}

configure_sftp(){
    if ! ssh_server_installed; then
        clear_action_pane
        draw_action_message "SFTP configuration unavailable."
        draw_action_message "OpenSSH server not installed."
        draw_action_message "Install with: sudo apt install openssh-server"
        return
    fi
    clear_action_pane
    draw_action_message "SFTP configuration placeholder."
    display_user_info "$SELECTED_USER"
}

# --------------------------------
# Delete user workflow
# --------------------------------
delete_user_safe(){
    local user="$1"
    [[ "$user" == "root" ]] && { clear_action_pane; draw_action_message "Refusing to delete root."; return 1; }

    clear_action_pane
    local home=$(getent passwd "$user" | cut -d: -f6)
    local mail="/var/mail/$user"
    local processes=$(pgrep -u "$user" || true)

    draw_action_message "Scanning user resources..."
    draw_action_message ""

    local outside_files=$(find /etc /var /usr /opt /srv /tmp -user "$user" 2>/dev/null || true)
    local outside_count=$(echo "$outside_files" | grep -c . || true)

    draw_action_message "User resource summary:"
    draw_action_message "Home directory: $([[ -d "$home" ]] && echo yes || echo no)"
    draw_action_message "Mailbox: $([[ -f "$mail" ]] && echo yes || echo no)"
    draw_action_message "Processes: $([[ -n "$processes" ]] && echo yes || echo no)"
    draw_action_message "Files outside home: $outside_count"
    draw_action_message ""

    local delete_home="no" delete_mail="no" kill_processes="no"

    [[ -d "$home" ]] && { read_action_input "Delete home directory? (y/N): "; [[ "$REPLY" =~ ^[Yy]$ ]] && delete_home="yes"; }
    [[ -f "$mail" ]] && { read_action_input "Delete mailbox? (y/N): "; [[ "$REPLY" =~ ^[Yy]$ ]] && delete_mail="yes"; }
    [[ -n "$processes" ]] && { read_action_input "Kill running processes? (y/N): "; [[ "$REPLY" =~ ^[Yy]$ ]] && kill_processes="yes"; }

    draw_action_message ""
    draw_action_message "Planned actions:"
    draw_action_message "Delete home: $delete_home"
    draw_action_message "Delete mailbox: $delete_mail"
    draw_action_message "Kill processes: $kill_processes"
    draw_action_message "Files outside home: preserved ($outside_count)"

    read_action_input "Proceed with deletion? (y/N): "
    [[ ! "$REPLY" =~ ^[Yy]$ ]] && { draw_action_message "Deletion cancelled."; return 1; }

    mkdir -p "$USER_DELETE_LOG_PATH"
    local log_file="$USER_DELETE_LOG_PATH/user_deletion_${user}.log"

    [[ "$kill_processes" == yes ]] && pkill -u "$user" || true
    [[ "$delete_home" == yes ]] && rm -rf "$home" || true
    [[ "$delete_mail" == yes ]] && rm -f "$mail" || true

    deluser "$user" &>/dev/null
    echo "User deletion log for $user" > "$log_file"

    draw_action_message "User deleted."
    draw_action_message "Log written to:"
    draw_action_message "$log_file"
    return 0
}

# --------------------------------
# Display user info in USER_PANE
# --------------------------------
display_user_info(){
    local user="$1"
    local info=""

    if user_exists "$user"; then
        user_has_password "$user"; local pw_state=$?
        user_password_login_enabled "$user"; local pwlogin_state=$?
        user_ssh_access_enabled "$user"; local ssh_state=$?
        user_sftp_access_enabled "$user"; local sftp_state=$?

        info+="User: $user"$'\n'
        info+="Exists: $(status_label 0)"$'\n'
        info+="Password: $(status_label $pw_state)"$'\n'
        info+="Can login: $(status_label $pwlogin_state)"$'\n'
        info+="SSH access: $(status_label $ssh_state)"$'\n'
        info+="SFTP access: $(status_label $sftp_state)"$'\n'
    else
        info+="User does not exist"
    fi

    draw_user_pane "$info"
}

# --------------------------------
# Display system info in SYSTEM_PANE
# --------------------------------
display_system_info(){
    local sys_lines=()

    # --- Line 1: SSH / SFTP ---
    local ssh_client="Missing" ssh_server="Missing" sftp="Missing"
    command -v ssh >/dev/null 2>&1 && ssh_client="Installed"
    if command -v sshd >/dev/null 2>&1; then
        ssh_server="Installed / $(systemctl is-active sshd >/dev/null 2>&1 && echo OK || echo FAIL)"
        grep -q "^Subsystem sftp" /etc/ssh/sshd_config 2>/dev/null && sftp="Installed / $(systemctl is-active sshd >/dev/null 2>&1 && echo OK || echo FAIL)"
    fi
    sys_lines+=("SSH client: $ssh_client   SSH server: $ssh_server   SFTP: $sftp")

    # --- Line 2: PHP ---
    local php_ok_versions=() php_fail_versions=()
    for phpf in /usr/sbin/php*-fpm; do
        [[ -x "$phpf" ]] || continue
        local ver=$(basename "$phpf" | sed 's/php//; s/-fpm//')
        if systemctl list-units | grep -q "php${ver}-fpm"; then
            php_ok_versions+=("${ver}-fpm")
        else
            php_fail_versions+=("${ver}-fpm")
        fi
    done
    local php_line="PHP: "
    if ((${#php_ok_versions[@]} + ${#php_fail_versions[@]} > 0)); then
        php_line+="Installed / OK (${php_ok_versions[*]})"
        ((${#php_fail_versions[@]} > 0)) && php_line+=" FAIL (${php_fail_versions[*]})"
    else
        php_line+="Missing"
    fi
    sys_lines+=("$php_line")

    # --- Line 3: Apache / Docker / MySQL ---
    local apache="Missing" docker="Missing" mysql="Missing"
    command -v apache2 >/dev/null 2>&1 && apache="Installed / $(systemctl is-active apache2 >/dev/null 2>&1 && echo OK || echo FAIL)"
    command -v docker >/dev/null 2>&1 && docker="Installed / $(systemctl is-active docker >/dev/null 2>&1 && echo OK || echo FAIL)"
    command -v mysql >/dev/null 2>&1 && mysql="Installed / $(systemctl is-active mariadb >/dev/null 2>&1 && echo OK || echo FAIL)"
    sys_lines+=("Apache: $apache   Docker: $docker   MySQL: $mysql")

    # --- Line 4: Composer / Node / Git ---
    local composer="Missing" node="Missing" git="Missing"
    command -v composer >/dev/null 2>&1 && composer="Installed"
    command -v node >/dev/null 2>&1 && node="Installed"
    command -v git >/dev/null 2>&1 && git="Installed"
    sys_lines+=("Composer: $composer   Node: $node   Git: $git")

    draw_system_pane "$(printf "%b\n" "${sys_lines[@]}")"
}

# --------------------------------
# Main loop
# --------------------------------
while true; do
    clear_screen
    display_system_info

    case "$MENU_STATE" in

    USER_SELECT_MENU)
        draw_user_pane "No user selected"
        draw_menu_pane "1. Select user
2. Create user
q. Exit"

        clear_action_pane
        read_action_input "Choose option: "

        case "$REPLY" in
            1)
                read_action_input "Enter username: "
                if user_exists "$REPLY"; then
                    SELECTED_USER="$REPLY"
                    MENU_STATE="USER_ACTION_MENU"
                else
                    draw_action_message "User not found"
                fi
            ;;
            2)
                read_action_input "Enter new username: "
                adduser "$REPLY"
            ;;
            q) break ;;
        esac
    ;;

    USER_ACTION_MENU)
        display_user_info "$SELECTED_USER"

        draw_menu_pane "1. Set user password
2. Toggle password login
3. Configure SSH access
4. Configure SFTP access
5. Delete user
b. Back"

        clear_action_pane
        read_action_input "Choose option: "

        case "$REPLY" in
            1) passwd "$SELECTED_USER" ; display_user_info "$SELECTED_USER" ;;
            2) toggle_password_login ;;
            3) configure_ssh ;;
            4) configure_sftp ;;
            5)
                if delete_user_safe "$SELECTED_USER"; then
                    SELECTED_USER=""
                    MENU_STATE="USER_SELECT_MENU"
                fi
            ;;
            b)
                SELECTED_USER=""
                MENU_STATE="USER_SELECT_MENU"
            ;;
        esac
    ;;

    esac
done

clear_screen
echo "Goodbye."