#!/usr/bin/env bash
# info_renderer.sh - decides what to show in the info pane

draw_info_pane() {
    clear_pane 0 $INFO_ROWS
    local lines=()

    case "$SELECTED_INFO_TYPE" in
        user)
            lines+=("User Info for $SELECTED_INFO_ENTITY")
            lines+=("UID: 1001")
            lines+=("Groups: testuser")
            lines+=("Home: /home/testuser")
            ;;
        ssh)
            lines+=("SSH Info")
            lines+=("Client Installed")
            lines+=("Server Installed")
            lines+=("SFTP Enabled")
            ;;
        docker)
            lines+=("Docker Info")
            lines+=("Docker Engine Installed")
            lines+=("Containers: 3 running")
            ;;
        system)
            lines+=("System Info")
            lines+=("Date: $(date '+%Y-%m-%d %H:%M:%S')")
            ;;
        *)
            lines+=("No info available")
            ;;
    esac

    local row=0
    for line in "${lines[@]}"; do
        tput cup $row 0
        echo "$line"
        ((row++))
    done
}