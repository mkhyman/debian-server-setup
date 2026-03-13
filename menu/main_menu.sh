#!/usr/bin/env bash

MENU_MAIN_TITLE="Main Menu"

MENU_MAIN_ITEMS=(
    "literal:Users Management|menu|USER"
    "literal:Application Management|menu|APPLICATION"
)

MENU_MAIN_ITEMS_BLOB="$(menu_items_to_blob "${MENU_MAIN_ITEMS[@]}")"

#
# MENU_NETWORK_TITLE="Network"
# MENU_NETWORK_ITEMS=(
#     "func:menu_label_ssh_toggle|workflow|WF_TOGGLE_SSH"
# )
#
# MENU_NETWORK_ON_ENTER="menu_network_on_enter"
# MENU_NETWORK_ON_BACK="menu_network_on_back"
#
# Example label function:
#
# menu_label_ssh_toggle() {
#     if ssh_is_enabled; then
#         printf 'Disable SSH'
#     else
#         printf 'Enable SSH'
#     fi
# }
#
# Example lifecycle handlers:
#
# menu_network_on_enter() {
#     local menu_name="$1"
#     refresh_network_cache
# }
#
# menu_network_on_back() {
#     local menu_name="$1"
#     clear_network_temp_state
# }