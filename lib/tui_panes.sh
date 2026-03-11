#!/usr/bin/env bash

#################################
# PANE STORAGE (indexed arrays)
#################################

PANE_IDS=()
PANE_START=()
PANE_HEIGHT=()
PANE_COLOR=()
PANE_SCROLL=()
PANE_BUFFER=()
PANE_CURSOR=()      # last content line rendered in the visible window

#################################
# REGISTER PANE
#################################

register_pane() {
    local id=$1
    local start=$2
    local height=$3
    local color=$4

    PANE_IDS+=("$id")
    PANE_START[$id]=$start
    PANE_HEIGHT[$id]=$height
    PANE_COLOR[$id]=$color
    PANE_SCROLL[$id]=0
    PANE_BUFFER[$id]=""
    PANE_CURSOR[$id]=0
}

setup_panes() {
    local rows=$(tput lines)

    register_pane 0 0 5 "\033[44m"
    register_pane 1 5 10 "\033[46m"
    register_pane 2 15 10 "\033[42m"

    local action_start=25
    local action_height=$((rows-action_start-1))
    register_pane 3 $action_start $action_height "\033[45m"
}

#################################
# LINE RENDERING FUNCTIONS
#################################

# Print a content line (affects cursor)
pane_print_line() {
    local id=$1
    local row=$2
    local text="$3"

    local start=${PANE_START[$id]}
    local color=${PANE_COLOR[$id]}
    local cols=$(tput cols)

    tput cup $((start+row)) 0
    printf "%b%-*s%b" "$color" "$cols" "$text" "\033[0m"

    # Update cursor to the last row containing content
    if [[ -n "$text" ]]; then
        PANE_CURSOR[$id]=$row
    fi
}

# Fill an empty line with background color (does not affect cursor)
pane_fill_line() {
    local id=$1
    local row=$2

    local start=${PANE_START[$id]}
    local color=${PANE_COLOR[$id]}
    local cols=$(tput cols)

    tput cup $((start+row)) 0
    printf "%b%-*s%b" "$color" "$cols" "" "\033[0m"
}

#################################
# PANE OPERATIONS
#################################

pane_clear() {

    local id=$1
    local height=${PANE_HEIGHT[$id]}

    PANE_BUFFER[$id]=""
    PANE_SCROLL[$id]=0
    PANE_CURSOR[$id]=-1

    for ((i=0;i<height;i++)); do
        pane_fill_line "$id" "$i"
    done
}

pane_draw() {

    local id=$1
    local height=${PANE_HEIGHT[$id]}
    local scroll=${PANE_SCROLL[$id]}

    local lines=()
    local IFS=$'\n'
    while read -r line; do lines+=("$line"); done <<< "${PANE_BUFFER[$id]}"

    local total=${#lines[@]}

    for ((i=0;i<height;i++)); do

        local index=$((scroll+i))

        if (( index < total )); then
            pane_print_line "$id" "$i" "${lines[index]}"
        else
            pane_fill_line "$id" "$i"
        fi

    done
}

pane_draw_all() {
    local id
    for id in "${PANE_IDS[@]}"; do
        pane_draw "$id"
    done
}

pane_append() {

    local id=$1
    local text="$2"
    local height=${PANE_HEIGHT[$id]}

    while IFS= read -r line; do
        PANE_BUFFER[$id]+="$line"$'\n'
    done <<< "$text"

    local lines=()
    local IFS=$'\n'
    while read -r line; do lines+=("$line"); done <<< "${PANE_BUFFER[$id]}"

    local total=${#lines[@]}

    # auto-scroll if necessary
    if (( total - PANE_SCROLL[$id] > height )); then
        PANE_SCROLL[$id]=$((total-height))
    fi

    local scroll=${PANE_SCROLL[$id]}

    for ((i=scroll;i<total;i++)); do
        local row=$((i-scroll))
        (( row >= 0 && row < height )) && pane_print_line "$id" "$row" "${lines[i]}"
    done
}

pane_replace_line() {
    local id=$1
    local target_index=$2
    local text="$3"

    local lines=()
    local line
    local i

    while IFS= read -r line; do
        lines+=("$line")
    done < <(printf '%s' "${PANE_BUFFER[$id]}")

    if (( target_index < 0 )); then
        return 1
    fi

    if (( target_index >= ${#lines[@]} )); then
        return 1
    fi

    lines[$target_index]="$text"

    PANE_BUFFER[$id]=""
    for ((i=0; i<${#lines[@]}; i++)); do
        PANE_BUFFER[$id]+="${lines[$i]}"$'\n'
    done

    return 0
}

pane_line_count() {
    local id=$1
    local count=0
    local line

    while IFS= read -r line; do
        count=$((count + 1))
    done < <(printf '%s' "${PANE_BUFFER[$id]}")

    printf '%s' "$count"
}

#################################
# SCROLLING
#################################

pane_scroll_up() {
    local id=$1
    if (( PANE_SCROLL[$id] > 0 )); then
        ((PANE_SCROLL[$id]--))
        pane_draw "$id"
    fi
}

pane_scroll_down() {
    local id=$1
    local height=${PANE_HEIGHT[$id]}
    local total_lines=0
    local IFS=$'\n'
    local tmp
    while read -r tmp; do ((total_lines++)); done <<< "${PANE_BUFFER[$id]}"

    if (( PANE_SCROLL[$id] < total_lines - height )); then
        ((PANE_SCROLL[$id]++))
        pane_draw "$id"
    fi
}