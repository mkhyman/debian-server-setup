#!/usr/bin/env bash

MENU_COMPOSER_TITLE="Composer Management"

MENU_COMPOSER_ITEMS=(
    "func:menu_label_composer_install_uninstall|workflow|WF_COMPOSER_INSTALL_UNINSTALL"
)

menu_register "COMPOSER" "${MENU_COMPOSER_ITEMS[@]}"

MENU_COMPOSER_ON_ENTER="menu_composer_on_enter"
MENU_COMPOSER_ON_BACK="menu_composer_on_back"

menu_label_composer_install_uninstall() {
    if composer_is_installed; then
        printf 'Uninstall Composer'
    else
        printf 'Install Composer'
    fi
}

menu_composer_on_enter() {
    local tty_state

    tty_state="$(stty -a 2>/dev/null)" || tty_state="<stty failed>"

    info_render_composer
}

menu_composer_on_back() {
    pane_clear "$PANE_INFO_ID"
}
