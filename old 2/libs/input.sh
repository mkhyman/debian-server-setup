#!/usr/bin/env bash
# input.sh - terminal input functions

# Read single key (arrow keys, space, q)
get_navigation_key() {
    local key
    stty -echo -icanon
    read -rsn1 key
    stty sane
    echo "$key"
}

# Read string input
prompt_string() {
    local prompt="$1"
    local input
    stty sane
    read -rp "$prompt" input
    echo "$input"
}

# Yes/No confirmation (raw mode)
get_confirmation() {
    local prompt="$1"
    local key
    printf "%s (y/n): " "$prompt"
    stty -echo -icanon
    while true; do
        read -rsn1 key
        case "$key" in
            [Yy]) stty sane; echo; return 0 ;;
            [Nn]) stty sane; echo; return 1 ;;
        esac
    done
}