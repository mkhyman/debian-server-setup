#!/usr/bin/env bash
# panes.sh - functions for managing and rendering panes

clear_overview_pane() {
    clear_pane 0 $PANE_SYS_ROWS "$PANE_SYS_BG"
}

clear_menu_pane() {
    clear_pane $PANE_SYS_ROWS $PANE_MENU_ROWS "$PANE_MENU_BG"
}

clear_info_pane() {
    clear_pane $((PANE_SYS_ROWS + PANE_MENU_ROWS)) $PANE_INFO_ROWS "$PANE_INFO_BG"
}

clear_action_pane() {
    local term_rows=$(tput lines)
    local pane_rows=$((term_rows - (PANE_SYS_ROWS + PANE_MENU_ROWS + PANE_INFO_ROWS) - 1))

    clear_pane $((PANE_SYS_ROWS + PANE_MENU_ROWS + PANE_INFO_ROWS)) $pane_rows "$PANE_ACTION_BG"
}

# Clear a pane (overwrite with spaces)
clear_pane() {
    local start_row=$1
    local num_rows=$2
    local bg_color="$3"

    tput sc
    for ((i=0;i<num_rows;i++)); do
        tput cup $((start_row + i)) 0
        printf "%b%*s%b" "$bg_color" "$(tput cols)" "" "$RESET"
    done
    tput rc
}

# Fill a pane with background color (fills entire width of terminal)
fill_pane() {
    local start_row=$1
    local num_rows=$2
    local bg_color="$3"
    tput sc
    for ((i=0;i<num_rows;i++)); do
        tput cup $((start_row + i)) 0
        printf "%b%*s%b" "$bg_color" "$(tput cols)" "" "$RESET"
    done
    tput rc
}



# Draw System Overview Pane (top)
draw_system_overview_pane() {
    local lines=("$@")
    local start_row=0
    fill_pane $start_row $SYS_OV_ROWS "$SYS_OV_PANE_BG$TEXT_CLR"
    local row=0
    for line in "${lines[@]}"; do
        tput cup $((start_row + row)) 0
        printf "%b%s%b" "$SYS_OV_PANE_BG$TEXT_CLR" "$line" "$RESET"
        ((row++))
    done
}

# Draw Menu Pane (below system overview)
draw_menu_pane() {
    local start_row=$SYS_OV_ROWS
    fill_pane $start_row $MENU_ROWS "$MENU_PANE_BG$TEXT_CLR"
}

# Draw Info Pane (below menu)
draw_info_pane() {
    local lines=("$@")
    local start_row=$((SYS_OV_ROWS + MENU_ROWS))
    fill_pane $start_row $INFO_ROWS "$INFO_PANE_BG$TEXT_CLR"
    local row=0
    for line in "${lines[@]}"; do
        tput cup $((start_row + row)) 0
        printf "%b%s%b" "$INFO_PANE_BG$TEXT_CLR" "$line" "$RESET"
        ((row++))
    done
}

# Draw Action Pane (bottom)
draw_action_pane() {
    local lines=("$@")
    local start_row=$((SYS_OV_ROWS + MENU_ROWS + INFO_ROWS))
    fill_pane $start_row $ACTION_ROWS "$ACTION_PANE_BG$TEXT_CLR"
    local row=0
    for line in "${lines[@]}"; do
        tput cup $((start_row + row)) 0
        printf "%b%s%b" "$ACTION_PANE_BG$TEXT_CLR" "$line" "$RESET"
        ((row++))
    done
}

# Helper: show a temporary message in action pane
show_action_message() {
    local msg="$1"
    draw_action_pane "$msg"
}